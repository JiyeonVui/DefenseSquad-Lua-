CellModelDefinition = require('objects/Model/Cell/CellModelDefinition')
EffectCellMode = require('objects/Model/Cell/EffectCell/EffectCellMode')
LevelModelDefinition = require('objects/Model/LevelModelDefinition')
Cell02Model = EffectCellMode:extend()

function Cell02Model:new()

    Cell02Model.super.new(CellModelDefinition.CellId.CELL_02)

    self._rechargeTime = 20.0;
    self._distance = 0.0;
    self._cost = 50;
    self._hp = 60;

    self._effectRechargeTime = 30.0;
    self._effectTimeCounter = 30.0;
end



function Cell02Model:canPutOn(level, cellX, cellY)
    if level == nil then return false end

    local map = level:getMap()
    local maxX = #map
    local maxY = #map[1]   -- Lua index từ 1, nên map[1] thay cho map[0]

    -- Kiểm tra biên (Lua: ô hợp lệ là 0..maxX-1 nếu bạn đánh số từ 0)
    if cellX < 0 or cellX >= maxX then return false end
    if cellY < 0 or cellY >= maxY then return false end

    -- Map col-major: map[cellX][cellY]
    if map[cellX][cellY] == LevelModelDefinition.MapPosition.ENEMY_PATH then
        return true
    end
    return false
end

function Cell02Model:update(dt)

end

function Cell02Model:draw()

end

return Cell02Model