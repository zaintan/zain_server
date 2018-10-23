---------------------------------------------------
---! @file
---! @brief 远程集群节点调用辅助 ClusterHelper
---------------------------------------------------
---! 依赖库 skynet
local skynet    = require "skynet"
local cluster   = require "skynet.cluster"

local packetHelper = require "PacketHelper"

---! ClusterHelper 模块定义
local class = {}

---! 防止读nil的key
setmetatable(class, {
    __index = function (t, k)
        return function()
            print("retrieve unknown field from ClusterHelper: ", k)
        end
    end
    })

---! 从配置获取当前节点信息
class.getNodeInfo = function ( cfg )
    local ret    = {}
    ret.appName  = skynet.getenv("app_name")
    ret.nodeName = skynet.getenv("NodeName")

    local node   = cfg.MySite[ret.nodeName]
    assert(node)
    ret.privateAddr = node[1]
    ret.publicAddr  = node[2]

    
    ret.serverKind = skynet.getenv("ServerKind")
    ret.serverIndex = tonumber(skynet.getenv("ServerNo"))
    ret.serverName  = ret.serverKind .. ret.serverIndex
    ret.numPlayers  = 0

    --代理服 必须有配 对外ip
    if ret.serverKind == "server_agent" then 
        assert(ret.publicAddr)
    end 

    local conf = cfg[ret.serverKind]
    assert(ret.serverIndex >= 0 and ret.serverIndex <= conf.maxIndex)
    local all  = {"debugPort","nodePort","tcpPort"}
    for _,key in ipairs(all) do
        if conf[key] then 
            ret[key] = conf[key] + ret.serverIndex
        end 
    end

    return ret
end
---! 获取config.cluster列表和各服务器列表
class.getAllNodes = function ( cfg, info )
    --所有的Server类型
    local all = {"server_agent","server_alloc","server_user","server_game", "server_node"}
    local ret = {}
    for nodeName,nodeValue in pairs(cfg.MySite) do
        for _,serverKind in ipairs(all) do
            local list = info[serverKind] or {}
            info[serverKind] = list

            local srv = cfg[serverKind]
            for i=0,srv.maxIndex do
                local name  = string.format("%s_%s%d",nodeName, serverKind, i)
                local value = string.format("%s:%d",nodeValue[1], srv.nodePort + i)
                ret[name] = value
                table.insert(list, name)
            end
        end
    end
    return ret
end


---! 解析集群内节点配置
--clusterList = {node1_Agent_0 = "127.0.0.1:8050", ... }
--info    = {Agent = {node1_Agent_0,node1_Agent_1,node1_Agent_2},Alloc = {},...}
class.parseConfig = function ( info )
    local cfg = packetHelper.load_config("./config/nodes.cfg")

    info.nodeInfo    = class.getNodeInfo(cfg)
    info.clusterList = class.getAllNodes(cfg, info)
end

return class