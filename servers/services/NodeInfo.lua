-------------------------------------------------------------
---! @file  NodeInfo.lua
---! @brief 保存当前节点信息，供其它服务使用
--------------------------------------------------------------

---! 依赖
local skynet     = require "skynet"
local cluster    = require "skynet.cluster"

local clsHelper  = require "ClusterHelper"
local tblHelper  = require "TableHelper"
---! 数据
local info = {}
---! 接口
local CMD  = {}

function CMD.initNode()
	clsHelper.parseConfig(info)
	return ""
end

function CMD.getConfig( ... )
	local args = table.pack(...)
	local ret  = info
	for _,key in ipairs(args) do
		if ret[key] then 
			ret = ret[key]
		else 
			return ""
		end 
	end
	
	ret = ret or ""
	return ret
end

function CMD.getServiceAddr(key)
	local ret = info[key]
	ret = ret or ""
	return ret
end

function CMD.getRegisterInfo()
	local nodeInfo = info.nodeInfo
	local ret = {}
	ret.kind  = nodeInfo.serverKind
	ret.name  = nodeInfo.appName
	ret.addr  = nodeInfo.privateAddr
	ret.port  = nodeInfo.debugPort
	ret.numPlayers = nodeInfo.numPlayers

	--ret.conf  = nodeInfo[clsHelper.kHallConfig]
	return ret
end

function CMD.updateConfig( value, ... )
	local args = table.pack(...)
	local last = table.remove(args)

	local ret  = info
	for _,key in ipairs(args) do
		local one = ret[key]
		if not one then 
			one = {}
			ret[key] = one
		elseif type("one") ~= "table" then 
			return ""
		end 
		ret = one
	end

	ret[last] = value
	return ""
end

local function start()
	cluster.register("NodeInfo")
	skynet.dispatch("lua", function ( _,_,cmd, ...)
		local f = CMD[cmd]
		if f then 
			local ret = f(...)
			if ret then 
				skynet.ret(skynet.pack(ret))
			end 
		else
			skynet.error("unknown cmd :", cmd)
		end 
	end)

	skynet.info_func(function ()
		return tblHelper.encode(info)
	end)	
end

skynet.start(start)

--[[
info = {
	["WatchDog"]=14,

	["server_agent"]={
		[1]="node1_server_agent0",
		[2]="node1_server_agent1"
	},
	["server_alloc"]={
		[1]="node1_server_alloc0"
	},
	["server_game"]={
		[1]="node1_server_game0",
		[2]="node1_server_game1"
	},
	["server_center"]={
		[1]="node1_server_user0"
	},	
	["clusterList"]={
		["node1_server_agent1"]    = "127.0.0.1:8051",
		["node1_server_game0"]     = "127.0.0.1:8250",
		["node1_server_agent0"]    = "127.0.0.1:8050",
		["node1_server_node0"]     = "127.0.0.1:8550",
		["node1_server_alloc0"]    = "127.0.0.1:8450",
		["node1_server_game1"]     = "127.0.0.1:8251",
		["node1_server_user0"]     = "127.0.0.1:8350"
	},
	["nodeInfo"]={
		["debugPort"]	= 8000,
		["serverKind"]  = "server_agent",
		["numPlayers"]  = 0,
		["nodeName"]    = "node1",
		["tcpPort"]     = 8100,
		["privateAddr"] = "127.0.0.1",
		["serverName"]  = "server_agent0",
		["nodePort"]    = 8050,
		["publicAddr"]  = "111.230.152.22",
		["serverIndex"] = 0,
		["appName"]     = "node1_server_agent0"
	},
};
]]--