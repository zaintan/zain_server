---------------------------------------------------
---! @file
---! @brief 文件和网络读写，打包解包等
---------------------------------------------------

---! 依赖库

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

return class