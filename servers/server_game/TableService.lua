------------------------------------------------------
---! @file
---! @brief TableService, 牌桌服务
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"

---! 全局常量
local myTable

---! lua commands
local CMD = {}

function CMD.init(roomId, roomInfo)
    myTable = (require "logic.TableFactory").create(roomInfo.game_id, roomInfo.game_type, roomId)
    
    return myTable:init(roomInfo.game_rules, roomInfo.over_type, roomInfo.over_val)
end

function CMD.join(...)
    return myTable.join(...)
end

function CMD.offline( ... )
    return myTable.offline(...)
end

--client request
function CMD.onRequest( ... )
    return myTable.onRequest(...)
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

