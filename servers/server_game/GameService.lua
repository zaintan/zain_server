------------------------------------------------------
---! @file
---! @brief GameService
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
require "skynet.manager"
local cluster   = require "skynet.cluster"

---! 辅助依赖
local NumSet       = require "NumSet"


---! 全局常量
local nodeInfo     = nil
local appName      = nil
local allocAppName = nil
local LOGTAG       = "GameService"


---! lua commands
local CMD = {}

function CMD.askReg()
    skynet.timeout(10, function ()
        CMD.reg()
    end)
end

function CMD.reg()
    pcall(cluster.call, allocAppName, ".AllocService", "regServer", appName, skynet.self())
end

function CMD.createTable(roomId, data)
    local tableAddr = skynet.newservice("TableService")
    skynet.call(tableAddr, "lua", "init",roomId, data)
    return tableAddr
end

function CMD.dissolveTable(roomId)
    -- body
end


---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )
    skynet.register(".GameService")

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
    skynet.call(nodeInfo, "lua", "updateConfig", skynet.self(), "GameService")

    ---! 获得appName
    appName = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo", "appName")

    allocAppName = skynet.call(nodeInfo, "lua", "getConfig", "server_alloc")[1]

    skynet.fork(CMD.reg)
end)

