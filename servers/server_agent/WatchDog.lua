-------------------------------------------------------------
---! @file
---! @brief watchdog, 监控游戏连接
--------------------------------------------------------------

---! 系统依赖
local skynet       = require "skynet"

---! 辅助依赖
local NumSet       = require "NumSet"

local myInfo      = nil
local nodeInfoSvr = nil

local allocApp    = nil
local centerApp   = nil 

---! gateserver's gate service
local gate        = nil
---! all agents
local tcpAgents   = NumSet.create()

---! @brief close agent on socket fd
local function close_agent( fd, bNotiCenter, bNotiGame)
    local info = tcpAgents:getObject(fd)
    if info then 
        tcpAgents:removeObject(fd)

        pcall(skynet.send, info.agent, "lua", "disconnect", bNotiCenter, bNotiGame)
    else
        Log.e("WatchDog","unable to close agent, fd = ",fd)
    end 
end

---!  socket handlings, SOCKET.error, SOCKET.warning, SOCKET.data
---!         may not called after we transfer it to agent
local SOCKET = {}

---! @brief new client from gate, start an agent and trasfer fd to agent
function SOCKET.open( fd, addr )
    local info = tcpAgents:getObject(fd)
    if info then 
        close_agent(fd, true, true)
    end 

    Log.i("WatchDog","tcp agent start fd:%d, addr:%s",fd, addr)
    local agent = skynet.newservice("TcpAgent")

    local info = {}
    info.watchdog   = skynet.self()
    info.gate       = gate
    info.client_fd  = fd
    info.address    = string.gsub(addr, ":%d+", "")
    info.agent      = agent
    info.appName    = myInfo.appName
    info.centerApp  = centerApp
    info.allocApp   = allocApp

    tcpAgents:addObject(info, fd)

    skynet.call(agent, "lua", "start", info)
    return 0
end

---! @brief close fd, is this called after we transfer it to agent ?
function SOCKET.close( fd )
    Log.i("WatchDog","socket close:%d", fd)
    --0.01s * 10 = 0.1s
    skynet.timeout(10, function ()
        close_agent(fd, true, true)
    end)

    return ""
end

---! @brief error on socket, is this called after we transfer it to agent ?
function SOCKET.error( fd, msg)
    Log.e("WatchDog","socket error fd:%d, err:%s", fd, msg or "")

    skynet.timeout(10, function ()
        close_agent(fd, true, true)
    end)
end

---! @brief warnings on socket, is this called after we transfer it to agent ?
function SOCKET.warning(fd, size)
    -- size K bytes havn't send out in fd
    Log.w("WatchDog","socket warning fd:%d, size:%d", fd, size)
end

---! @brief packets on socket, is this called after we transfer it to agent ?
function SOCKET.data(fd, msg)
end

---! skynet service handlings
local CMD = {}
---! @brief this function may not be called after we transfer fd to agent
function CMD.closeAgent(fd,bNotiCenter, bNotiGame)
    skynet.timeout(10, function()
        close_agent(fd,bNotiCenter, bNotiGame)
    end)
    return 0
end

function CMD.getStat ()
    local stat = {}
    stat.tcp = tcpAgents:getCount()
    stat.sum = stat.tcp
    return stat
end


---! 注册LoginWatchDog的处理函数，一种是skynet服务，一种是socket
local function registerDispatch()
    skynet.dispatch("lua", function ( session, source, cmd, subcmd, ... )
        if cmd == "socket" then 
            local f = SOCKET[subcmd]
            if f then 
                f(...)
            else
                Log.e("WatchDog","unknown sub command:%d for cmd:%d ",subcmd,cmd)
            end 
            --socket api don't need return
        else 
            local f = CMD[cmd]
            if f then 
                local ret = f(subcmd, ...)
                if ret then 
                    skynet.ret(skynet.pack(ret))
                end 
            else 
                Log.e("WatchDog","unknown command:%s",cmd)
            end
        end
    end)
end

---! 开启 watchdog 功能, tcp/web
local function startWatch ()
    ---! 获得NodeInfo 服务 注册自己
    nodeInfoSvr = skynet.uniqueservice("NodeInfo")
    skynet.call(nodeInfoSvr, "lua", "updateConfig", skynet.self(), "WatchDog")

    myInfo = skynet.call(nodeInfoSvr, "lua", "getConfig", "nodeInfo")

    centerApp = skynet.call(nodeInfoSvr, "lua", "getConfig", "server_center")[1]
    allocApp  = skynet.call(nodeInfoSvr, "lua", "getConfig", "server_alloc")[1]
    
    ---! 启动gate
    local publicAddr = "0.0.0.0"
    gate = skynet.newservice("gate")
    skynet.call(gate, "lua", "open", {
        address   = publicAddr,
        port      = myInfo.tcpPort,  ---! 监听端口 8200 + serverIndex
        maxclient = 2048,            ---! 最多允许 2048 个外部连接同时建立  注意本数值，当客户端很多时，避免阻塞
        nodelay   = true,            ---! 给外部连接设置  TCP_NODELAY 属性
    })
end

--[[
-- 心跳, 汇报在线人数
local function loopReport ()
    local timeout = 60  -- 60 seconds
    while true do
        local stat = CMD.getStat()

        local centerList = skynet.call(nodeInfoSvr,  "lua", "getConfig", "server_center") 
        --向中心服 上报当前在线人数
        if centerList and #centerList == 1 then 
            pcall(cluster.send, centerList[1], ".ServerStatus" ,"lua", "heartBeat", stat.sum)
        end

        skynet.sleep(timeout * 100)
    end
end
]]
---! 启动函数
skynet.start(function()
    registerDispatch()
    startWatch()
    --skynet.fork(loopReport)
end)
