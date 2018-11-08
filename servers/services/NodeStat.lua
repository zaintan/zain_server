-------------------------------------------------------------
---! @file  NodeStat.lua
---! @brief 调试当前节点，获取运行信息
--------------------------------------------------------------

local skynet    = require "skynet"
local strHelper = require "StringHelper"

local function agent_info(nodeInfo,srv)
	local watchdog = skynet.call(srv, "lua", "getServiceAddr", "WatchDog")
	if watchdog == "" then 
		return "WatchDog service has not start yet!"
	end 

	local stat = skynet.call(watchdog, "lua", "getStat")
	local arr  = {nodeInfo.appName}
	table.insert(arr, string.format("Tcp: %d", stat.tcp))
	table.insert(arr, string.format("总人数: %d", stat.sum))	
    return strHelper.join(arr, "\t")	
end

local function game_info()
	return ""
end

local function center_info()
	return ""
end

local function alloc_info(nodeInfo,srv)
	local allocAddr = skynet.call(srv, "lua", "getConfig", "AllocService")
	if not allocAddr or allocAddr == "" then 
		return "AllocService has not start yet!"
	end 

	local stat = skynet.call(allocAddr, "lua", "getStat")
	local arr  = {nodeInfo.appName}
	for _,v in ipairs(stat or {}) do
		table.insert(arr, string.format("name:%s isActive:%s tableNum:%d playerNum:%d",v.appName, tostring(v.active), v.tableNum, v.playerNum))
	end
    return strHelper.join(arr, "\n")
end

local DumpFuncMap = {
	["server_agent"]   = agent_info;
	["server_game"]    = game_info;
	["server_center"]  = center_info;
	["server_alloc"]   = alloc_info;
}

local function dump_info()
	local srv      = skynet.uniqueservice("NodeInfo")
	local nodeInfo = skynet.call(srv, "lua", "getConfig", "nodeInfo")
	local func     = DumpFuncMap[nodeInfo.serverKind]
	if func then 
		return func(nodeInfo, srv)
	end 
	return "Not Support ServerKind:" .. nodeInfo.serverKind
end

skynet.start(function()
    skynet.info_func(dump_info)
end)