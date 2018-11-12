local class = {mt = {}}
class.mt.__index = class

function class.create()
	local self = {}
	setmetatable(self, class.mt)

	self:init()
    return self
end

function class:init()
	self.m_idList   = {}
	self.m_roomMap  = {} 

	self.m_curIndex = 0

	for i = 100000, 999999 do
		table.insert(self.m_idList, i)
--		self.m_roomMap[i] = {
--			gameAppName  = nil
--			tableAddr    = nil
--		}
	end 
	--打乱顺序
	for i=#self.m_idList,1,-1 do
		local randIndex = math.random(1,i)
		local tmpId = self.m_idList[randIndex]
		self.m_idList[randIndex] = self.m_idList[i]
		self.m_idList[i] = tmpId
	end
end

function class:recoverId(roomId)
	if self.m_roomMap[roomId] then 
		self.m_roomMap[roomId] = nil
	end 
end

function class:allocId()
	local count = 0

	while(true) do 
		if self.m_curIndex >= #self.m_idList then 
			self.m_curIndex = 0
		end 
		self.m_curIndex = self.m_curIndex + 1
		
		local roomId = self.m_idList[self.m_curIndex]
		if not self.m_roomMap[roomId] then 
			return roomId
		end 
		-------------------------------------------------------------------------------
		count = count + 1
		if count > 100000 then 
			Log.e("RoomIdPool","获取空余房间号遍历超过100000次 可能死循环!!!!", cmd)
		end 
		-------------------------------------------------------------------------------
	end 
end

function class:useId(roomId, gameAppName, tableAddr, creatorId)
	local t = self.m_roomMap[roomId] or {}
	t.gameAppName = gameAppName
	t.tableAddr   = tableAddr
	t.creatorId   = creatorId
	self.m_roomMap[roomId] = t
end

function class:enter( roomId, uid )
	-- body
end

function class:getRoomAddr( roomId )
	local room = self.m_roomMap[roomId]
	if room then 
		return room.gameAppName,room.tableAddr
	end 
	return nil
end


return class