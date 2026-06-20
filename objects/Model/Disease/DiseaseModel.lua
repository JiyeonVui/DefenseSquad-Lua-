
local Direction = {
    UP    = "up",
    DOWN  = "down",
    LEFT  = "left",
    RIGHT = "right",
}

-- Unit step vector per direction, in GRID units.
-- Orientation matches the original target logic: dy > 0 means UP, dx > 0 means RIGHT.
local DIR_VECTOR = {
    [Direction.UP]    = {  0,  1 },
    [Direction.DOWN]  = {  0, -1 },
    [Direction.RIGHT] = {  1,  0 },
    [Direction.LEFT]  = { -1,  0 },
}

-- Disease behavior state (DiseaseAction in C++).
local DiseaseAction = {
    WAITING   = "waiting",
    WALKING   = "walking",
    ATTACKING = "attacking",
    DEAD      = "dead",
}

-- Character status (CharacterStatus in C++).
local CharacterStatus = {
    NORMAL = "normal",
    FROZEN = "frozen",
}

-- Disease identifiers (DiseaseId in C++).
local DiseaseId = {
    DISEASE_00 = "Disease00",
    DISEASE_01 = "Disease01",
    DISEASE_02 = "Disease02",
    DISEASE_03 = "Disease03",
    DISEASE_04 = "Disease04",
    DISEASE_05 = "Disease05",
    DISEASE_06 = "Disease06",
}

local TILE_SIZE = 32

-- How long a disease stays frozen, in seconds.
local FROZEN_DURATION = 3.0

-- Small tolerance for "within one cell" target checks (grid units).
local DISTANCE_EPSILON = 0.05

--------------------------------------------------------------------------------
-- Per-disease design stats. Real numbers should come from the subclasses or a
-- data file; these are placeholders so the factory produces working enemies.
--   speed is in grid cells per second.
--------------------------------------------------------------------------------

local DISEASE_STATS = {
    [DiseaseId.DISEASE_00] = { hp = 60,  speed = 1.5, damage = 10, hitRechargeTime = 1.0, reward = 10 },
    [DiseaseId.DISEASE_01] = { hp = 80,  speed = 1.3, damage = 15, hitRechargeTime = 1.0, reward = 12 },
    [DiseaseId.DISEASE_02] = { hp = 120, speed = 1.0, damage = 20, hitRechargeTime = 1.2, reward = 15 },
    [DiseaseId.DISEASE_03] = { hp = 200, speed = 0.8, damage = 25, hitRechargeTime = 1.5, reward = 20 },
    [DiseaseId.DISEASE_04] = { hp = 100, speed = 2.0, damage = 12, hitRechargeTime = 0.8, reward = 18 },
    [DiseaseId.DISEASE_05] = { hp = 300, speed = 0.7, damage = 30, hitRechargeTime = 2.0, reward = 30 },
    [DiseaseId.DISEASE_06] = { hp = 500, speed = 0.6, damage = 40, hitRechargeTime = 2.0, reward = 50 },
}

-- Maps a DiseaseId to its dedicated subclass module (loaded lazily by the factory).
local DISEASE_MODULES = {
    [DiseaseId.DISEASE_00] = "objects/Model/D/Disease00",
    [DiseaseId.DISEASE_01] = "objects/Model/D/Disease01",
    [DiseaseId.DISEASE_02] = "objects/Model/D/Disease02",
    [DiseaseId.DISEASE_03] = "objects/Model/D/Disease03",
    [DiseaseId.DISEASE_04] = "objects/Model/D/Disease04",
    [DiseaseId.DISEASE_05] = "objects/Model/D/Disease05",
    [DiseaseId.DISEASE_06] = "objects/Model/D/Disease06",
}

--------------------------------------------------------------------------------
-- CharacterModel (minimal). Replace with the real CharacterModel.lua when it
-- exists; this self-contained version lets DiseaseModel.lua run on its own.
--------------------------------------------------------------------------------


DiseaseModel = CharacterModel:extend()

-- Re-export constants on the module so callers can reference them.
DiseaseModel.DiseaseId       = DiseaseId
DiseaseModel.Direction       = Direction
DiseaseModel.DiseaseAction   = DiseaseAction
DiseaseModel.CharacterStatus = CharacterStatus


function DiseaseModel:new(id)
    DiseaseModel.super.new(self) -- CharacterModel:new()

    self.diseaseId = id or DiseaseId.DISEASE_00
    local stats = DISEASE_STATS[self.diseaseId] or {}

    self._hp              = stats.hp or 100
    self._maxHp           = self.hp
    self._speed           = stats.speed or 1.0           -- grid cells / second
    self._damage          = stats.damage or 10
    self._hitRechargeTime = stats.hitRechargeTime or 1.0
    self._reward          = stats.reward or 0

    self._alive      = true
    self._ignoreCell = false
    self._status     = CharacterStatus.NORMAL

    -- Collapsed Model+View: no UIDisease pointer. `ui` kept only for API parity.
    self._ui     = nil
    self._action = DiseaseAction.WAITING
    self._dir    = Direction.LEFT

    -- Path following. C++ used list iterators; we use 1-based integer indices.
    self._path            = nil
    self._currentPathIndex = 1
    self._nextPathIndex    = 2

    -- Timers (fixed 0.01s tick -> dt-based countdowns).
    self._frozenStatusCounter = 0
    self._hitTimer            = 0   -- ready to hit when <= 0
end

-- FACTORY: given a DiseaseId, return the matching subclass instance
-- (Disease00..Disease06). Falls back to a stats-configured base DiseaseModel
-- while the subclass modules don't exist yet. (Module-level function.)
function DiseaseModel.create(id)
    local modulePath = DISEASE_MODULES[id]
    if modulePath then
        local ok, Subclass = pcall(require, modulePath)
        if ok and Subclass then
            return Subclass(id)
        end
    end
    return DiseaseModel(id)
end

--------------------------------------------------------------------------------
-- Simple accessors
--------------------------------------------------------------------------------

-- This disease's DiseaseId.
function DiseaseModel:getDiseaseId() return self.diseaseId end

-- Gold/energy reward granted when this disease dies.
function DiseaseModel:getReward() return self.reward end

-- Attack damage per hit.
function DiseaseModel:getDamage() return self.damage end

--------------------------------------------------------------------------------
-- Level attachment & path setup
--------------------------------------------------------------------------------

-- Attach the owning level. On attach, pick a random enemy path, seed the
-- current/next path indices, snap onto the first node, and face along the path.
-- Overrides CharacterModel:__setLevel.
function DiseaseModel:__setLevel(level)
    self.level = level

    -- was: level:__getEnemyPath() -- returns a random path
    self.path = level:getEnemyPath()
    if not self.path or #self.path == 0 then return end

    self.currentPathIndex = 1
    self.nextPathIndex    = 2

    local startNode = self.path[1]
    self.cellX, self.cellY = startNode[1], startNode[2]
    self:_updateViewPosition()

    self:changeDirectionOnPath()
end

--------------------------------------------------------------------------------
-- Direction selection
--------------------------------------------------------------------------------

-- Face along the path: compare the next node against the current node.
-- If there is no next node (past the end), keep the current direction.
function DiseaseModel:changeDirectionOnPath()
    if not self.path then return end
    if self.nextPathIndex > #self.path then return end

    local cur = self.path[self.currentPathIndex]
    local nxt = self.path[self.nextPathIndex]
    if not cur or not nxt then return end

    local dx = nxt[1] - cur[1]
    local dy = nxt[2] - cur[2]
    self.dir = self:_pickDirection(dx, dy)
end

-- Face toward a target cell. Vertical bias when |dx| < |dy| (matches the .cpp).
function DiseaseModel:changeDirectionToTarget(cell)
    local dx = cell:getPositionCellX() - self.cellX
    local dy = cell:getPositionCellY() - self.cellY

    if math.abs(dx) < math.abs(dy) then
        self.dir = (dy > 0) and Direction.UP or Direction.DOWN
    else
        self.dir = (dx > 0) and Direction.RIGHT or Direction.LEFT
    end
end

-- Choose a direction from a delta, preferring the dominant axis.
function DiseaseModel:_pickDirection(dx, dy)
    if dx == 0 and dy == 0 then return self.dir end
    if math.abs(dx) >= math.abs(dy) then
        return (dx > 0) and Direction.RIGHT or Direction.LEFT
    else
        return (dy > 0) and Direction.UP or Direction.DOWN
    end
end

--------------------------------------------------------------------------------
-- Target acquisition
--------------------------------------------------------------------------------

-- Grid-space distance from this disease to a cell.
function DiseaseModel:_distanceToCell(cell)
    return distance(self.cellX, self.cellY,
        cell:getPositionCellX(), cell:getPositionCellY())
end

-- True if the cell sits on the current or previous path node (already passed).
function DiseaseModel:_isPassed(cell)
    if not self.path then return false end
    local cx, cy = cell:getPositionCellX(), cell:getPositionCellY()

    local current  = self.path[self.currentPathIndex]
    local previous = self.path[self.currentPathIndex - 1]

    if current and current[1] == cx and current[2] == cy then return true end
    if previous and previous[1] == cx and previous[2] == cy then return true end
    return false
end

-- Scan the level cell list for the first attackable target within ~1 cell that
-- can be eaten and has not already been passed on the path. Returns nil if none.
function DiseaseModel:_findTarget()
    local cells = self.level:getCellList()
    for i = 1, #cells do
        local cell = cells[i]
        local eatable = cell.canBeEaten and cell:canBeEaten()
        local living  = (not cell.isAlive) or cell:isAlive()
        if eatable and living then
            local d = self:_distanceToCell(cell)
            if d <= 1.0 + DISTANCE_EPSILON and not self:_isPassed(cell) then
                return cell
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Combat
--------------------------------------------------------------------------------

-- Strike a target: play the attack pose, deal damage, flash the target.
function DiseaseModel:hitTarget(target)
    self.action = DiseaseAction.ATTACKING -- was: ui:attackAnimate(self.dir)
    target:takeDamage(self.damage)
    -- was: target:__getUIObject():hitAnimate()
    -- TODO: flag a brief hit-flash on the target in the collapsed design.
end

--------------------------------------------------------------------------------
-- Frozen status
--------------------------------------------------------------------------------

-- Freeze the disease (it cannot move until it thaws).
function DiseaseModel:setFrozen()
    self.status = CharacterStatus.FROZEN
    self.frozenStatusCounter = FROZEN_DURATION
    -- was: ui:setFrozenAnimate()
end

-- Thaw the disease and clear the frozen timer.
function DiseaseModel:deFrozen()
    self.status = CharacterStatus.NORMAL
    self.frozenStatusCounter = 0
    -- was: ui:deFrozenAnimate()
end

--------------------------------------------------------------------------------
-- Visual hookup (collapsed Model+View)
--------------------------------------------------------------------------------

-- Original: store the UIDisease view, then play its idle animation.
-- Collapsed design: there is no separate view. We keep the method for API
-- parity (callers may pass a sprite/atlas handle) and remember it.
function DiseaseModel:setUIObject(ui)
    self.ui = ui
    -- was: ui:idleAnimate(self.dir) -- rendering is driven by self.action/self.dir
end

-- Collapsed design: the model IS the view.
function DiseaseModel:__getUIObject() return self end

-- Sync the pixel position from the grid position (the "view position" update).
function DiseaseModel:_updateViewPosition()
    self:setPosition(self.cellX * TILE_SIZE, self.cellY * TILE_SIZE)
end

--------------------------------------------------------------------------------
-- Path movement
--------------------------------------------------------------------------------

-- Advance to the next path segment. If the next index runs past the end, the
-- disease has reached the base -> tell the level it's a loss.
function DiseaseModel:_advancePath()
    self.currentPathIndex = self.nextPathIndex
    self.nextPathIndex    = self.nextPathIndex + 1

    if self.nextPathIndex > #self.path then
        if self.level then self.level:setLose() end
    end
end

-- Move along the current direction by speed * dt.
--
-- The original snapped to integer grid coordinates by testing whether cellX/cellY
-- were ~integers within ACCEPTING_TIME_ERROR. With dt-based movement the position
-- overshoots the node instead of landing exactly, so that test would drift the
-- enemy off the path. Instead we detect when the step REACHES OR PASSES the next
-- node along the current axis, snap exactly onto it, and advance. This is the
-- most port-sensitive piece — snapping is what keeps enemies on the lane.
function DiseaseModel:_moveAlongPath(dt)
    local node = self.path and self.path[self.nextPathIndex]
    if not node then return end -- past the end: stop (loss already triggered)

    local vec = DIR_VECTOR[self.dir]
    local dxStep = vec[1] * self.speed * dt
    local dyStep = vec[2] * self.speed * dt

    local newX = self.cellX + dxStep
    local newY = self.cellY + dyStep

    local nx, ny = node[1], node[2]

    -- Reached/passed the node along the movement axis?
    local reached = false
    if vec[1] ~= 0 then
        reached = (vec[1] > 0 and newX >= nx) or (vec[1] < 0 and newX <= nx)
    elseif vec[2] ~= 0 then
        reached = (vec[2] > 0 and newY >= ny) or (vec[2] < 0 and newY <= ny)
    end

    if reached then
        -- Snap exactly onto the node, pause to re-evaluate next frame.
        self.cellX, self.cellY = nx, ny
        self:_updateViewPosition()
        self:_advancePath()
        self.action = DiseaseAction.WAITING -- was: ui:idleAnimate(self.dir) on landing
        return
    end

    self.cellX, self.cellY = newX, newY
    self:_updateViewPosition()
end

--------------------------------------------------------------------------------
-- Update — reproduces the original ordering exactly.
--------------------------------------------------------------------------------

-- Per-frame logic. `dt` is LÖVE delta time in seconds.
function DiseaseModel:update(dt)
    -- 1. Death.
    if self.alive and self.hp <= 0 then
        self.alive = false
        if self.level then
            self.level:dumpDisease(self)
            self.level = nil
        end
        if self.status == CharacterStatus.FROZEN then
            -- was: ui:deFrozenAnimate()
        end
        self.action = DiseaseAction.DEAD
        -- was: ui:dieAnimate(self.dir)
        return
    end

    -- 2. Frozen gate: thaw when the timer elapses, otherwise tick it and stop.
    if self.status == CharacterStatus.FROZEN then
        if self.frozenStatusCounter <= DISTANCE_EPSILON then
            self:deFrozen()
        else
            self.frozenStatusCounter = self.frozenStatusCounter - dt
            return -- cannot move while frozen
        end
    end

    -- 3. Look for an attackable target in range.
    local target = nil
    if self.alive and self.level then
        target = self:_findTarget()
    end

    -- 4. A live target (and not ignoring cells) means we switch to attacking.
    if target and not self.ignoreCell then
        self.action = DiseaseAction.ATTACKING
    end

    -- 5/6/7. State machine: one transition per frame, matching the original.
    if self.action == DiseaseAction.ATTACKING then
        if target then
            self:changeDirectionToTarget(target)

            -- HIT RECHARGE: the original detected a hit when timeCounter /
            -- hitRechargeTime landed on an integer, which only works with a
            -- fixed tick. With variable dt that almost never lands exactly, so
            -- we use a per-disease countdown timer instead.
            self.hitTimer = self.hitTimer - dt
            if self.hitTimer <= 0 then
                self:hitTarget(target)
                self.hitTimer = self.hitRechargeTime
            end

            -- was: ui:idleAnimate(self.dir)
            self:changeDirectionOnPath()
        else
            self.action = DiseaseAction.WAITING
            -- was: ui:idleAnimate(self.dir)
        end

    elseif self.action == DiseaseAction.WAITING then
        self.action = DiseaseAction.WALKING
        self:changeDirectionOnPath()
        -- was: ui:walkAnimate(self.dir)

    elseif self.action == DiseaseAction.WALKING then
        self:_moveAlongPath(dt)
        -- was: ui:walkAnimate(self.dir) / idle on landing
    end
end


return DiseaseModel
