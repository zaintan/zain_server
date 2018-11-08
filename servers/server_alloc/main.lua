------------------------------------------------------
---! @file
---! @brief server_alloc 的启动文件
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    ---! 启动NodeInfo
    local nodeInfo = skynet.uniqueservice("NodeInfo")
    skynet.call(nodeInfo, "lua", "initNode")

    ---! 启动debug_console服务
    local port = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo", "debugPort")
    assert(port > 0)
    Log.i("Main","debug port is:%d", port)
    --print("debug port is", port)
    skynet.newservice("debug_console", port)

    ---! 集群处理
    local list = skynet.call(nodeInfo, "lua", "getConfig", "clusterList")
    list["__nowaiting"] = true
    cluster.reload(list)

    --app_name = NodeName .. "_" .. ServerKind .. ServerNo  ex:node1_server_center_0
    local appName = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo", "appName")
    cluster.open(appName)

    ---! 启动 info :d 节点状态信息 服务
    skynet.uniqueservice("NodeStat") 

    ---! 启动 CenterService 服务
    skynet.uniqueservice("AllocService")
    
    ---! 启动好了，没事做就退出
    skynet.exit()
end)