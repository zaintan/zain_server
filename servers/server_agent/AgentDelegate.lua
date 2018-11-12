---! 依赖库
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"
local socket    = require "skynet.socket"
---! 帮助库
local packetHelper  = (require "PacketHelper").create("protos/ZainCommon.pb")
local ProtoHelper   = (require "ProtoHelper").init()

local class = {mt = {}}
class.mt.__index = class

--[[ info = {
    watchdog;
    gate;
    client_fd;
    address;
    agent;
    appName;
    centerApp;
    allocApp;
}]]--
function class.create(info)
	local self = {}
	setmetatable(self, class.mt)

	for k,v in pairs(info or {}) do
        self[k] = v
    end

    self.agentSign   = os.time()
    --self.m_bIsLogin  = false
    self.profile     = {}
    self:active()

    Log.i("Agent","CMD start called on fd %d",self.client_fd)
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
    Log.i("Agent","heartbeat timeout! kick me!")
    pcall(skynet.send, self.watchdog, "lua", "closeAgent", self.client_fd, true, true)
end

function class:quit(bNotiCenter, bNotiGame)
    Log.i("Agent","玩家下线!")
    --下线通知 中心服 和 游戏服
    if bNotiCenter then 
        local ok, status = pcall(cluster.call, self.centerApp, ".CenterService", "logout",
                                self.FUserID, self.appName)
    end 

    if bNotiGame and self.gameApp and self.gameAddr then 
        pcall(cluster.call, self.gameApp, self.gameAddr, "offline", self.FUserID, self.appName)
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

function class:sendClientMsg(main_type,sub_type,msg_id,data)

    local protoName = ProtoHelper.IdToName[msg_id] 
    local body      = packetHelper:encodeMsg("Zain."..protoName, data)
    self:outputProfile(main_type,msg_id)

    local packet = packetHelper:makeProtoData(main_type, sub_type,msg_id , body)
    self:sendClientPacket(packet)

    return true
end

function class:handlerAllocRequest(msg, args)
    if not self:hadLogin() then 
        self:sendErrorTip("您还未登录!")
        return
    end     

    local status = pcall(cluster.call, self.allocApp, ".AllocService",  "cliRequest" , self.FUserID,args.msg_id, args.msg_body, self.appName, self.agent)
    if not status then 
        self:sendErrorTip("链接AllocServer失败!")
        return 
    end 
end

function class:handlerHallRequest(msg, args)
    if not self:hadLogin() then 
        self:sendErrorTip("您还未登录!")
        return
    end     
    -- body
--    local msgId   = string.unpack(">I2",msg)
--    if msgId == 1 then --login
--        local loginData = packetHelper:decodeMsg(ProtoHelper.IdToName[msgId], string.sub(msg,3))
--    end 
    self:sendErrorTip("非法请求中心服!")
end

function class:handlerRoomRequest(msg, args)
    if not self:hadLogin() then 
        self:sendErrorTip("您还未登录!")
        return
    end 

    local ok,ret,retData = pcall(cluster.call, self.gameApp, self.gameAddr, "onRequest", self.FUserID, args.msg_id, args.msg_body)
    if not ok then 
        self:sendErrorTip("链接逻辑服失败!")
    end 

    if ret and ret > 0 and retData then 
        self:sendClientMsg(const.ProtoMain.RESPONSE, const.ProtoSub.GAME, ret, retData)
    else
        self:sendErrorTip("Game服务器未注册的协议!")
    end     
end

function class:handlerHeartRequest(args)
    self:sendClientMsg(const.ProtoMain.RESPONSE, const.ProtoSub.GATE ,const.MsgId.HeartRsp,{})
end

function class:onLoginFailed(errString, errCode)
    local response = {}
    response.status     = errCode or -1
    response.status_tip = errString or ""
    self:sendClientMsg(const.ProtoMain.RESPONSE, const.ProtoSub.GATE ,const.MsgId.LoginRsp, response)
end

function class:handlerLoginRequest(args)
    if not args then 
        self:onLoginFailed("非法登录请求参数!")
        return
    end 
    if self:hadLogin() then 
        self:onLoginFailed("不要重复登录!")
        return 
    end 

    Log.i("Agent","handlerLoginRequest:")
    Log.dump("Agent",args)

    --self:sendErrorTip("Invalid Gate Request")
    local ok,msg = pcall(cluster.call, self.centerApp, ".CenterService", "login", args, self.appName)
    if ok then 
        Log.i("Agent","登录中心服返回验证:")
        Log.dump("Agent", msg)
        if msg[1] == 0 then --登录成功
            self.FUserID = msg[2].FUserID
            --return to client 
            local response = {}
            response.status   = 0
            local t = {}
            t.user_id      = msg[2].FUserID
            t.user_name    = msg[2].FUserName
            t.head_img_url = msg[2].FHeadUrl
            t.sex          = msg[2].FSex
            t.diamond      = msg[2].FDiamond
            t.gold         = msg[2].FGold
            t.room_id      = msg[2].roomId
            response.user_info = t
            self:sendClientMsg(const.ProtoMain.RESPONSE, const.ProtoSub.GATE, const.MsgId.LoginRsp,response)
        else 
            self:onLoginFailed(msg[2],msg[1])
        end 
    else
        self:onLoginFailed("链接中心服失败!")
    end 
end

local GateComandFuncMap = {
    [4] = class.handlerHeartRequest;--心跳
    [1] = class.handlerLoginRequest;
}

function class:handlerGateRequest(msg, args)
    local msgId    = args.msg_id
    local f        = GateComandFuncMap[msgId]
    if f then 
        local args = packetHelper:decodeMsg("Zain."..ProtoHelper.IdToName[msgId], args.msg_body)
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

function class:inputProfile( args , recvTime )
    --rpc time profile
    if args.main_type == 1 then 
        local msg_id  = args.msg_id
        if not self.profile[msg_id] then 
            self.profile[msg_id] = {}
        end 
        self.profile[msg_id].recvTime    = recvTime
        self.profile[msg_id].processTime = skynet.time()
    end 
end

function class:outputProfile(main_type,msg_id)
    if main_type == 2 then 
        if msg_id > ProtoHelper.ResponseBase then 
            local request_id = msg_id - ProtoHelper.ResponseBase
            local info = self.profile[request_id]
            if info then 
                info.respTime = skynet.time()
                local waitTime,procTime = info.processTime - info.recvTime, info.respTime - info.processTime
                waitTime = math.ceil(waitTime*1000)
                procTime = math.ceil(procTime*1000)
                --self.profile[request_id] = nil
                --精度 0.01s = 10ms
                Log.i("Agent","msg_id = %d, waitTime = %d ms, procTime = %d ms",request_id,waitTime,procTime)
            end 
        end 
    end 
end


function class:command_handler(msg, recvTime)
    self:active()
    --解析包头 转发处理消息 做对应转发
    local args = packetHelper:decodeMsg("Zain.ProtoInfo",msg)
    self:inputProfile(args, recvTime)
    if args.main_type == 1 or args.main_type == 3 then --request or upload
        local f = ComandFuncMap[args.sub_type]
        if f then 
            return f(self, msg, args)
        else--非法请求
            self:sendErrorTip(string.format("Invalid Request! sub_type = %d,sub_type must be [1,4]", args.sub_type))
        end 
    else
        --非法请求
        self:sendErrorTip(string.format("Invalid Request! main_type = %d,main_type must be 1 or 3", args.main_type))
    end 
end

function class:sendErrorTip(content, type)
    local data = {}
    data.type    = type or 1
    data.content = content or ""
    return self:sendClientMsg(const.ProtoMain.PUSH, const.ProtoSub.GATE, const.MsgId.CommonTipsPush, data)
end

function class:hadLogin()
    return self.FUserID ~= nil
end

return class