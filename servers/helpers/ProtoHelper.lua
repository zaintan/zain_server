local M = {}
M.IdToName = {
	[const.MsgId.LoginReq]       = "LoginRequest";
	[const.MsgId.LoginRsp]       = "LoginResponse";
	[const.MsgId.CreateReq]      = "CreateRoomRequest";
	[const.MsgId.CreateRsp]      = "CreateRoomResponse";
	[const.MsgId.JoinReq]        = "JoinRoomRequest";
	[const.MsgId.JoinRsp]        = "JoinRoomRoomResponse";
	[const.MsgId.HeartReq]       = "HeartRequest";
	[const.MsgId.HeartRsp]       = "HeartResponse";
	[const.MsgId.ReadyReq]       = "ReadyRequest";
	[const.MsgId.ReadyRsp]       = "ReadyResponse";	

	[const.MsgId.CommonTipsPush]  = "CommonTipsPush";
	[const.MsgId.PlayerEnterPush] = "PlayerEnterPush";
	[const.MsgId.ReadyPush]       = "ReadyPush";
	[const.MsgId.GameStartPush]   = "GameStartPush";			
};
M.NameToId = nil;

M.ResponseBase = 10000;

function M.init()
	if M.NameToId == nil then 
		M.NameToId = {}
		for k,v in pairs(M.IdToName) do
			M.NameToId[v] = k
		end
	end 
	return M
end
return M