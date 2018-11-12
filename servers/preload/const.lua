local M = {}

M.ProtoMain  = {
    REQUEST  = 1;
    RESPONSE = 2;
    UPLOAD   = 3;
    PUSH     = 4;	
};

M.ProtoSub   = {
    GATE     = 1;
    CENTER   = 2;
    ALLOC    = 3;
    GAME     = 4;	
}

M.MsgId       = {
	LoginReq  = 1;
	LoginRsp  = 10001;
	CreateReq = 2;
	CreateRsp = 10002;
	JoinReq   = 3;
	JoinRsp   = 10003;
	HeartReq  = 4;
	HeartRsp  = 10004;
	ReadyReq  = 5;
	ReadyRsp  = 10005;
	
	CommonTipsPush  = 20001;
	PlayerEnterPush = 20002; 
	ReadyPush       = 20003;
	GameStartPush   = 20004;
}

M.GameStatus  = {
	FREE      = 0;
	WAIT      = 100;
	PLAY      = 200;
}

return M