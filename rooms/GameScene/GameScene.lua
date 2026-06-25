local LevelModel = require("objects.Model.LevelModel")
local GSMap = require("rooms.GameScene.GSMap")
local GSControlLayer = require("rooms.GameScene.GSControlLayer")

GameScene = Object:extend()

function GameScene:new(levelId)
    self._level = nil
    self._gsMap = nil
    self._control = nil
    self._bgImage = nil
    -- init

    self._level = LevelModel(levelId, self)
    self._level:startCounting()

    -- Audio

    self:setupMap()          -- DỰNG GSMap -> tạo canvas (1 lần)

    -- Tutorial

end

function GameScene:setupMap()
    self._gsMap = GSMap()
    self._gsMap:createMap(self._level)   -- dựng canvas map (1 lần)

    -- Tầng đặt cell: DÙNG CHUNG MapLayout với GSMap, rồi inject vào LevelModel.
    self._control = GSControlLayer(self._gsMap:getLayout(), self._level)
    self._level:setControlLayer(self._control)
end



function GameScene:updateLevel()

end

function GameScene:update(dt)
    self._level:update(dt)
    if self._control then self._control:update(dt) end
end

function GameScene:mousepressed(x, y, button)
    if self._control then self._control:mousepressed(x, y, button) end
end

function GameScene:mousemoved(x, y)
    if self._control then self._control:mousemoved(x, y) end
end

function GameScene:mousereleased(x, y, button)
    if self._control then self._control:mousereleased(x, y, button) end
end

function GameScene:drawMap()
    if self._gsMap then
        self._gsMap:draw()
    end
end


function GameScene:draw()
    -- 1. Background trước (zOrder -1 -> vẽ đầu, nằm dưới cùng)
    if self._bgImage then
        love.graphics.draw(self._bgImage, 0, 0)
    end

    -- 2. Map (zOrder 0 -> vẽ sau background)
    self:drawMap()

    -- 3. Entities (cell, disease, projectile) — trên map
    -- self._level:draw()

    -- 3.5 Tầng đặt cell: preview + ô gợi ý đặt được (trên map, dưới HUD)
    if self._control then self._control:draw() end

    -- 4. UI/HUD trên cùng
    -- self._level:drawHUD()
end

function GameScene:destroy()
    if self._level then
        self._level:destroy()
        self._level = nil
    end
end

return GameScene
