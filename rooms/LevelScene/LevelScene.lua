AssetsPath = require 'rooms.AssetsPath'
LevelButton = require 'rooms.LevelScene.LevelButton'
Timer = require 'libraries/hump/timer'
LevelScene = Object:extend()

function LevelScene:new()
    self._screenW, self._screenH = love.graphics.getDimensions()
    self:setBackGround()
    self:createBackButton()
    self:createButtonLevel()
end

function LevelScene:setBackGround()

    local hour = tonumber(os.date("%H"))
    local imgPath

    if hour < 6 or hour >= 18 then
        imgPath = AssetsPath.IMG_MMBGNIGHT        -- đêm
    elseif hour >= 6 and hour < 15 then
        imgPath = AssetsPath.IMG_MMBGMOR        -- sáng
    else
        imgPath = AssetsPath.IMG_MMBGAFTER        -- mặc định (chiều/15-18h)
    end

    self._bg = love.graphics.newImage(imgPath)
    self._bgOpacity = 175 / 255        -- Cocos 0..255 -> LÖVE 0..1

    self._bgScaleX = self._screenW / self._bg:getWidth()
    self._bgScaleY = self._screenH / self._bg:getHeight()
end

function LevelScene:drawBackground()
    if self._bg then
        love.graphics.setColor(1, 1, 1, self._bgOpacity)
        love.graphics.draw(self._bg, 0, 0, 0, self._bgScaleX, self._bgScaleY)
        love.graphics.setColor(1, 1, 1, 1)   -- reset, nếu không mọi thứ vẽ sau bị mờ
    end
end

function LevelScene:loadCurrentLevel()
    return 8
end

function LevelScene:createButtonLevel()

    -- Đọc level hiện tại đã lưu (mặc định 1 nếu chưa có)
    local levelCurrent = self:loadCurrentLevel()

    self._levelButtons = {}   -- lưu để vẽ và bắt click
    self._locks = {}

    local lockImage = love.graphics.newImage(AssetsPath.LOCK_BUTTON)
    local y = self._screenH * 2 / 3   -- bỏ VISIBLE_ORIGIN (LÖVE không có)

    for level = 1, 8 do
        local x = level * self._screenW / 9

        if level <= levelCurrent then
            local button = LevelButton(level)
            button._x = x
            button._y = y
            table.insert(self._levelButtons, button)
        else
            table.insert(self._lock,{
                image = love.graphics.newImage(AssetsPath.LOCK_BUTTON),
                _x = x,
                _y = y
            })
        end
    end
end

function LevelScene:createBackButton()
    self._backButton = {
        normal  = love.graphics.newImage(AssetsPath.BUTTON_BACK),
        clicked = love.graphics.newImage(AssetsPath.BUTTON_BACK_CLICKED),
        scale   = 1.25,
        x = self._screenW - 113.75,   -- bỏ VISIBLE_ORIGIN_X
        y = 44.5,                       -- bỏ VISIBLE_ORIGIN_Y
        pressed = false,
    }
end

function LevelScene:drawBackButton()
    local b = self._backButton
    local img = b.pressed and b.clicked or b.normal
    local w, h = img:getWidth(), img:getHeight()
    -- anchor giữa (Cocos mặc định 0.5,0.5)
    love.graphics.draw(img, b.x, b.y, 0, b.scale, b.scale, w/2, h/2)
end

function LevelScene:backButtonHitTest(px, py)
    local b = self._backButton
    local w = b.normal:getWidth() * b.scale
    local h = b.normal:getHeight() * b.scale
    return px >= b.x - w/2 and px <= b.x + w/2
       and py >= b.y - h/2 and py <= b.y + h/2
end

function LevelScene:mousepressed(px, py, button)
    if self:backButtonHitTest(px, py) then
        self._backButton.pressed = true
        return
    end
    for _, btn in ipairs(self._levelButtons) do
        btn:mousepressed(px, py, button)
    end
end

function LevelScene:mousereleased(px, py, button)
    -- back
    if self._backButton.pressed and self:backButtonHitTest(px, py) then
        gotoRoom('MainMenuScene')
    end
    self._backButton.pressed = false

    -- level buttons
    for _, btn in ipairs(self._levelButtons) do
        if btn:mousereleased(px, py, button) then
            print("[LevelScene] chon level " .. btn._level)
            gotoRoom('GameScene', btn._level)
            return
        end
    end
end

function LevelScene:update(dt)

end

function LevelScene:draw()
    self:drawBackground()

    for _, btn in ipairs(self._levelButtons) do
        btn:draw()                      -- LevelButton tự vẽ
    end
    for _, lock in ipairs(self._locks) do
        local w, h = lock.image:getWidth(), lock.image:getHeight()
        love.graphics.draw(lock.image, lock.x, lock.y, 0, 1, 1, w/2, h/2)
    end

    self:drawBackButton()
end

return LevelScene