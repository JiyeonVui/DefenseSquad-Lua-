-- GSBrick.lua
-- Port từ GSBrick.cpp (Cocos2d-x). Vẽ MỘT ô đường đi bằng 9 mảnh 3x3 (autotiling).
--
-- Khác bản gốc: Cocos tạo 1 object GSBrick cho mỗi ô. Ở đây map tĩnh được vẽ
-- một lần vào canvas, nên không cần giữ object brick cho từng ô. GSBrick thành
-- một "drawer" dùng chung: tạo 1 lần, gọi :draw() cho từng ô đường.
--
-- TRỤC Y: Cocos gốc dưới-trái (y lên). LÖVE y xuống -> offset y của 9 mảnh bị đảo.
-- Đã tính sẵn: mảnh "up" của Cocos nằm ở oy=TOP (trên màn hình).

local BRICK_SHEET = "assets/sprites/MapLayer/brick.png"   -- bảng mảnh 96x160, ô 32x32

local GSBrick = Object:extend()

-- Tạo 1 lần. layout = MapLayout (để biết tileSize + cellToPixel).
function GSBrick:new(layout)
    self._layout = layout
    self._sheet  = love.graphics.newImage(BRICK_SHEET)

    -- Tạo quad cho 14 piece. Giữ NGUYÊN công thức gốc createPiece:
    --   row = 4 - (piece-1)//3 ; col = (piece-1)%3 ; ô 32x32
    local sw, sh = self._sheet:getDimensions()
    self._quads = {}
    for piece = 1, 14 do
        local row = 4 - math.floor((piece - 1) / 3)
        local col = (piece - 1) % 3
        self._quads[piece] = love.graphics.newQuad(32 * col, 32 * row, 32, 32, sw, sh)
    end
end

-- Vẽ một ô đường tại (col, row) 0-based, dựa trên 4 láng giềng.
-- Gọi trong setCanvas (vẽ vào canvas tĩnh), không gọi mỗi frame.
function GSBrick:draw(col, row, left, right, up, down)
    local size  = self._layout.tileSize
    local third = size / 3
    local scale = third / 32

    -- góc trên-trái ô trên màn hình (cellToPixel trả TÂM -> trừ nửa ô)
    local cx, cy = self._layout:cellToPixel(col, row)
    local bx, by = cx - size / 2, cy - size / 2

    local sheet, quads = self._sheet, self._quads
    local function piece(p, ox, oy)
        love.graphics.draw(sheet, quads[p], bx + ox, by + oy, 0, scale, scale)
    end

    -- offset (đã lật trục y: TOP = trên màn hình)
    local LEFTx, MIDx, RIGHTx = 0, third, third * 2
    local TOP, MID, BOT       = 0, third, third * 2

    -- center
    piece(5, MIDx, MID)

    -- 4 mép: nối -> piece 5; không nối -> mép tương ứng
    piece(left  and 5 or 4, LEFTx,  MID)
    piece(right and 5 or 6, RIGHTx, MID)
    piece(up    and 5 or 8, MIDx,   TOP)
    piece(down  and 5 or 2, MIDx,   BOT)

    -- 4 góc: phụ thuộc 2 hướng kề (cây if giữ nguyên bản gốc)
    local ul
    if up and left then ul = 13
    elseif (not up) and left then ul = 8
    elseif up and (not left) then ul = 4
    else ul = 7 end
    piece(ul, LEFTx, TOP)

    local ur
    if up and right then ur = 14
    elseif (not up) and right then ur = 8
    elseif up and (not right) then ur = 6
    else ur = 9 end
    piece(ur, RIGHTx, TOP)

    local ll
    if down and left then ll = 10
    elseif (not down) and left then ll = 2
    elseif down and (not left) then ll = 4
    else ll = 1 end
    piece(ll, LEFTx, BOT)

    local lr
    if down and right then lr = 11
    elseif (not down) and right then lr = 2
    elseif down and (not right) then lr = 6
    else lr = 3 end
    piece(lr, RIGHTx, BOT)
end

return GSBrick
