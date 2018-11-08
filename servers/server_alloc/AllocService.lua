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

local function rspCreate(appName, agentAddr, data)
    pcall(cluster.call, appName, agentAddr, "sendClientMsg",2,3,"CreateRoomResponse",data)
end

local function create( uid, data, appName, agentAddr )
    local roomId           = roomIdPool:allocId()
    local gameServer       = getGameServer()
    if gameServer == nil then 
        Log.e(LOGTAG,"无可分配的游戏服务器")
        rspCreate(appName, agentAddr,{status = -1; status_tip = "无可分配的游戏服务器";})
        return nil
    end 
    local status,tableAddr = pcall(cluster.call, gameServer:getClusterAddr(), ".GameService", "createTable", roomId, data)
    if status and tableAddr then 
        gameServer.tableNum = gameServer.tableNum + 1
        roomIdPool:useId(roomId, gameServer:getClusterAddr(), tableAddr, uid)
        --创建成功
        rspCreate(appName, agentAddr,{status = 0; room_id = roomId;})
        return true
    end 
    --创建桌子失败 回收id
    gameServer.failedCount = gameServer.failedCount + 1
    roomIdPool:recoverId(roomId)
    Log.e(LOGTAG,"创建桌子失败:%s", tostring(tableAddr))
    rspCreate(appName, agentAddr,{status = -2; status_tip = "创建桌子失败";})  
    return nil
end

local function rspJoin(appName, agentAddr, data)
    pcall(cluster.call, appName, agentAddr, "sendClientMsg",2,3,"JoinRoomRoomResponse",data)
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
        rspJoin(appName, agentAddr, {status = -1;status_tip = "获取不到房间所在逻辑服的桌子地址"..enterRoomId;})
        return false
    end 
    local status,ret = pcall(cluster.call, gameAppName,tableAddr, "join", uid, roomId, appName, agentAddr)
    --加入成功
    if status and ret then 
        if ret.status ~= 0 then--失败 
            userMap:removeObject(uid)
            rspJoin(appName, agentAddr, ret)
            return false
        end 
        rspJoin(appName, agentAddr, ret) 
        return true
    end 
    userMap:removeObject(uid)
    local status_tip = "链接逻辑服失败"
    if ret and ret.status_tip then 
        status_tip = ret.status_tip
    end 
    rspJoin(appName, agentAddr, {status = -2;status_tip = status_tip;})    
    return false
end

---! lua commands
local CMD = {}

---from client request
function CMD.cliRequest(source, uid, msgId, msgBody, appName, agentAddr )
    skynet.ignoreret()

    local msgName = ProtoHelper.IdToName[msgId]
    if not msgName then 
        pcall(cluster.call, appName, agentAddr, "sendErrorTip", "找不到msgId对应的协议名!")
        return
    end 

    local data = packetHelper:decodeMsg("Zain."..msgName, args.msg_body)
    if not data then 
        pcall(cluster.call, appName, agentAddr, "sendErrorTip", "协议解析错误!")
        return
    end 

    if msgId == 2 then --create
        return create(uid, data, appName, agentAddr)
    elseif msgId == 3 then --join
        return join(uid, data.room_id, appName, agentAddr)
    end 
    --pcall(cluster.call, appName, agentAddr, "sendErrorTip", "协议解析错误!")
    ---return
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
    return userMap:getObject(uid)
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

