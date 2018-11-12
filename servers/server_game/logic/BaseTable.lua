---! 依赖库
local skynet    = require "skynet"
require "skynet.manager"
local cluster   = require "skynet.cluster"
---! 帮助库
local packetHelper  = (require "PacketHelper").create("protos/ZainCommon.pb")
local ProtoHelper   = (require "ProtoHelper").init()
---!
local Player    = require "logic.BaseUser"

local BaseTable = class()

BaseTable.kCliHanderMap = {
	[5] = "onReady";
	[6] = "onOutCard";
	[7] = "onDoOperate";
	[8] = "onReleaseGame";
}

function BaseTable:ctor(game_id, game_type, room_id)
    -- body
    self.gameId   = game_id
    self.gameType = game_type
    self.roomId   = room_id
end

--根据玩法 解析局数
function BaseTable:init(rules, over_type, over_val)
	self:_initClientHanders()

	self.gameRules    = rules
    self.gameStatus   = const.GameStatus.FREE
    self.playStatus   = nil;

    self.maxPlayerNum = 4
    self.players      = {}
    return true
end

function BaseTable:_initClientHanders()
	local newHanderMap = {}
	for msg_id,funcName in pairs(self.kCliHanderMap) do
		newHanderMap[msg_id] = self[funcName]
	end
	self.kCliHanderMap = newHanderMap
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
		if player.FUserID == uid then 
			return player
		end 
	end
	return nil
end

function BaseTable:addUser(uid, appName, agentAddr)
	---待实现
	local status,data = pcall(cluster.call, player.appName, ".CenterService",  "query", uid);
	if status and data and data.FUserID then 
		retData.appName   = appName
		retData.agentAddr = agentAddr
	
		local seatIndex  = #self.players + 1
		local player = new(Player, retData, seatIndex)
		return player
	end
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


function BaseTable:broadcastMsg(msgId, data, seatIndex )
	local exceptSeat = seatIndex or -1

	for seat,player in ipairs(self.players) do
		if not player:isOffline() and exceptSeat ~= seat then 
			local status,ret = pcall(cluster.call, 
								     player.appName, 
								     player.agentAddr, 
								     "sendClientMsg", 
					                 const.ProtoMain.RESPONSE, 
					                 const.ProtoSub.GAME,msgId, 
					                 data);
		end 
	end
end


function BaseTable:offline(uid, appName)
	local player = self:getPlayer(uid)
	if player then 
		if player:offline(appName) then 
			return 0
		end 
	end 

	--下线失败 节点校验不通过
	return -1
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
    self:broadcastMsg(const.MsgId.PlayerEnterPush, {player=player:getProto();}, player.seatIndex)
    --回复自己 加入成功
    local retData   = self:getBaseProto()
    retData.players = {}
    for _,player in ipairs(self.players) do
    	table.insert(retData, player:getProto())
    end
    return retData
end
--from client
function BaseTable:onRequest( uid, msg_id, msg_body )
    -- self.FUserID, args.msg_id, args.msg_body
    local data = packetHelper:decodeMsg("Zain."..ProtoHelper.IdToName[msg_id], msg_body)
    Log.dump("BaseTable",data)

    local handler = self.kCliHanderMap[msg_id]
    if handler then 
    	return handler(self, uid, data)
    end 

    return -1
end

function BaseTable:onReady( uid, data )
    if self.gameStatus == const.GameStatus.FREE or self.gameStatus == const.GameStatus.WAIT then 
    	local player = self:getPlayer(uid)
    	if player then 
    		player:setReady(data.ready)
    		self:broadcastMsg(const.MsgId.ReadyPush,{ready = data.ready; target= player.seatIndex;}, player.seatIndex);
    		return const.MsgId.ReadyRsp,{status = 0; ready = data.ready;}
    	else	
    		Log.e("BaseTable","uid == %d is not in table:%d!", uid, self.roomId)
    	end 
    else
    	return const.MsgId.ReadyRsp,{status = -1; status_tip = "Only Free or Wait State can change ready!"};
    end 
end

function BaseTable:onReleaseGame( uid, data )
	-- body
end

function BaseTable:onDoOperate( uid, data )
	-- body
end

function BaseTable:onOutCard( uid, data )
	-- body
end

return BaseTable