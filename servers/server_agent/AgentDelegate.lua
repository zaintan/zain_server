local skynet    = require "skynet"
local socket    = require "skynet.socket"

local class = {mt = {}}
class.mt.__index = class

--[[ info = {
    watchdog;
    gate;
    client_fd;
    address;
    agent;
    appName;
}]]--
function class.create(info)
	local self = {}
	setmetatable(self, class.mt)

	for k,v in pairs(info or {}) do
        self[k] = v
    end

    self.agentSign   = os.time()
    self:active()

    skynet.error("CMD start called on fd ", self.client_fd)
    skynet.call(self.gate, "lua", "forward", self.client_fd)
    skynet.fork(function ()
        while true do 
            -- 3 seconds to send heart beat
            -- 10 seconds to break
            if self:timeoutCheck(3,  10) then 
                return 
            end 
            self:sendClientPacket(self:packHeartBeat())
            skynet.sleep(heartbeat * 100)
        end 
    end)
    return self
end

function class:timeoutCheck( heartbeat, timeout )
    if skynet.time() - self.last_update >= timeout then 
        self:kickMe()
        return true
    end 
end

function class:active()
	self.last_update = skynet.time()
end

function class:getUnActiveSeconds()
	return skynet.time() - self.last_update
end


function class:kickMe()
    skynet.error("heartbeat timeout! kick me!")
    pcall(skynet.send, self.watchdog, "lua", "closeAgent", self.client_fd)
end

function class:quit()
    if self.connApp and self.connAddr then
        local flg, ret = pcall(cluster.call, self.connApp, self.connAddr, "agentQuit",
                                self.FUserCode, self.agentSign)
        if not flg or not ret then
            kickMe()
        end
    end

    if self.client_fd then 
        socket.close(self.client_fd)
    end 

    skynet.exit()    
end

function class:sendClientPacket( packet )
    if self.client_fd then 
        local data = string.pack(">s2", packet)
        socket.write(self.client_fd, data)
    end 
end

function class:command_handler(msg)
    self:active()
end

function class:packHeartBeat()
    return ""
end
return class