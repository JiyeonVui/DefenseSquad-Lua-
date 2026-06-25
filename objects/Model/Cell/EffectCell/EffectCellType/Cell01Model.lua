CellModelDefinition = require('objects/Model/Cell/CellModelDefinition')
EffectCellMode = require('objects/Model/Cell/EffectCell/EffectCellMode')
LevelModelDefinition = require('objects/Model/LevelModelDefinition')
Cell01Model = EffectCellMode:extend()

function Cell01Model:new()

    Cell01Model.super.new(CellModelDefinition.CellId.CELL_01)

    self._rechargeTime = 12.0;
    self._effectRechargeTime = 12.0;
    self._effectTimeCounter = 9.0;
    self._distance = 0.0;
    self._cost = 50;
    self._hp = 5;
end

function Cell01Model:TakeEffect()
    -- Callback: sinh energy object tại ô của cell này
    local onEffect = function()
        if self._level ~= nil then
            self._level:addEnergyObject(self._cellX, self._cellY)
        end
    end

    -- Chạy animation hiệu ứng, truyền callback vào để gọi đúng thời điểm
    self:effectAnimate(onEffect)
end 

function Cell01Model:canPutOn(level, cellX, cellY)
    if level == nil then return false end

    local map = level:getMap()
    local maxX = #map
    local maxY = #map[1]   -- Lua index từ 1, nên map[1] thay cho map[0]

    -- Kiểm tra biên (Lua: ô hợp lệ là 0..maxX-1 nếu bạn đánh số từ 0)
    if cellX < 0 or cellX >= maxX then return false end
    if cellY < 0 or cellY >= maxY then return false end

    -- Map col-major: map[cellX][cellY]
    if map[cellX][cellY] == LevelModelDefinition.MapPosition.EMPTY_CAN_PUT then
        return true
    end
    return false
end

function Cell01Model:update(dt)

end

function Cell01Model:draw()

end

return Cell01Model