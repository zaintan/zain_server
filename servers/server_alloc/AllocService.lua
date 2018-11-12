------------------------------------------------------
---! @file
---! @brief AllocService
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
require "skynet.manager"
local cluster   = require "skynet.cluster"

---! 帮助库
local packetHelper  = (require "PacketHelper").create("protos/ZainCommon.pb")
local ProtoHelper   = (require "ProtoHelper").init()

---! 辅助依赖
local NumSet          = require "NumSet"

local ErrorCode       = require "ErrorCode"
local GameServerModel = require "GameServerModel"

---! all users:  k = userid; v = roomId;
local userMap        = NumSet.create()
local gameServerList = NumSet.create()
local roomIdPool     = (require "RoomIdPool").create()

---! 全局常量
local nodeInfo = nil


local LOGTAG   = "AllocService"


local function getGameServer()
    --local minCount = nil
    local minObj      = nil

    --负载均衡 找牌桌最少的一个GameServer 
    gameServerList:forEach(function (obj)
        if obj:isActive() and (minObj == nil or minObj.tableNum > obj.tableNum ) then 
            minObj = obj
        end 
    end)
    return minObj
end

local function create( uid, data, appName, agentAddr )
    local roomId           = roomIdPool:allocId()
    local gameServer       = getGameServer()
    if gameServer == nil then 
        Log.e(LOGTAG,"无可分配的游戏服务器")
        return const.MsgId.CreateRsp,{status = -1; status_tip = "无可分配的游戏服务器";}
    end 
    local status,tableAddr = pcall(cluster.call, gameServer:getClusterAddr(), ".GameService", "createTable", roomId, data)
    if status and tableAddr and tableAddr ~= -1 then 
        gameServer.tableNum = gameServer.tableNum + 1
        roomIdPool:useId(roomId, gameServer:getClusterAddr(), tableAddr, uid)
        --创建成功
        return const.MsgId.CreateRsp, {status = 0; room_id = roomId;}
    end 
    --创建桌子失败 回收id
    gameServer.failedCount = gameServer.failedCount + 1
    roomIdPool:recoverId(roomId)
    Log.e(LOGTAG,"创建桌子失败:%s", tostring(tableAddr)) 
    return const.MsgId.CreateRsp, {status = -2; status_tip = "创建桌子失败";}
end

local function join( uid, roomId, appName, agentAddr )
    ----------------------------
    local enterRoomId = userMap:getObject(uid) or roomId
    if enterRoomId and roomId ~= enterRoomId then 
        Log.w(LOGTAG,"该用户已经在房间%d里面了,不能重复进入房间%d", oldRoomId,roomId)
    end 
    userMap:addObject(enterRoomId,  uid)
    local gameAppName,tableAddr = roomIdPool:getRoomAddr(enterRoomId)
    if not gameAppName or not tableAddr then 
        Log.e(LOGTAG,"获取不到房间%d所在逻辑服的桌子地址", enterRoomId)
        userMap:removeObject(uid)
        return const.MsgId.JoinRsp,{status = -1;status_tip = "获取不到房间所在逻辑服的桌子地址";}
    end 
    local status,ret = pcall(cluster.call, gameAppName,tableAddr, "join", uid, roomId, appName, agentAddr)
    --加入成功
    if status and ret then 
        if ret.status ~= 0 then--失败 
            userMap:removeObject(uid)
        end 
        return const.MsgId.JoinRsp,ret
    end 
    userMap:removeObject(uid)
    local status_tip = "链接逻辑服失败"
    if ret and ret.status_tip then 
        status_tip = ret.status_tip
    end  
    return const.MsgId.JoinRsp,{status = -2;status_tip = status_tip;}
end

local function sendClientMsg(appName, agentAddr,msgId, data )
    pcall(cluster.call, appName, 
                        agentAddr,  
                        "sendClientMsg" , 
                        const.ProtoMain.RESPONSE, 
                        const.ProtoSub.ALLOC, 
                        msgId, 
                        data)
end

local function sendErrorTip(appName, agentAddr, content, type)
    pcall(cluster.call, appName, 
                        agentAddr,  
                        "sendErrorTip", 
                        content, type)
end

---! lua commands
local CMD = {}

---from client request
function CMD.cliRequest(source, uid, msgId, msgBody, appName, agentAddr )
    skynet.ignoreret()

    Log.i(LOGTAG,"recv cliRequest: msgId = %d",msgId)

    local msgName = ProtoHelper.IdToName[msgId]
    if not msgName then 
        sendErrorTip(appName, agentAddr,"找不到msgId对应的协议名!")
        return 
    end 

    local data = packetHelper:decodeMsg("Zain."..msgName, msgBody)
    if not data then 
        sendErrorTip(appName, agentAddr,"协议解析错误!")
        return 
    end 
    Log.dump(LOGTAG,data)
    if msgId == 2 then --create
        sendClientMsg(appName, agentAddr, create(uid, data, appName, agentAddr) )
        return 
    elseif msgId == 3 then --join
        sendClientMsg(appName, agentAddr, join(uid, data.room_id, appName, agentAddr) )
        return 
    end 

    sendErrorTip(appName, agentAddr,"未定义的协议!")
    return
end

---! get the server stat
function CMD.getStat()
    local ret = {}
    --负载均衡 找牌桌最少的一个GameServer 
    gameServerList:forEach(function (obj)
        local server = {}
        server.appName   = obj.appName
        server.active    = obj.active
        server.tableNum  = obj.tableNum
        server.playerNum = obj.playerNum
        table.insert(ret,server)
    end)

    return ret
end

--GameServer申请退休 ps:此时可能还有牌桌 这时候只做个标记 不再分配用户到此游戏服务器 待所有牌桌结束后 再处理
function CMD.retireServer(source, appName)
    local gameServer = gameServerList:getObject(appName)
    if gameServer then 
        gameServer:retire()
    end 
end
--GameServer激活
function CMD.regServer(source, appName, addr)
    local gameServer = GameServerModel.create(appName, addr)
    gameServerList:addObject(gameServer, appName)
    return true
end

--获取有效GameServer
function CMD.askAll()
    local list = skynet.call(nodeInfo, "lua", "getConfig", "server_game")
    
    for _, app in ipairs(list) do
        local ok,msg = pcall(cluster.call, app, ".GameService", "askReg")
        if not ok then 
            Log.e(LOGTAG,"connect to gameServer:%s failed! err:%s", app, tostring(msg))
        end 
    end
end

--from center server
function CMD.queryUser(source, uid)
    Log.i(LOGTAG,"recv queryUser uid:%d from center!",uid)
    return userMap:getObject(uid) or -1
end

--from game logic server
function CMD.exit(source, uid, roomId )
    -- body
end

function CMD.dissolve(source, roomId )
    -- body
end

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )
    skynet.register(".AllocService")

    ---! 注册skynet消息服务
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            local ret = f(source, ...)
            if ret then
                skynet.ret(skynet.pack(ret))
            end
        else
            Log.e(LOGTAG,"unknown command:%s", cmd)
        end
    end)

    ---! 获得NodeInfo 服务
    nodeInfo = skynet.uniqueservice("NodeInfo")

    ---! 注册自己的地址
    skynet.call(nodeInfo, "lua", "updateConfig", skynet.self(), "AllocService")

    ---! 获得appName
    appName = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo", "appName")

    ---! ask all game nodes to register
    skynet.fork(CMD.askAll)
end)

