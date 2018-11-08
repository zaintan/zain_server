local BaseTable = class()

function BaseTable:ctor(game_id, game_type, room_id)
    -- body
    self.gameId   = game_id
    self.gameType = game_type
    self.roomId   = room_id
end

--根据玩法 解析局数
function BaseTable:init(rules, over_type, over_val)
	self.gameRules    = rules
    self.gameStatus   = 0;-- free 0, wait 200 ,play 100
    self.playStatus   = nil;

    self.maxPlayerNum = 4
    self.players      = {}
end

function BaseTable:getBaseProto()
	return {
		status = 0;
		game_id     = self.gameId;
		game_type   = self.gameType;
		game_rules  = self.gameRules;
		game_status = self.gameStatus;
		play_status = self.playStatus;
		over_type   = self.overType; 
		over_val    = self.overVal;
	}
end

function BaseTable:hasRule()
	-- body
end

function BaseTable:isFull()
    return #self.players >= self.maxPlayerNum
end

function BaseTable:isIntable( uid )
	return self:getPlayer(uid)
end

function BaseTable:getPlayer( uid )
	for seat,player in ipairs(self.players) do
		if player.FUserID = uid then 
			return player
		end 
	end
	return nil
end

function BaseTable:addUser(uid, appName, agentAddr)
	---待实现
	return false
end

function BaseTable:gameStart()
	-- body
end


function BaseTable:reconnect(uid, appName, agentAddr)
	local player = self:getPlayer(uid)
	player:online(appName, agentAddr)

	local reconnData = {}

	return reconnData
end

function BaseTable:broadcastMsg(protoName, data, seatIndex )
	local exceptSeat = seatIndex or -1

	for seat,player in ipairs(self.players) do
		if not player:isOffline() and exceptSeat ~= seat then 
		--local status,ret = pcall(cluster.call, )
		end 
	end
end


function BaseTable:offline(uid, appName)
	local player = self:getPlayer(uid)
	if player then 
		if player:offline(appName) then 
			return
		end 
	end 

	--下线失败 节点校验不通过
end
--from alloc server
function BaseTable:join(uid, room_id,appName, agentAddr)
	if room_id ~= self.roomId then 
		return {status = -101;status_tip = "房间号错误!"}
	end 
	--已经在房间里面了  走重连逻辑
	if self:isIntable(uid) then 
		return self:reconnect(uid, appName, agentAddr)
	end 

	if self.gameStatus ~= 0 then 
		return {status = -102;status_tip = "不可中途加入!"}
	end 

    if self:isFull() then 
        return {status = -103;status_tip = "房间已满!"}
    end 

    --加入房间逻辑
    local player = self:addUser(uid, appName, agentAddr)
    if not player then 
    	return {status = -104;status_tip = "玩家坐下失败!"}
    end 

    --推送广播其他玩家 有玩家进来了
    self:broadcastMsg("PlayerEnterPush",{ player = player:getProto();}, player.seatIndex)
    --回复自己 加入成功
    local retData   = self:getBaseProto()
    retData.players = {}
    for _,player in ipairs(self.players) do
    	table.insert(retData, player:getProto())
    end
    return retData
end
--from client
function BaseTable:onRequest( ... )
    -- body
end

function BaseTable:onReady( ... )
    if self.gameStatus == 0 or self.gameStatus == 200 then 

    end 
end



return BaseTable