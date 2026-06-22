LevelButton = Object:extend()

function LevelButton:new(level,x,y)
    self._level = level
    self._x = x or 0
    self._y = y or 0
    self._scale = 1
    self._pressed = false

    -- Dựng đường dẫn ảnh theo số level (giống std::string ghép chuỗi bên C++)
    local base = "assets/sprites/objects/button/levelButton/numberic"
    self._normal  = love.graphics.newImage(base .. level .. ".png")
    self._clicked = love.graphics.newImage(base .. level .. "_clicked.png")

    print("[LevelButton] tao level " .. level) 
end
-- Kiểm tra điểm (px,py) có nằm trong nút không
function LevelButton:hitTest(px, py)
    local w = self._normal:getWidth() * self._scale
    local h = self._normal:getHeight() * self._scale
    return px >= self._x - w/2 and px <= self._x + w/2
       and py >= self._y - h/2 and py <= self._y + h/2
end

function LevelButton:mousepressed(px, py, button)
    if button ~= 1 then return end
    if self:hitTest(px, py) then
        self._pressed = true
    end
end

-- Trả về true nếu nút được kích hoạt (thả chuột trên đúng nút)
function LevelButton:mousereleased(px, py, button)
    if button ~= 1 then return false end
    local activated = self._pressed and self:hitTest(px, py)
    self._pressed = false
    return activated
end

function LevelButton:update(dt)

end

function LevelButton:draw()
    local img = self._pressed and self._clicked or self._normal
    local w, h = img:getWidth(), img:getHeight()
    -- anchor giữa (Cocos mặc định 0.5, 0.5)
    love.graphics.draw(img, self._x, self._y, 0, self._scale, self._scale, w/2, h/2)
end

return LevelButton