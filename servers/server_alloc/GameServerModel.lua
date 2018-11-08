local class = {mt = {}}
class.mt.__index = class

function class.create(appName, address)
	local self = {}
	setmetatable(self, class.mt)

	self.tableNum  = 0
    self.playerNum = 0
    self.appName   = appName
    self.address   = address
    self.active    = true
    
    self.failedCount = 0
    return self
end

function class:isActive( )
	return self.active
end

function class:retire()
	self.active = false
end

function class:getClusterAddr()
	return self.appName
end


return class