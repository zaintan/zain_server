-------------------------------------------------------------
---! @file  NodeLink.lua
---! @brief 监控当前节点，察觉异常退出
--------------------------------------------------------------

---! 依赖
local skynet      = require "skynet"
local cluster     = require "skynet.cluster"

local nodeInfoSrv = nil
local theMainNode = nil
local thisInfo    = nil


---! 向 NodeServer 注册自己
local function registerSelf()
    --自己是主节点 不用注册
    if theMainNode then 
        return 
    end 

    thisInfo = skynet.call(nodeInfoSrv, "lua", "getRegisterInfo")
    skynet.error("thisInfo.kind = ", thisInfo.kind)

    if thisInfo.kind == "server_node" then 
        skynet.error("MainNodeServer should not register itself", thisInfo.name)
        return
    end 

    local list = skynet.call(nodeInfoSrv, "lua", "getConfig", "server_node")
end


local CMD = {}

function CMD.askReg()
    skynet.fork(registerSelf)
    return 0
end

function CMD.heartBeat( num )
    --自己是主节点 不用上报
    if theMainNode then 
        return 0
    end 

    --local mainAddr = 
end

function CMD.exit()
    skynet.exit()
    return 0
end


skynet.start(function ()
    ---! 注册skynet消息服务
    skynet.dispatch("lua", function(_,_, cmd, ...)
        local f = CMD[cmd]
        if f then
            local ret = f(...)
            if ret then
                skynet.ret(skynet.pack(ret))
            end
        else
            skynet.error("unknown command ", cmd)
        end
    end)

    nodeInfoSrv = skynet.uniqueservice("NodeInfo")
    skynet.call(nodeInfoSrv, "lua", "nodeOn", skynet.self() )

    skynet.fork(registerSelf)
end)