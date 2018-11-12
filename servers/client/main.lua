------------------------------------------------------
---! @file
---! @brief Client 的启动文件
------------------------------------------------------

---! 依赖库
local skynet      = require "skynet"
local Client      = require "Client"

local delegate = nil

local function main_loop ()
    delegate:stage_login()
end

local function tickFrame ()
    while true do
        delegate:tickFrame()
        skynet.sleep(10)
    end
end

---! 服务的启动函数
skynet.start(function()

   -- delegate = new Client()
   -- skynet.fork(tickFrame)
   -- skynet.fork(main_loop)
    skynet.uniqueservice("test1") 
    local addr = skynet.uniqueservice("test2")   
    skynet.error("====================================",skynet.time())
    skynet.call(addr,"lua","query")
    skynet.error("====================================",skynet.time())
end)

