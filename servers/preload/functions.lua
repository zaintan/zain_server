---------------------Global functon class ---------------------------------------------------
--Parameters:   super               -- The super class
--              autoConstructSuper   -- If it is true, it will call super ctor automatic,when
--                                      new a class obj. Vice versa.
--Return    :   return an new class type
--Note      :   This function make single inheritance possible.
---------------------------------------------------------------------------------------------

---
-- 用于定义一个类.
--
-- @param #table super 父类。如果不指定，则表示不继承任何类，如果指定，则该指定的对象也必须是使用class()函数定义的类。
-- @param #boolean autoConstructSuper 是否自动调用父类构造函数，默认为true。如果指定为false，若不在ctor()中手动调用super()函数则不会执行父类的构造函数。
-- @return #table class 返回定义的类。
-- @usage
function class(super, autoConstructSuper)
    local classType = {};
    classType.autoConstructSuper = autoConstructSuper or (autoConstructSuper == nil);

    if super then
        classType.super = super;
        local mt = getmetatable(super);
        setmetatable(classType, { __index = super; __newindex = mt and mt.__newindex;});
    else
        classType.setDelegate = function(self,delegate)
            self.m_delegate = delegate;
        end
    end
    return classType;
end

---------------------Global functon new -------------------------------------------------
--Parameters:   classType -- Table(As Class in C++)
--              ...        -- All other parameters requisted in constructor
--Return    :   return an object
--Note      :   This function is defined to simulate C++ new function.
--              First it called the constructor of base class then to be derived class's.
-----------------------------------------------------------------------------------------

---
-- 创建一个类的实例.
-- 调用此方法时会按照类的继承顺序，自上而下调用每个类的构造函数，并返回新创建的实例。
--
-- @param #table classType 类名。  使用class()返回的类。
-- @param ... 构造函数需要传入的参数。
-- @return #table obj 新创建的实例。
function new(classType, ...)
    local obj = {};
    local mt = getmetatable(classType);
    setmetatable(obj, { __index = classType; __newindex = mt and mt.__newindex;});
    do
        local create;
        create =
            function(c, ...)
            if c.super and c.autoConstructSuper then
                create(c.super, ...);
            end
            if rawget(c,"ctor") then
                obj.currentSuper = c.super;
                c.ctor(obj, ...);
            end
        end
        create(classType, ...);
    end
    obj.currentSuper = nil;
    return obj;
end