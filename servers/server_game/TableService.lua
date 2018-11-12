------------------------------------------------------
---! @file
---! @brief TableService, 牌桌服务
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
require "skynet.manager"
local cluster   = require "skynet.cluster"
local queue     = require "skynet.queue"

local TableFactory = require "logic.TableFactory"
---! 全局常量
local myTable

local cs  = queue()
---! lua commands
local CMD = {}

function CMD.init(roomId, roomInfo)
    --cs(function ()
        Log.i("TableService", "init roomId=%d",roomId)
        Log.dump("TableService", roomInfo)
        myTable = TableFactory.create(roomInfo.game_id, roomInfo.game_type, roomId)
        Log.i("TableService", "myTable=%s",tostring(myTable))
        if not myTable then 
            skynet.timeout(1, function ()
                skynet.exit()
            end)
            --
            return -1
        end 
        Log.i("TableService", "myTable:init ")
        local ret = myTable:init(roomInfo.game_rules, roomInfo.over_type, roomInfo.over_val)
        if not ret then 
            skynet.timeout(1, function ()
                skynet.exit()
            end)
            --
            return -1
        end 
        Log.i("TableService", "myTable:init ret=%s",tostring(ret))
        return 0
    --end)
end
--from alloc server
function CMD.join(uid, roomId, appName, agentAddr)
    cs(function ()
        return myTable:join(uid, roomId, appName, agentAddr)
    end)
end
--from agent server
function CMD.offline( uid, appName )
    cs(function ()
        return myTable:offline(uid, appName)
    end)
end

--client request
function CMD.onRequest( uid, msgId, msgBody )
    cs(function ()
        return myTable:onRequest(uid, msgId, msgBody)
    end)
end

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )

    ---! 注册skynet消息服务
    skynet.dispatch("lua", function(_,_, cmd, ...)
        local f = CMD[cmd]
        if f then
            local ret = f(...)
            if ret then
                skynet.ret(skynet.pack(ret))
            end
        else
            Log.e("TableService","unknown command:%s", cmd)
        end
    end)
    ---!
end)

