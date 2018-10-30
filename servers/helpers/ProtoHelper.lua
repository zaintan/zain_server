local M = {}
M.IdToName = {
	[1]     = "LoginRequest";
	[10001] = "LoginResponse";
	[2]     = "CreateRoomRequest";
	[10002] = "CreateRoomResponse";
	[3]     = "JoinRoomRequest";
	[10003] = "JoinRoomRoomResponse";
	[4]     = "HeartRequest";
	[10004] = "HeartResponse";

	[20001] = "CommonTipsPush";
};
M.NameToId = nil;

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