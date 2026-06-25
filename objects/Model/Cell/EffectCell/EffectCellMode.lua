local CellModel = require("objects/Model/CellModel")

EffectCellMode = CellModel:extend()

function EffectCellMode:new(id)
    EffectCellMode.super.new(self, id)
    self._effectTimeCounter = 0
    self._effectRechargeTime = self._rechargeTime
end

function EffectCellMode:update(dt)
    EffectCellMode.super.update(self, dt)
    
    if self._alive and self._level ~= nil then
        self._effectTimeCounter = self._effectTimeCounter - dt

        if self._effectTimeCounter <= 0 then
            self._effectTimeCounter = self._effectRechargeTime
            self:effectAnimate()
            self:takeEffect()
            self:idleAnimate()
        end

    end
    
end

function EffectCellMode:draw()

end

return EffectCellMode