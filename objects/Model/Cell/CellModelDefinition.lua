-- objects/Model/CellModelDefinition.lua
local CellModelDefinition = {}

-- Đường dẫn ảnh
CellModelDefinition.CELL_00_FILENAME = "assets/sprites/objects/cell/cell00.png"
-- ...

-- Enum CellId (Lua dùng string hoặc số)
CellModelDefinition.CellId = {
    CELL_00 = "CELL_00_EOSINOPHILS",
    CELL_01 = "CELL_01_ERYTHROCYTES",
    CELL_02 = "CELL_02_PLATELETS",
    CELL_03 = "CELL_03_BASOPHILS",
    CELL_04 = "CELL_04_MONOCYTES",
    CELL_05 = "CELL_05_LYMPHOCYTESB",
    CELL_06 =  "CELL_06_NEUTROPHILS",
    REMOVE =  "REMOVE_CELL"
    -- ...
}

-- Hằng số
CellModelDefinition.OBJECT_SCALE = 1.0
CellModelDefinition.CELL_WIDTH = 64

return CellModelDefinition