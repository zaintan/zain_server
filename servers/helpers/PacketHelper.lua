---------------------------------------------------
---! @file
---! @brief 文件和网络读写，打包解包等
---------------------------------------------------

---! 依赖库
local protobuf = require "protobuf"

--! create the class metatable
local class = {mt = {}}
class.mt.__index = class

---! @brief 加载配置文件, 文件名为从 servers目录计算的路径
local function load_config( filename )
    local f = assert(io.open(filename))
    local source = f:read "*a"
    f:close()
    local tmp = {}
    assert(load(source, "@"..filename, "t", tmp))()
    return tmp
end
class.load_config = load_config


local msgFiles = {}
---! PacketHelper 模块定义
--! @brief The creator for PacketHelper
--! @return return the created object
local function create (protoFile)
    local self = {}
    setmetatable(self, class.mt)

    if protoFile then
        if type(protoFile) == "string" then 
        	self:registerProtoName(protoFile)
        elseif type(protoFile) == "table" then 
        	for _,name in ipairs(protoFile) do
        		self:registerProtoName(name)
        	end
        end 
    end
    return self
end
class.create = create

---! @brief  make sure the protoFile is registered
local function registerProtoName (self, protoFile)
    if not msgFiles[protoFile] then
        protobuf.register_file(protoFile)
        msgFiles[protoFile] = true
    end
end
class.registerProtoName  = registerProtoName


---! @brief make a general proto data for client - server.
local function makeProtoData (self, main, sub, id,body)
    local msg = {
        main_type = main,
        sub_type  = sub,
        msg_id    = id,
        msg_body  = body
    }

    local packet = protobuf.encode("Zain.ProtoInfo", msg)
    return packet
end
class.makeProtoData = makeProtoData

---! 编码
local function encodeMsg (self, msgFormat, packetData)
    return protobuf.encode(msgFormat, packetData)
end
class.encodeMsg = encodeMsg

---! 解码
local function decodeMsg (self, msgFormat, packet)
    return protobuf.decode(msgFormat, packet)
end
class.decodeMsg = decodeMsg

---! 深度递归解码
local function extractMsg (self, msg)
    protobuf.extract(msg)
    return msg
end
class.extractMsg = extractMsg

return class