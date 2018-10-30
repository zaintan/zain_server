------------------------------------------------------
---! @file
---! @brief CenterService, 保存所有连接节点信息
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

---! 帮助库
--local clsHelper    = require "ClusterHelper"
--local filterHelper = require "FilterHelper"
--local strHelper    = require "StringHelper"

---! 全局常量
local nodeInfo = nil
local appName = nil

--local servers = {}
--local main = {}

---! lua commands
local CMD = {}

function CMD.askAll()
--    servers = {"server_agent","server_alloc"}--

--    local all  = skynet.call(nodeInfo, "lua", "getConfig", "server_agent")
--    local list = skynet.call(nodeInfo, "lua", "getConfig", "server_alloc")
--    local list = skynet.call(nodeInfo, "lua", "getConfig", "server_game")
--    for _, v in ipairs(list) do
--        table.insert(all, v)
--    end--

--    for _, app in ipairs(all) do
--        local addr = clsHelper.cluster_addr(app, clsHelper.kNodeLink)
--        if addr then
--            pcall(cluster.call, app, addr, "askReg")
--        end
--    end
end

---! get the server stat
function CMD.getStat ()

end

function CMD.login( args )
    if true then
        Log.i("CenterService","handleLoginRequest")
        Log.dump("CenterService", args)
        return {status = "ok";}
    end 
end

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )
    skynet.register(".CenterService")

    ---! 注册skynet消息服务
    skynet.dispatch("lua", function(_,_, cmd, ...)
        local f = CMD[cmd]
        if f then
            local ret = f(...)
            if ret then
                skynet.ret(skynet.pack(ret))
            end
        else
            Log.e("CenterService","unknown command:%d", cmd)
        end
    end)

    ---! 获得NodeInfo 服务
    nodeInfo = skynet.uniqueservice("NodeInfo")

    ---! 注册自己的地址
    skynet.call(nodeInfo, "lua", "updateConfig", skynet.self(), "CenterService")

    ---! 获得appName
    appName = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo", "appName")

    ---! ask all nodes to register
    skynet.fork(CMD.askAll)
end)

