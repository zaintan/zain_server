---------------------------------------------------
---! @file
---! @brief 字符串辅助处理
---------------------------------------------------

---! 模块定义
local class = {}

---! @brief 分割字符串
---! @param text 被分割的字符串
---! @param regularExp 用来表示间隔的正则表达式 默认是空格区分 "[^%s]+"
---! @return 返回分割后的字符串数组
local function split (text, regularExp)
    text = text or ""
    regularExp = regularExp or "[^%s]+"

    local arr = {}
    for w in string.gmatch(text, regularExp) do
        table.insert(arr, w)
    end
    return arr
end
class.split = split

---! @brief 合并字符串数组
---! @param arr 需要合并的字符串数组
---! @param sep 间隔符
---! @return 返回合并后的字符串
local function join (arr, sep)
    arr = arr or {}
    sep = sep or " "

    local str = nil
    for _, txt in ipairs(arr) do
        txt = tostring(txt)
        if str then
            str = str .. sep .. txt
        else
            str = txt
        end
    end

    str = str or ""
    return str
end
class.join = join


return class

