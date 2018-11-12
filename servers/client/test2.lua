
---! 依赖库
local skynet      = require "skynet"
require "skynet.manager"
local CMD = {}

function CMD.query()
    
    local status, ret,ret2,ret3 = pcall(skynet.call,".test1","lua","test")
    skynet.error("status:"..tostring(status))
    skynet.error("ret:"..tostring(ret))
    skynet.error("ret2:"..tostring(ret2))
    skynet.error("ret3:"..tostring(ret3))
    return 0,"bbb"
end

---! 服务的启动函数
skynet.start(function()

    skynet.register(".test2")

    ---! 注册skynet消息服务
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            local ret = f(source, ...)
            if ret then
                skynet.ret(skynet.pack(ret))
            end
        else
            skynet.error("unknown command:%s", cmd)
        end
    end)
end)

