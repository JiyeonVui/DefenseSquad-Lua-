-- Constants.lua
-- Các hằng số game, port từ định nghĩa C++ (#define + enum MapPosition)

local LevelModelDefinition = {}

-- Loại ô trên bản đồ (gốc: enum MapPosition).
-- Lua không có enum; dùng hằng số có tên với giá trị số giữ NGUYÊN như C++
-- để logic so sánh map[x][y] và các phép tính offset (vd EMPTY_CAN_PUT_OCCUPIED - EMPTY_CAN_PUT) vẫn đúng.
LevelModelDefinition.MapPosition = {
    EMPTY_CAN_PUT          = 0,
    ENEMY_PATH             = 1,
    ENEMY_PATH_END         = 2,
    EMPTY_CANNOT_PUT       = 3,
    EMPTY_CAN_PUT_OCCUPIED = 4,
    ENEMY_PATH_OCCUPIED    = 5,
}

-- Các #define cấu hình
LevelModelDefinition.UPDATING_FREQUENCY  = 0.01    -- bước tick cố định ở bản gốc; ở LÖVE nên thay bằng dt
LevelModelDefinition.ACCEPTING_TIME_ERROR = 0.0001 -- sai số chấp nhận khi so khớp thời gian
LevelModelDefinition.DUMP_CAPACITY       = 100     -- ngưỡng dọn rác cho dump list
LevelModelDefinition.MAX_ENERGY          = 9000
LevelModelDefinition.MAX_GOLD            = 999990

return LevelModelDefinition