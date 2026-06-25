-- objects/Model/DiseaseModelDefinition.lua
local DiseaseModelDefinition = {}

-- Hành động của disease (DiseaseAction)
DiseaseModelDefinition.DiseaseAction = {
    WALKING   = "walking",
    ATTACKING = "attacking",
    WAITING   = "waiting",
}

-- Loại disease (DiseaseId) — 7 enemy
DiseaseModelDefinition.DiseaseId = {
    DISEASE_00_RABIES    = "Disease00",
    DISEASE_01_SMALLPOX  = "Disease01",
    DISEASE_02_INFLUENZA = "Disease02",
    DISEASE_03_MEASLES   = "Disease03",
    DISEASE_04_POLIO     = "Disease04",
    DISEASE_05_MALARIA   = "Disease05",
    DISEASE_06_EBOLA     = "Disease06",
}

-- Hướng di chuyển (Direction)
DiseaseModelDefinition.Direction = {
    UP    = "up",
    DOWN  = "down",
    LEFT  = "left",
    RIGHT = "right",
}

return DiseaseModelDefinition