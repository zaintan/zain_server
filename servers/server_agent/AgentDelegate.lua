---! 依赖库
local skynet    = require "skynet"
local socket    = require "skynet.socket"
---! 帮助库
local packetHelper  = (require "PacketHelper").create("protos/ZainCommon.pb")
local Msg           = (require "protos.Msg").init()

local class = {mt = {}}
class.mt.__index = class

--[[ info = {
    watchdog;
    gate;
    client_fd;
    address;
    agent;
    appName;
}]]--
function class.create(info)
	local self = {}
	setmetatable(self, class.mt)

	for k,v in pairs(info or {}) do
        self[k] = v
    end

    self.agentSign   = os.time()
    --self.m_bIsLogin  = false

    self:active()

    skynet.error("CMD start called on fd ", self.client_fd)
    skynet.call(self.gate, "lua", "forward", self.client_fd)
    skynet.fork(function ()
        while true do 
            -- 2 seconds 检查一次
            -- 10 seconds 都没有收到过包  就认为掉线直接踢掉
            if self:timeoutCheck(10) then 
                self:kickMe()
                return 
            end 
            skynet.sleep(2 * 100)
        end 
    end)
    return self
end

function class:timeoutCheck(timeout )
    if skynet.time() - self.last_update >= timeout then 
        return true
    end 
end

function class:active()
	self.last_update = skynet.time()
end

function class:kickMe()
    skynet.error("heartbeat timeout! kick me!")
    pcall(skynet.send, self.watchdog, "lua", "closeAgent", self.client_fd)
end

function class:quit()
    if self.connApp and self.connAddr then
        --下线通知 中心服 和 游戏服
        local flg, ret = pcall(cluster.call, self.connApp, self.connAddr, "agentQuit",
                                self.FUserCode, self.agentSign)
        if not flg or not ret then
            kickMe()
        end
    end

    if self.client_fd then 
        socket.close(self.client_fd)
    end 

    skynet.exit()    
end

function class:sendClientPacket( packet )
    if self.client_fd then 
        local data = string.pack(">s2", packet)
        socket.write(self.client_fd, data)
    end 
end

function class:sendClientMsg(mainType,subType,protoName,data)
    local body   = packetHelper:encodeMsg("Zain."..protoName, data)
    local packet = packetHelper:makeProtoData(mainType, subType, string.pack(">I2",Msg.NameToId[protoName])..body)
    self:sendClientPacket(packet)
end

function class:handlerAllocRequest(msg, data)
    -- body
end

function class:handlerHallRequest(msg, data)
    -- body
--    local msgId   = string.unpack(">I2",msg)
--    if msgId == 1 then --login
--        local loginData = packetHelper:decodeMsg(Msg.IdToName[msgId], string.sub(msg,3))
--    end 
end

function class:handlerRoomRequest(msg, data)
    -- body
end

function class:handlerHeartRequest(args)
    self:sendClientMsg(2,1,"HeartResponse",{})
end


local GateComandFuncMap = {
    [4] = class.handlerHeartRequest;--心跳
}

function class:handlerGateRequest(msg, data)
    local msgId    = string.unpack(">I2",msg)
    local f        = GateComandFuncMap[msgId]
    if f then 
        local args = packetHelper:decodeMsg(Msg.IdToName[msgId], string.sub(msg, 3))
        return f(self,args)
    else--非法请求
        self:sendErrorTip("Invalid Gate Request")
    end 
end

local ComandFuncMap = {
    [1] = class.handlerGateRequest;
    [2] = class.handlerHallRequest;
    [3] = class.handlerAllocRequest;
    [4] = class.handlerRoomRequest;
}



function class:command_handler(msg)
    self:active()
    --解析包头 转发处理消息 做对应转发
    local args = packetHelper:decodeMsg("Zain.ProtoInfo",msg)
    if args.mainType == 1 or args.mainType == 3 then --request or upload
        local f = ComandFuncMap[args.subType]
        if f then 
            return f(self, msg, args)
        else--非法请求
            self:sendErrorTip(string.format("Invalid Request! subType = %d,subType must be [1,4]", args.subType))
        end 
    else
        --非法请求
        self:sendErrorTip(string.format("Invalid Request! mainType = %d,mainType must be 1 or 3", args.mainType))
    end 
end

function class:sendErrorTip(content, type)
    local data = {}
    data.type    = type or 1
    data.content = content or ""
    self:sendClientMsg(4,1,"CommonTipsPush", data)
end

return class