Timer = require 'libraries/hump/timer'

local IMG_MMBGMOR = "assets/sprites/Background/bg_mainmenu_morning.png"
local IMG_MMBGAFTER = "assets/sprites/Background/bg_mainmenu_afternoon.png"
local IMG_MMBGNIGHT = "assets/sprites/Background/bg_mainmenu_night.png"
local IMG_NAMEGAME = "assets/sprites/Background/defensesquad.png"


MMBackgroundLayer = Object:extend()

function MMBackgroundLayer:new()
    self._screenW, self._screenH = love.graphics.getDimensions()

    self:setBackGroundImagePosition()
    self:setNameGamePosition()
end

function MMBackgroundLayer:setBackGroundImagePosition()
    local hour = tonumber(os.date("%H"))
    local imgPath, opacity

    if hour <= 6 or hour >= 18 then
        imgPath, opacity = IMG_MMBGNIGHT, 175
    elseif hour > 6 and hour < 15 then  
        imgPath, opacity = IMG_MMBGMOR, 175 
    else
        imgPath, opacity = IMG_MMBGAFTER, 150
    end

    self._bg = love.graphics.newImage(imgPath)
    self._bgOpacity = opacity/255

    self._bgScaleX = self._screenW / self._bg:getWidth()
    self._bgScaleY = self._screenH / self._bg:getHeight()
end

function MMBackgroundLayer:setNameGamePosition()
    self._timer = Timer.new()
    self._name = love.graphics.newImage(IMG_NAMEGAME)

    self._nameX = 10 + self._screenW / 2
    self._nameY = self._screenH
    self._nameScale = 1.25
    self._nameFlip = 1

    self._nameAnchorX = 0.5
    self._nameAnchorY = 0.375

    local targetY = self._screenH * 1/5
    print("[MMBackgroundLayer] targetY = " .. targetY)
    self._timer:after(0.5, function() 
        self._timer:tween(0.75, self, { _nameY = targetY}, 'linear')
        self._timer:after(0.75 + 1.0, function ()
            self:startNameSpin()
        end)
    end)
end

function MMBackgroundLayer:startNameSpin()
    local function doSpin()
        self._timer:tween(1.0, self, {_nameFlip = -1}, 'in-out-quad', function ()
            self._timer:tween(1.0, self, {_nameFlip = 1}, 'in-out-quad', function ()
                self._timer:after(12, doSpin)
            end)
        end)
    end
    doSpin()
end

function MMBackgroundLayer:update(dt)
    self._timer:update(dt)
end

function MMBackgroundLayer:draw()

        -- 1. Ảnh nền (dưới cùng)
    if self._bg then
        love.graphics.setColor(1, 1, 1, self._bgOpacity)
        love.graphics.draw(self._bg, 0, 0, 0, self._bgScaleX, self._bgScaleY)
        love.graphics.setColor(1, 1, 1, 1)   -- reset, nếu không logo bị mờ theo
    end

    local img = self._name
    local w, h = img:getWidth(), img:getHeight()

    -- LÖVE đặt origin (ox, oy) theo pixel, không phải tỉ lệ như Cocos.
    -- Anchor (0.5, 0.375) -> ox = w*0.5, oy = h*0.375
    local ox = w * self._nameAnchorX
    local oy = h * self._nameAnchorY

    love.graphics.draw(
        img,
        self._nameX, self._nameY,
        0,                                      -- rotation 2D = 0
        self._nameScale * self._nameFlip,       -- scaleX (âm = lật ngang)
        self._nameScale,                        -- scaleY
        ox, oy
    )
end

return MMBackgroundLayer