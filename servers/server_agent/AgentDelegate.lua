---! 依赖库
local skynet    = require "skynet"
local socket    = require "skynet.socket"
---! 帮助库
local packetHelper  = (require "PacketHelper").create("protos/ZainCommon.pb")

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
            -- 3 seconds to send heart beat
            -- 10 seconds to break
            if self:timeoutCheck(3,  10) then 
                return 
            end 
            self:sendClientPacket(self:packHeartBeat())
            skynet.sleep(heartbeat * 100)
        end 
    end)
    return self
end

function class:timeoutCheck( heartbeat, timeout )
    if skynet.time() - self.last_update >= timeout then 
        self:kickMe()
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

function class:handlerAllocRequest(msg, data)
    -- body
end

function class:handlerHallRequest(msg, data)
    -- body
end

function class:handlerRoomRequest(msg, data)
    -- body
end

local ComandFuncMap = {
    [1] = class.handlerHallRequest;
    [2] = class.handlerAllocRequest;
    [3] = class.handlerRoomRequest;
}

function class:command_handler(msg)
    self:active()
    --解析包头 转发处理消息 做对应转发
    local args = packetHelper:decodeMsg("ZainCommon.ProtoInfo",msg)
    if args.mainType == 1 or args.mainType == 3 then 
        local f = ComandFuncMap[args.subType]
        if f then 
            return f(self, msg, args)
        else--非法请求

        end 
    else
        --非法请求
    end 
end

function class:packHeartBeat()
    return ""
end


return class