-- CellModel
-- Lua/LÖVE port of the Cocos2d-x CellModel (a defensive tower placed on the map).
--
-- C++ had:  class CellModel : public CharacterModel  + a UICell* view it drove
-- directly. Here Model and View are collapsed into one BYTEPATH-style object:
-- animation is a `self.state` field that draw() reads, instead of a UICell pointer.
--
-- NOTE: enums below (MapPosition / CharacterStatus / CellId) are reconstructed from
-- the names used in the original. Replace with the real LevelModelDefinitions.lua.

--------------------------------------------------------------------------------
-- Constants (stand in for LevelModelDefinitions.h enums)
--------------------------------------------------------------------------------

-- Map tile classification (MapPosition.type in C++).
local MapPosition = {
    EMPTY_CANNOT_PUT = 0,  -- decoration / blocked
    EMPTY_CAN_PUT    = 1,  -- buildable ground for normal cells
    ENEMY_PATH       = 2,  -- the lane diseases walk; on-path cells go here
    BEGIN_PATH       = 3,
    END_PATH         = 4,
}

-- Character status (CharacterStatus in C++).
local CharacterStatus = {
    NORMAL  = "normal",
    SLOWED  = "slowed",
    STUNNED = "stunned",
}

-- Cell identifiers (CellId in C++): the seven buildable cells + the remove tool.
local CellId = {
    CELL_00 = "Cell00",
    CELL_01 = "Cell01",
    CELL_02 = "Cell02",
    CELL_03 = "Cell03",
    CELL_04 = "Cell04",
    CELL_05 = "Cell05",
    CELL_06 = "Cell06",
    REMOVE_CELL = "RemoveCell",
}

-- How long the 'attack' pose stays on screen before snapping back to 'idle'.
-- (In Cocos the attack+idle animations were fired back-to-back asynchronously;
--  with a state field we need a real timer so the attack pose is visible.)
local ATTACK_ANIM_DURATION = 0.20

--------------------------------------------------------------------------------
-- Per-cell design stats. Real numbers should come from the cell subclasses or a
-- data file; these are placeholders so the factory produces working cells.
--   placement: 'empty' = normal buildable, 'path' = goes on the lane,
--              'remove' = the remove tool (targets occupied tiles).
--------------------------------------------------------------------------------

local CELL_STATS = {
    [CellId.CELL_00] = { hp = 100, cost = 50,  rechargeTime = 1.0, distance = 120, placement = 'empty', beEaten = true },
    [CellId.CELL_01] = { hp = 120, cost = 75,  rechargeTime = 1.2, distance = 140, placement = 'empty', beEaten = true },
    [CellId.CELL_02] = { hp = 150, cost = 100, rechargeTime = 0.8, distance = 100, placement = 'empty', beEaten = true },
    [CellId.CELL_03] = { hp = 200, cost = 125, rechargeTime = 1.5, distance = 160, placement = 'empty', beEaten = true },
    [CellId.CELL_04] = { hp = 180, cost = 150, rechargeTime = 1.0, distance = 130, placement = 'empty', beEaten = true },
    [CellId.CELL_05] = { hp = 250, cost = 175, rechargeTime = 2.0, distance = 180, placement = 'empty', beEaten = true },
    -- Example "wall / on-path" cell: blocks the lane, can be eaten by diseases.
    [CellId.CELL_06] = { hp = 300, cost = 200, rechargeTime = 0.0, distance = 0,   placement = 'path',  beEaten = true },
    -- The remove tool: not a real cell, only validates against occupied tiles.
    [CellId.REMOVE_CELL] = { hp = 0, cost = 0, rechargeTime = 0.0, distance = 0,   placement = 'remove', beEaten = false },
}

-- Maps a CellId to its dedicated subclass module (loaded lazily by the factory).
local CELL_MODULES = {
    [CellId.CELL_00] = "objects/Model/CellModel/Cell00",
    [CellId.CELL_01] = "objects/Model/CellModel/Cell01",
    [CellId.CELL_02] = "objects/Model/CellModel/Cell02",
    [CellId.CELL_03] = "objects/Model/CellModel/Cell03",
    [CellId.CELL_04] = "objects/Model/CellModel/Cell04",
    [CellId.CELL_05] = "objects/Model/CellModel/Cell05",
    [CellId.CELL_06] = "objects/Model/CellModel/Cell06",
}



CellModel = CharacterModel:extend()

-- Re-export the constants on the module so callers can reference them.
CellModel.CellId          = CellId
CellModel.MapPosition     = MapPosition
CellModel.CharacterStatus = CharacterStatus

--------------------------------------------------------------------------------
-- Placement validation helpers (shared by the instance and static canPutOn).
--------------------------------------------------------------------------------

-- True if (x, y) addresses a real tile in the grid.
local function inBounds(map, x, y)
    return map[y] ~= nil and map[y][x] ~= nil
end

-- A tile may be a plain enum value or a table { type = ..., occupant = ... }.
local function tileType(tile)
    if type(tile) == "table" then return tile.type end
    return tile
end

-- True if a cell already sits on this tile.
local function tileOccupied(tile)
    return type(tile) == "table" and tile.occupant ~= nil
end

-- Core rule check shared by instance and static canPutOn. Reproduces the C++
-- per-CellId switch via the cell's `placement` category.
local function checkPlacement(placement, level, cellX, cellY)
    local map = level:getMap()
    if not inBounds(map, cellX, cellY) then return false end

    local tile = map[cellY][cellX]

    if placement == "remove" then
        -- REMOVE_CELL: only valid where a cell already exists.
        return tileOccupied(tile)
    elseif placement == "path" then
        -- On-path cells: must sit on the enemy lane and on a free tile.
        return tileType(tile) == MapPosition.ENEMY_PATH and not tileOccupied(tile)
    else
        -- Normal cells: must sit on buildable, unoccupied ground.
        return tileType(tile) == MapPosition.EMPTY_CAN_PUT and not tileOccupied(tile)
    end
end

--------------------------------------------------------------------------------
-- Construction & factory
--------------------------------------------------------------------------------

-- Build a cell of the given id, configured from CELL_STATS.
-- (Mirrors the C++ constructor: ui = nil, beEaten = true, alive = true,
--  status = NORMAL, hp set per cell type.)
function CellModel:new(id)
    CellModel.super.new(self) -- CharacterModel:new()

    self._cellId = id or CellId.CELL_00
    local stats = CELL_STATS[self.cellId] or {}

    self._hp           = stats.hp or 100
    self._maxHp        = self.hp
    self._cost         = stats.cost or 0
    self._rechargeTime = stats.rechargeTime or 1.0
    self._distance     = stats.distance or 0          -- attack range in pixels
    self._placement    = stats.placement or "empty"
    self._beEaten      = (stats.beEaten ~= false)     -- default true

    self._alive  = true
    self._status = CharacterStatus.NORMAL

    -- Collapsed Model+View: no UICell pointer. `ui` kept only for API parity.
    self._ui    = nil
    self._state = "idle" -- 'idle' | 'attack' | 'die'  (replaces UICell animations)

    -- Timers (converted from the fixed 0.01s tick to dt-based countdowns).
    self._shootTimeCounter = 0          -- recharge: ready to fire when <= 0
    self._attackStateTimer = 0          -- keeps the 'attack' pose visible
end

-- FACTORY: given a CellId, return the matching subclass instance (Cell00..Cell06).
-- Falls back to a stats-configured base CellModel while the subclass modules
-- don't exist yet. (Module-level function, not a method.)
function CellModel.create(id)
    local modulePath = CELL_MODULES[id]
    if modulePath then
        local ok, Subclass = pcall(require, modulePath)
        if ok and Subclass then
            return Subclass(id)
        end
    end
    return CellModel(id)
end

--------------------------------------------------------------------------------
-- Simple accessors
--------------------------------------------------------------------------------

-- Attack range in pixels.
function CellModel:getDistance() return self._distance end

-- This cell's CellId.
function CellModel:getCellId() return self.cellId end

-- Energy/gold cost to place this cell.
function CellModel:getCost() return self.cost end

-- Seconds between attacks.
function CellModel:getRechargeTime() return self.rechargeTime end

-- Whether diseases can eat (target) this cell.
function CellModel:canBeEaten() return self.beEaten end

function CellModel:canPutOn(level, cellX, cellY)
    return checkPlacement(self._placement, level, cellX, cellY)
end

-- Static check by id, without building a cell. Renamed from the C++ static
-- CellModel::canPutOn because Lua cannot host both an instance method and a
-- static function under the same `canPutOn` key on the module table.
function CellModel.canPutOnById(id, level, cellX, cellY)
    local stats = CELL_STATS[id]
    local placement = (stats and stats._placement) or "empty"
    return checkPlacement(placement, level, cellX, cellY)
end

--------------------------------------------------------------------------------
-- Visual hookup (collapsed Model+View)
--------------------------------------------------------------------------------

-- Original: store the UICell view, then start its idle animation.
-- Collapsed design: there is no separate view. We keep the method for API
-- parity (callers may pass a sprite/atlas handle), remember it, and enter idle.
function CellModel:setUIObject(ui)
    self._ui = ui
    self._ui.idleAnimate();
end


-- Collapsed design: the model IS the view. Kept as the __getUIObject equivalent.
function CellModel:__getUIObject()
    return self
end


-- Per-frame logic. `dt` is LÖVE delta time in seconds.
function CellModel:update(dt)
    if self._hp <= 0 and self._level ~= nil then
        self._alive = false
        self._level.dumpCell(self)
        self._level = nil
        self._ui.dieAnimate();
        return
    end
end



return CellModel
