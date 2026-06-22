local MM_PLAY_LAYER_FILENAME = "assets/sprites/objects/button/play_layer_button_mainmenu.png"
local MM_PLAY_LAYER_CLICKED_FILENAME = "assets/sprites/objects/button/play_layer_button_mainmenu_clicked.png"
local MM_OPTIONS_LAYER_FILENAME = "assets/sprites/objects/button/options_layer_button_mainmenu.png"
local MM_OPTIONS_LAYER_CLICKED_FILENAME = "assets/sprites/objects/button/options_layer_button_mainmenu_clicked.png"
local MM_QUIT_LAYER_FILENAME = "assets/sprites/objects/button/quit_layer_button_mainmenu.png"
local MM_QUIT_LAYER_CLICKED_FILENAME = "assets/sprites/objects/button/quit_layer_button_mainmenu_clicked.png"

Timer = require 'libraries/hump/timer'

MMControl = Object:extend()

function MMControl:new()
    self._screenW, self._screenH = love.graphics.getDimensions()
    self._timer = Timer.new()

    self:addButtonMenu()
end

function MMControl:goToLevelScene()
    print("[MMControl] goToLevelScene -> LevelScene")
    gotoRoom('LevelScene')
end

function MMControl:goToOptions()
    print("[MMControl] goToOptions - chuyen sang OptionsScene")
end

function MMControl:exitGame()
    love.event.quit()
end 

function MMControl:addButtonMenu()
    self._buttons = {
        {
            normal  = love.graphics.newImage(MM_PLAY_LAYER_FILENAME),
            clicked = love.graphics.newImage(MM_PLAY_LAYER_CLICKED_FILENAME),
            action  = function() self:goToLevelScene() end,
            spinDelay = 14,
        },
        {
            normal  = love.graphics.newImage(MM_OPTIONS_LAYER_FILENAME),
            clicked = love.graphics.newImage(MM_OPTIONS_LAYER_CLICKED_FILENAME),
            action  = function() self:goToOptions() end,
            spinDelay = 16,
        },
        {
            normal  = love.graphics.newImage(MM_QUIT_LAYER_FILENAME),
            clicked = love.graphics.newImage(MM_QUIT_LAYER_CLICKED_FILENAME),
            action  = function() self:exitGame() end,
            spinDelay = 18,
        },
    }

    self._scale = 1.25
    self._padding = 9.5          -- alignItemsVerticallyWithPadding(9.5)
    self._pressedIndex = nil     -- nút đang được nhấn giữ

    -- Khởi tạo trạng thái động cho từng nút
    for _, b in ipairs(self._buttons) do
        b.flip = 1              -- scaleX cho hiệu ứng lật trục Y
        b.x = self._screenW / 2
        b.y = self._screenH + 200  -- bắt đầu dưới màn (ngoài khung nhìn)
    end

    self:layout()               -- tính vị trí đích theo dạng menu dọc
    self:startIntro()    
end
-- Tính vị trí đích của cả cụm menu (căn giữa ngang, xếp dọc)
function MMControl:layout()
    -- Chiều cao tổng = tổng cao các nút (đã scale) + padding giữa
    local totalH = 0
    for i, b in ipairs(self._buttons) do
        totalH = totalH + b.normal:getHeight() * self._scale
        if i < #self._buttons then totalH = totalH + self._padding end
    end

    -- Tâm cụm menu: tương đương HEIGHT/3 + 50 trong bản gốc (đã quy đổi trục Y)
    local centerY = self._screenH * 2 / 3 - 50
    local startY = centerY - totalH / 2

    -- Gán toạ độ đích (targetX, targetY) cho mỗi nút
    local y = startY
    for _, b in ipairs(self._buttons) do
        local h = b.normal:getHeight() * self._scale
        b.targetX = self._screenW / 2
        b.targetY = y + h / 2     -- tâm nút
        y = y + h + self._padding
    end
end

-- Chuỗi mở màn: delay 0.5 -> bay vào (nảy) -> delay 1.0 -> bắt đầu xoay
function MMControl:startIntro()
    self._timer:after(0.5, function()
        -- Cả cụm bay vào: tween x,y từng nút tới đích
        for _, b in ipairs(self._buttons) do
            self._timer:tween(0.75, b, { x = b.targetX, y = b.targetY }, 'linear')
        end

        self._timer:after(0.75 + 1.0, function()
            -- Mỗi nút bắt đầu vòng xoay với chu kỳ riêng
            for _, b in ipairs(self._buttons) do
                self:startSpin(b)
            end
        end)
    end)
end

-- Xoay quanh trục Y (giả lập bằng scaleX: 1 -> -1 -> 1), xong delay rồi lặp
function MMControl:startSpin(b)
    local function doSpin()
        self._timer:tween(1.0, b, { flip = -1 }, 'in-out-quad', function()
            self._timer:tween(1.0, b, { flip = 1 }, 'in-out-quad', function()
                self._timer:after(b.spinDelay, doSpin)
            end)
        end)
    end
    doSpin()
end


function MMControl:update(dt)
    self._timer:update(dt)
end

function MMControl:draw()
    for i, b in ipairs(self._buttons) do
        -- Đổi ảnh khi đang nhấn nút này
        local img = (self._pressedIndex == i) and b.clicked or b.normal
        local w, h = img:getWidth(), img:getHeight()

        love.graphics.draw(
            img,
            b.x, b.y,
            0,
            self._scale * b.flip,   -- scaleX (âm = lật)
            self._scale,            -- scaleY
            w / 2, h / 2           -- anchor giữa (Cocos MenuItem mặc định 0.5,0.5)
        )
    end
end

-- ---- Click detection (phần Cocos làm tự động, LÖVE phải tự viết) ----

-- Kiểm tra điểm (px,py) có nằm trong vùng nút i không (theo bounding box)
function MMControl:hitTest(i, px, py)
    local b = self._buttons[i]
    local w = b.normal:getWidth() * self._scale
    local h = b.normal:getHeight() * self._scale
    local left = b.x - w / 2
    local top  = b.y - h / 2
    return px >= left and px <= left + w and py >= top and py <= top + h
end

function MMControl:mousepressed(px, py, button)
    if button ~= 1 then return end
    for i = 1, #self._buttons do
        if self:hitTest(i, px, py) then
            self._pressedIndex = i   -- đổi sang ảnh "clicked"
            return
        end
    end
end

function MMControl:mousereleased(px, py, button)
    if button ~= 1 then return end
    -- Chỉ kích hoạt nếu thả chuột trên đúng nút đã nhấn (giống hành vi nút chuẩn)
    if self._pressedIndex and self:hitTest(self._pressedIndex, px, py) then
        self._buttons[self._pressedIndex].action()
    end
    self._pressedIndex = nil
end


return MMControl