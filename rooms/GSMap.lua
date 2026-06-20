local layout = require("rooms/GSDefine") 
local brick = require("rooms/GSBrick")

GSMap = Object:extend();

function GSMap:new()
    local screenW, screenH = love.graphics.getDimensions()   -- lấy từ window thật (conf.lua: 960x540)
    
    self._layout = layout.new(screenW, screenH)
    self._layout.rows = 5   -- = #map[1], số phần tử mỗi cột
    self._layout.cols = 8   -- = #map
    local cols = self._layout.COLS        -- số cột (chiều X)
    local rows = self._layout.ROWS        -- số hàng (chiều Y)
    self._tileSize = math.min(screenW / cols, screenH / rows)        -- kích thước mỗi ô (pixel), bạn tự chọn
    self._brick = brick(self._layout)


    self._mapImage   = love.graphics.newImage("assets/sprites/MapLayer/khonggian.png")
    self._brickSheet = love.graphics.newImage("assets/sprites/MapLayer/brick.png")
end




function GSMap:createMap(levelModel)
    local map = levelModel:getMap()
    local cols, rows = #map, #map[1]
    local layout = self._layout

    local function checkPath(c, r)
        if not map[c] then return false end
        local v = map[c][r]
        return v == 5 or v == 1 or v == 2
    end

    self._canvas = love.graphics.newCanvas(layout.tileSize * cols, layout.tileSize * rows)
    love.graphics.setCanvas(self._canvas)
    love.graphics.clear()

    -- vẽ vào canvas: origin = 0
    local savedX, savedY = layout.originX, layout.originY
    layout.originX, layout.originY = 0, 0

    local sx = (layout.tileSize * cols) / self._mapImage:getWidth()
    local sy = (layout.tileSize * rows) / self._mapImage:getHeight()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self._mapImage, 0, 0, 0, sx, sy)

    for i = 1, cols do
        for j = 1, rows do
            if checkPath(i, j) then
                local left  = i > 1    and checkPath(i-1, j)
                local right = i < cols and checkPath(i+1, j)
                local down  = j > 1    and checkPath(i, j-1)
                local up    = j < rows and checkPath(i, j+1)
                self._brick:draw(i - 1, j - 1, left, right, up, down)
            end
        end
    end

    layout.originX, layout.originY = savedX, savedY   -- trả lại
    love.graphics.setCanvas()
end

function GSMap:draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(self._canvas, self._layout.originX,self._layout.originY)
end

return GSMap