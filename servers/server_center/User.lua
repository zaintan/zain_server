local User = {mt = {}}
User.mt.__index = User

--[[ info = {
    watchdog;
    gate;
    client_fd;
    address;
    agent;
    appName;
    centerApp;
    allocApp;
}]]--
function User.create(info)
	local self = {}
	setmetatable(self, User.mt)

	for k,v in pairs(info or {}) do
        self[k] = v
    end
    return self
end


return User