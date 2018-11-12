local BaseUser = class()

function BaseUser:ctor(info, seat)

    for k,v in pairs(info) do
        self[k] = v
    end
    --self.FUserID      = uid
    --self.FUserName    = ""--userInfo.FUserName
    --self.FHeadUrl     = ""--userInfo.FHeadUrl
    --self.appName      = nil;
    --self.agentAddr    = nil;

    self.score        = 0
    self.seatIndex    = seat or 0  
    self.playerStatus = 0

    self.ready        = false
end

function BaseUser:getProto()
    return {
        user_id   = self.FUserID;
        user_name = self.FUserName;
        head_img_url = self.FHeadUrl;
        score        = self.score;
        seat_index   = self.seatIndex;
        ready        = self.ready;
    }
end

function BaseUser:online( appName, agentAddr )
    self.appName = appName
    self.agentAddr = agentAddr
end

function BaseUser:offline( appName )
    if self.appName == appName then 
        self.appName   = nil
        self.agentAddr = nil
        return true
    end 
    return false
end

function BaseUser:isOffline()
    return self.appName == nil
end

function BaseUser:setReady( bVal )
    self.ready = bVal and true or false
end


return BaseUser