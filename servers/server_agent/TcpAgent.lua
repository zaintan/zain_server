--------------------------------------------------------------
---! @file
---! @brief tcp socket的客户连接
--------------------------------------------------------------

---! 依赖库
local skynet        = require "skynet"
local queue         = require "skynet.queue"
local cluster       = require "skynet.cluster"

local agentDelegate = require "AgentDelegate"

---!
local agent     = nil

local CMD       = {}
---! 顺序序列
local critical  = nil

---! @brief start service
function CMD.start( info )
    if not agent then 
        agent           = agentDelegate.create(info)
    else
        skynet.error("can not repeat start agent!")
    end 

    return 0
end

---! @brief 通知agent主动结束
function CMD.disconnect()
    agent:quit()
end

---! send protocal back to user socket
function CMD.sendClientPacket( packet )
    agent:sendClientPacket(packet)
end


---! handle socket data
skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return skynet.tostring(msg,sz)
	end,
	dispatch = function (session, address, text)
        skynet.ignoreret()

        local worker = function ()
            agent:command_handler(text)
        end

        xpcall( function()
            critical(worker)
        end,
        function(err)
            skynet.error(err)
            skynet.error(debug.traceback())
        end)
	end
}


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

    critical            = queue()
end)