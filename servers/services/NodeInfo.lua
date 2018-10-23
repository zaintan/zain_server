-------------------------------------------------------------
---! @file  NodeInfo.lua
---! @brief 保存当前节点信息，供其它服务使用
--------------------------------------------------------------

---! 依赖
local skynet     = require "skynet"
local cluster    = require "skynet.cluster"

local clsHelper  = require "ClusterHelper"
---! 数据
local info = {}
---! 接口
local CMD  = {}

function CMD.initNode()
	clsHelper.parseConfig(info)
	skynet.error("NodeInfo initNode parseConfig:", info)
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
end

skynet.start(start)