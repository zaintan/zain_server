
---! 依赖库
local skynet      = require "skynet"
require "skynet.manager"
local CMD = {}

function CMD.test()
	skynet.error("============test",skynet.time())
	skynet.sleep(100)--0.01
	skynet.error("============test before ignoreret",skynet.time())
	--skynet.ignoreret()
	skynet.error("============test after ignoreret",skynet.time())
	skynet.sleep(100)--0.01
	return "ddd",nil,3
end

---! 服务的启动函数
skynet.start(function()

    skynet.register(".test1")

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

