local TableFactory = {}

--local CreateMap = {
--    
--}

function TableFactory.create(game_id, game_type, room_id)
    return new(require("logic.BaseTable"), game_id, game_type, room_id)
end


return TableFactory