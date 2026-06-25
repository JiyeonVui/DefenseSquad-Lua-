-- GSControlLayer.lua
-- Tầng đặt cell: hiện preview theo lưới, kiểm tra hợp lệ, và đặt cell khi thả chuột.
--
-- ĐIỂM MẤU CHỐT: KHÔNG tự chế hằng số toạ độ. Dùng CHUNG đúng instance MapLayout
-- mà GSMap đang dùng để vẽ canvas map -> preview/cell luôn khớp khít với map.
--   pixel chuột  -> ô : layout:pixelToCellIndex(px, py)   (đã lật Y)
--   ô           -> pixel TÂM ô : layout:cellToPixel(col, row)
--   ngoài lưới  : layout:isOutside(px, py)
--
-- Quy ước chỉ số (THỐNG NHẤT col-major, khớp JSON + GSMap):
--   - Lưới của layout là 0-based (col 0..COLS-1, row 0..ROWS-1), khớp cellToPixel.
--   - Model (CellModel/LevelModel) đánh map[x][y] 1-based -> quy đổi modelX/Y = col+1/row+1.

require('objects.Model.CharacterModel')               -- nạp global CharacterModel trước
local CellModel = require('objects.Model.CellModel.CellModel')

GSControlLayer = Object:extend()

--------------------------------------------------------------------------------
-- Hằng số & tài nguyên
--------------------------------------------------------------------------------

local PLACABLE_IMG = "assets/sprites/objects/cell/placable.png"      -- ô đặt được
local RADIUS_IMG   = "assets/sprites/objects/cell/radius_preview.png" -- vòng tầm bắn

-- Nhịp nhấp nháy của ô gợi ý "đặt được".
local HIGHLIGHT_ALPHA_MIN = 0.30
local HIGHLIGHT_ALPHA_MAX = 0.70
local HIGHLIGHT_PULSE_HZ  = 2.0

-- Màu preview theo trạng thái (giữ nguyên bản gốc): trắng / đỏ / xám.
local COLOR_VALID   = { 1, 1, 1 }
local COLOR_INVALID = { 1, 0, 0 }
local COLOR_REMOVE  = { 0.78, 0.78, 0.78 }   -- 200/255

-- Ảnh sprite từng cellId (chỉ cell_00/01 + remove có sẵn; còn lại fallback cell_00).
local CELL_IMAGE = {
    [CellModel.CellId.CELL_00]    = "assets/sprites/objects/cell/cell_00.png",
    [CellModel.CellId.CELL_01]    = "assets/sprites/objects/cell/cell_01.png",
    [CellModel.CellId.REMOVE_CELL]= "assets/sprites/objects/cell/remove.png",
}
local CELL_IMAGE_FALLBACK = "assets/sprites/objects/cell/cell_00.png"

--------------------------------------------------------------------------------
-- Khởi tạo
--------------------------------------------------------------------------------

-- layout : MapLayout dùng chung với GSMap (BẮT BUỘC).
-- level  : LevelModel hiện hành (để kiểm tra ô + đặt cell).
-- onPlace: callback tuỳ chọn (cellId, modelX, modelY) khi đặt thành công.
function GSControlLayer:new(layout, level, onPlace)
    assert(layout, "GSControlLayer cần MapLayout dùng chung từ GSMap")
    self._layout  = layout
    self._level   = level
    self._onPlace = onPlace

    self._active      = true
    self._buttonCheck = false   -- đã chọn loại cell để đặt chưa
    self._dragging    = false
    self._pulseTime   = 0

    self._cellId        = nil
    self._distance      = 0
    self._previewImg    = nil
    self._anchorX       = 0.5
    self._anchorY       = 0.5
    self._scale         = 1
    self._preview       = nil    -- { x, y, color, alpha, valid, col, row }
    self._placableCells = {}     -- danh sách { col, row } gợi ý đặt được

    self._placableImg = love.graphics.newImage(PLACABLE_IMG)
    self._radiusImg   = love.graphics.newImage(RADIUS_IMG)
end

-- Tra cứu ảnh/anchor cho một cellId.
function GSControlLayer:getCellInfo(cellId)
    return {
        image   = CELL_IMAGE[cellId] or CELL_IMAGE_FALLBACK,
        anchorX = 0.5, anchorY = 0.5,   -- neo tâm để khớp tâm ô
    }
end

--------------------------------------------------------------------------------
-- Chọn loại cell để đặt
--------------------------------------------------------------------------------

-- Bắt đầu một phiên đặt cell: nạp ảnh preview và quét trước các ô đặt được.
function GSControlLayer:setPreviewImage(cellId, distance)
    self._cellId      = cellId
    self._distance    = distance or 0
    self._buttonCheck = true
    self._preview     = nil

    local info = self:getCellInfo(cellId)
    self._previewImg = love.graphics.newImage(info.image)
    self._anchorX, self._anchorY = info.anchorX, info.anchorY

    -- Khớp sprite vào kích thước ô (theo chiều rộng ảnh).
    self._scale = self._layout.tileSize / self._previewImg:getWidth()

    self._placableCells = self:_collectPlacableCells(cellId)
end

-- Quét cả lưới (0-based) tìm ô đặt được cho cellId.
function GSControlLayer:_collectPlacableCells(cellId)
    local layout = self._layout
    local cells  = {}
    for col = 0, layout.COLS - 1 do
        for row = 0, layout.ROWS - 1 do
            if CellModel.canPutOnById(cellId, self._level, col + 1, row + 1) then
                table.insert(cells, { col = col, row = row })
            end
        end
    end
    return cells
end

function GSControlLayer:setActive(active) self._active = active end

-- Kết thúc phiên đặt (huỷ chọn).
function GSControlLayer:clearSelection()
    self._buttonCheck   = false
    self._dragging      = false
    self._preview       = nil
    self._placableCells = {}
end

--------------------------------------------------------------------------------
-- Tương tác chuột
--------------------------------------------------------------------------------

function GSControlLayer:mousepressed(px, py, button)   -- onTouchBegan
    if button ~= 1 or not self._active or not self._buttonCheck then return end
    self._dragging = true
    self:updatePreview(px, py)
end

function GSControlLayer:mousemoved(px, py)             -- onTouchMoved
    if self._dragging then
        self:updatePreview(px, py)
    end
end

function GSControlLayer:mousereleased(px, py, button)  -- onTouchEnded
    if button ~= 1 or not self._dragging then return end
    self._dragging = false

    local preview = self._preview
    if preview and preview.valid then
        self:_placeCell(preview.col, preview.row)
    end
    self:clearSelection()
end

-- Tính preview cho vị trí chuột (px, py): snap về tâm ô + xác định hợp lệ.
function GSControlLayer:updatePreview(px, py)
    local layout = self._layout

    if layout:isOutside(px, py) then
        self._preview = { x = px, y = py, color = COLOR_INVALID, alpha = 150 / 255, valid = false }
        return
    end

    -- pixel -> ô (đã lật Y), kẹp trong lưới cho an toàn.
    local col, row = layout:pixelToCellIndex(px, py)
    col = math.max(0, math.min(layout.COLS - 1, col))
    row = math.max(0, math.min(layout.ROWS - 1, row))

    local gx, gy   = layout:cellToPixel(col, row)            -- tâm ô trên màn hình
    local canPlace = CellModel.canPutOnById(self._cellId, self._level, col + 1, row + 1)

    local color
    if canPlace then
        color = COLOR_VALID
    elseif self._cellId == CellModel.CellId.REMOVE_CELL then
        color = COLOR_REMOVE
    else
        color = COLOR_INVALID
    end

    self._preview = { x = gx, y = gy, color = color, alpha = 1, valid = canPlace, col = col, row = row }
end

--------------------------------------------------------------------------------
-- Đặt cell
--------------------------------------------------------------------------------

-- Đặt cell tại ô lưới (col, row) 0-based. Trả về true nếu thành công.
function GSControlLayer:_placeCell(col, row)
    local modelX, modelY = col + 1, row + 1

    -- Công cụ xoá: gỡ cell đang chiếm ô, không tạo cell mới.
    if self._cellId == CellModel.CellId.REMOVE_CELL then
        self._level:findAndRemoveCell(modelX, modelY)
        self:_notifyPlaced(modelX, modelY)
        return true
    end

    local cell = CellModel.create(self._cellId)

    -- Kiểm tra năng lượng trước khi đặt.
    local cost = cell:getCost()
    if self._level:getEnergyValue() < cost then
        self._level:emphasizeEnergy()
        return false
    end

    self._level:addEnergyValue(-cost)
    cell._level = self._level            -- để cell tự dump khi hp <= 0
    self._level:addCell(cell, modelX, modelY)
    self:_notifyPlaced(modelX, modelY)
    return true
end

function GSControlLayer:_notifyPlaced(modelX, modelY)
    if self._onPlace then
        self._onPlace(self._cellId, modelX, modelY)
    end
end

--------------------------------------------------------------------------------
-- Vòng đời
--------------------------------------------------------------------------------

function GSControlLayer:update(dt)
    self._pulseTime = self._pulseTime + dt
end

function GSControlLayer:draw()
    if not self._active or not self._buttonCheck then return end

    self:_drawPlacableHints()
    self:_drawPreview()

    love.graphics.setColor(1, 1, 1, 1)   -- trả màu mặc định
end

-- Tô sáng các ô đặt được (nhấp nháy nhẹ).
function GSControlLayer:_drawPlacableHints()
    local layout = self._layout
    local img    = self._placableImg
    local scale  = layout.tileSize / img:getWidth()

    local pulse = HIGHLIGHT_ALPHA_MIN
        + (HIGHLIGHT_ALPHA_MAX - HIGHLIGHT_ALPHA_MIN)
        * 0.5 * (1 + math.sin(self._pulseTime * HIGHLIGHT_PULSE_HZ * 2 * math.pi))

    love.graphics.setColor(1, 1, 1, pulse)
    local ox, oy = img:getWidth() / 2, img:getHeight() / 2
    for _, c in ipairs(self._placableCells) do
        local x, y = layout:cellToPixel(c.col, c.row)
        love.graphics.draw(img, x, y, 0, scale, scale, ox, oy)
    end
end

-- Vẽ vòng tầm bắn + sprite preview tại ô đang trỏ.
function GSControlLayer:_drawPreview()
    local preview = self._preview
    if not preview then return end

    -- Vòng tầm bắn (chỉ khi đứng trong lưới và có tầm bắn).
    if self._distance > 0 and preview.col then
        local rImg = self._radiusImg
        local rScale = (self._distance * 2) / rImg:getWidth()
        local tint = preview.valid and { 0, 1, 0 } or { 1, 0, 0 }
        love.graphics.setColor(tint[1], tint[2], tint[3], 0.25)
        love.graphics.draw(rImg, preview.x, preview.y, 0, rScale, rScale,
            rImg:getWidth() / 2, rImg:getHeight() / 2)
    end

    -- Sprite preview.
    if self._previewImg then
        local img = self._previewImg
        local c = preview.color
        love.graphics.setColor(c[1], c[2], c[3], preview.alpha)
        love.graphics.draw(img, preview.x, preview.y, 0, self._scale, self._scale,
            img:getWidth() * self._anchorX, img:getHeight() * self._anchorY)
    end
end

return GSControlLayer
