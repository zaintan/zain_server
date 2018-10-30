----------------------------------
---! @file
---! @brief server_agent 的启动配置文件
----------------------------------
local _root		= "./"
local _skynet	= _root.."../skynet/"

---! server_agent 用到的参数 从 命令行传的参数
NodeName    =  "$NodeName"
ServerKind  =  "server_agent"
ServerNo    =  "$ServerNo"

----------------------------------
---!  自定义参数
----------------------------------
app_name    	= NodeName .. "_" .. ServerKind .. ServerNo
app_root    	= _root.. ServerKind .."/"

----------------------------------
---!  skynet用到的六个参数
----------------------------------
---!  工作线程数
thread      = 4
---!  服务模块路径（.so)
cpath       = _skynet.."cservice/?.so"
---!  港湾ID，用于分布式系统，0表示没有分布
harbor      = 0
---!  后台运行用到的 pid 文件
daemon      = nil
---!  日志文件
-- logger      = nil
--logger      = _root .. "/logs/" .. app_name .. ".log"
logpath     = _root .. "/logs/"
---!  初始启动的模块
bootstrap   = "snlua bootstrap"

---!  snlua用到的参数
lua_path    = _skynet.."lualib/?.lua;"..app_root.."?.lua;".._root .."algos/?.lua;".._root.."helpers/?.lua;".._root.."services/?.lua"
lua_cpath   = _skynet.."luaclib/?.so;"..app_root.."cservice/?.so"
luaservice  = _skynet.."service/?.lua;".. app_root .. "?.lua;" .._root.."services/?.lua;".._root.."managers/?.lua"
lualoader   = _skynet.."lualib/loader.lua"
preload     = _root.."preload/".."init.lua"	-- run preload.lua before every lua service run

start       = "main"

---!  snax用到的参数
snax    = _skynet.."service/?.lua;".. app_root .. "?.lua;" .._root.."services/?.lua"

---!  cluster 用到的参数
cluster = app_root.."../config/cluster.cfg"


