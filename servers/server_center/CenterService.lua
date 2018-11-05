------------------------------------------------------
---! @file
---! @brief CenterService, 保存所有连接节点信息
------------------------------------------------------

---! 依赖库
local skynet    = require "skynet"
require "skynet.manager"
local cluster   = require "skynet.cluster"

---! 辅助依赖
local NumSet       = require "NumSet"

---! all users:  k = userid; v = User;
local userMap      = NumSet.create()
---! all quick login token;  k = token; v = accountId;
local tokenMap     = NumSet.create()

local CacheLimitCount = 10000
---! 全局常量
local nodeInfo = nil
local appName  = nil
local dbAddr   = nil

local LOGTAG   = "CenterService"

local function getDBAddr()
    if dbAddr then 
        return dbAddr
    end 
    dbAddr =  skynet.call(nodeInfo, "lua", "getConfig", "DBService")
    return dbAddr
end

local function cacheUser(userInfo)
    tokenMap[userInfo.FPlatformID] = userInfo.FUserID
    local t = {}
    t.FUserID       = userInfo.FUserID
    t.FPlatformID   = userInfo.FPlatformID
    t.FUserName     = userInfo.FUserName
    t.FHeadUrl      = userInfo.FHeadUrl
    t.FSex          = userInfo.FSex
    t.FDiamond      = userInfo.FDiamond
    t.FGold         = userInfo.FGold
    t.FPlatformType = userInfo.FPlatformType
    t.FGameIndex    = userInfo.FGameIndex
    t.FRegDate      = userInfo.FRegDate
    t.FLastLoginTime= userInfo.FLastLoginTime
    userMap[userInfo.FUserID] = t
    return t
end

--注册用户
--[[
insert into TUser(FPlatformID,FUserName,FHeadUrl,FSex,FDiamond,FGold,FPlatformType,FGameIndex,FRegDate,FLastLoginTime)
values('tzy','zaintan','','1','10','1000','3','0',NOW(),NOW());
+---------+-------------+-----------+----------+------+----------+-------+---------------+------------+------------+---------------------+
| FUserID | FPlatformID | FUserName | FHeadUrl | FSex | FDiamond | FGold | FPlatformType | FGameIndex | FRegDate   | FLastLoginTime      |
+---------+-------------+-----------+----------+------+----------+-------+---------------+------------+------------+---------------------+
|    1000 | tzy         | zaintan   |          |    1 |       10 |  1000 |             3 |          0 | 2018-11-02 | 2018-11-02 17:18:14 |
+---------+-------------+-----------+----------+------+----------+-------+---------------+------------+------------+---------------------+
]]
local function registerGuestUser(userInfo)
    local sqlStr = string.format("insert into TUser(FPlatformID,FUserName,FHeadUrl,FSex,FDiamond,FGold,FPlatformType,FGameIndex,FRegDate,FLastLoginTime) 
                                    values('%s','%s','%s','%d','%d','%d','%d','%d','%s','%s');", 
            info.FPlatformID,info.FUserName,info.FHeadUrl,info.FSex,info.FDiamond,info.FGold,info.FPlatformType,info.FGameIndex,"NOW()","NOW()");
    
    local pRet   = skynet.call(getDBAddr(), "lua", "execDB", sqlStr)
    if not pRet then 
        return false
    end    

    local sqlStr = string.format("select * from TUser where FPlatformID=\"%s\";",userInfo.FPlatformID)
    local pRet   = skynet.call(getDBAddr(), "lua", "execDB", sqlStr)
    if pRet and type(pRet) == "table" and #pRet > 0 then 
        userInfo.FUserID = tonumber(pRet[1].FUserID)
    else--找不到
        return false
    end  
    --register success
    local ret = cacheUser(userInfo)
    Log.i(LOGTAG,"register success!")
    Log.dump(LOGTAG,ret)
    return userInfo
end
--local servers = {}
--local main = {}

---! lua commands
local CMD = {}

function CMD.askAll()
--    servers = {"server_agent","server_alloc"}--

--    local all  = skynet.call(nodeInfo, "lua", "getConfig", "server_agent")
--    local list = skynet.call(nodeInfo, "lua", "getConfig", "server_alloc")
--    local list = skynet.call(nodeInfo, "lua", "getConfig", "server_game")
--    for _, v in ipairs(list) do
--        table.insert(all, v)
--    end--

--    for _, app in ipairs(all) do
--        local addr = clsHelper.cluster_addr(app, clsHelper.kNodeLink)
--        if addr then
--            pcall(cluster.call, app, addr, "askReg")
--        end
--    end
end

---! get the server stat
function CMD.getStat()

end





--required int32     login_type     = 1;
--optional string    token          = 2;
--optional int32     platform       = 3; //1=android 2=ios 3=pc
--optional string    client_version = 4;
--optional int32     game_index     = 5;

function CMD.login(source, args )
    --if true then
    Log.i(LOGTAG,"handleLoginRequest")
    Log.dump(LOGTAG, args)
    if not args.login_type or type(args.login_type) ~= "number" then 
        return {status = -1; tip = "invalid arg: login_type";}
    end 
    if not args.token or type(args.token) ~= "string" then 
        return {status = -1; tip = "invalid arg: token";}
    end 


    if args.login_type == 1 then --游客登录
        local userid =  tokenMap[args.token]
        if userid then --缓存里查到了
        else--缓存里面没有  需要去查数据库
            local sqlStr = string.format("select * from TUser where FPlatformID=\"%s\";",args.token)
            local pRet   = skynet.call(getDBAddr(), "lua", "execDB", sqlStr)
            if pRet and type(pRet) == "table" then 
                Log.dump(LOGTAG, pRet)
                if #pRet <= 0 then 
                    --register
                    registerGuestUser()
                else
                    --login
                end
            else--找不到
                return { status = -1; tip = "query db failed!"; }
            end 
        end 
    end 
end

function CMD.logout(source)
    -- body
end

---! 服务的启动函数
skynet.start(function()
    ---! 初始化随机数
    math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) )
    skynet.register(".CenterService")

    ---! 注册skynet消息服务
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = CMD[cmd]
        if f then
            local ret = f(source, ...)
            if ret then
                skynet.ret(skynet.pack(ret))
            end
        else
            Log.e(LOGTAG,"unknown command:%s", cmd)
        end
    end)

    ---! 获得NodeInfo 服务
    nodeInfo = skynet.uniqueservice("NodeInfo")

    ---! 注册自己的地址
    skynet.call(nodeInfo, "lua", "updateConfig", skynet.self(), "CenterService")

    ---! 获得appName
    appName = skynet.call(nodeInfo, "lua", "getConfig", "nodeInfo", "appName")

    ---! ask all nodes to register
    skynet.fork(CMD.askAll)
end)

