    -- MapLayout.lua
    -- Port hệ tọa độ lưới map từ GSDefine.h (Cocos2d-x) sang LÖVE.
    -- Tính tileSize + originPos từ kích thước màn hình (KHÔNG fix cứng),
    -- và đổi qua lại giữa ô (row, col) <-> pixel.
    --
    -- Khác biệt trục toạ độ:
    --   Cocos: gốc góc DƯỚI-trái, y hướng LÊN.
    --   LÖVE : gốc góc TRÊN-trái, y hướng XUỐNG.  -> phải LẬT trục y.
    -- Quy ước macro gốc: Vec2(.x = COLUMN, .y = ROW). Giữ nguyên: col->x, row->y.

    local MapLayout = {}
    MapLayout.__index = MapLayout

    -- Hằng số lưới (gốc: #define ROWW 5, COLUMNN 8)
    MapLayout.ROWS = 5
    MapLayout.COLS = 8

    -- Tạo layout, tính toàn bộ từ kích thước màn hình hiện tại.
    function MapLayout.new(screenW, screenH)
        local self = setmetatable({}, MapLayout)

        -- Vùng cỏ theo tỉ lệ màn hình (gốc: GRASS_POSITION_*)
        local grassLeft   = screenW * 3/16
        local grassRight  = screenW * 15/16
        local grassTop    = screenH * 7/8
        local grassBottom = screenH * 1/8

        -- Kích thước ô vuông = min(rộng/cột, cao/hàng)  (gốc: SIZE_OF_SQUARE)
        self.tileSize = math.min(
            (grassRight - grassLeft) / MapLayout.COLS,
            (grassTop - grassBottom) / MapLayout.ROWS
        )

        -- Gốc lưới = căn giữa lưới trong vùng cỏ (gốc: GRASS_ORIGIN_POSITION_*)
        -- Tính theo hệ Cocos trước (gốc dưới-trái):
        local originX_cocos = (grassRight + grassLeft) / 2 - MapLayout.COLS * self.tileSize / 2
        local originY_cocos = (grassTop + grassBottom) / 2 - MapLayout.ROWS * self.tileSize / 2

        -- originX giữ nguyên (trục x không lật)
        self.originX = originX_cocos

        -- LẬT trục y sang hệ LÖVE (trên-trái):
        -- mép trên của lưới trong Cocos là originY_cocos + ROWS*tileSize (tính từ dưới lên),
        -- đổi sang khoảng cách từ ĐỈNH màn hình:
        self.originY = screenH - (originY_cocos + MapLayout.ROWS * self.tileSize)

        self.screenW = screenW
        self.screenH = screenH
        return self
    end

    -- Đổi ô -> pixel TÂM ô (gốc: ROW_COLUMN_TO_POSITION, có +SIZE/2).
    -- row, col dùng 0-based để khớp công thức C++. Nếu mảng Lua 1-based thì truyền (idx-1).
    function MapLayout:cellToPixel(col, row)
        local px = self.originX + self.tileSize * col + self.tileSize / 2
        -- lật Y: row lớn (phần tử cuối mảng) ở TRÊN, row nhỏ ở DƯỚI
        local py = self.originY + self.tileSize * (self.rows - 1 - row) + self.tileSize / 2
        return px, py
    end

    -- Đổi pixel -> ô (gốc: POSITION_TO_ROW_COLUMN). Trả về col, row (0-based, có thể lẻ).
    function MapLayout:pixelToCell(px, py)
        local col = (px - self.originX - self.tileSize / 2) / self.tileSize
        local row = (py - self.originY - self.tileSize / 2) / self.tileSize
        return col, row
    end

    -- Đổi pixel -> chỉ số ô nguyên (để biết click vào ô nào). 0-based.
    function MapLayout:pixelToCellIndex(px, py)
        local col = math.floor((px - self.originX) / self.tileSize)
        local row = math.floor((py - self.originY) / self.tileSize)
        return col, row
    end

    -- Kiểm tra pixel có nằm ngoài lưới không (gốc: GRASS_OUTSIDE)
    function MapLayout:isOutside(px, py)
        return px < self.originX
            or px > self.originX + self.COLS * self.tileSize
            or py < self.originY
            or py > self.originY + self.ROWS * self.tileSize
    end

    return MapLayout