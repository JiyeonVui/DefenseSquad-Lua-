local json = require 'libraries/json/json' -- TODO: provide rxi/json.lua at this path

LevelModel = Object:extend()


function LevelModel:new(level, stage)
    self._levelId = level or 0
    self._stage   = stage

    -- Địa hình TĨNH: map[x][y] (col-major, khớp JSON). Mỗi ô là số nguyên loại ô.
    self._map = {}

    -- Trạng thái ĐỘNG, tách hẳn khỏi địa hình (col-major):
    --   _occupants[x][y]     = cell đang chiếm ô
    --   _energySources[x][y] = true nếu ô là nguồn năng lượng
    self._occupants     = {}
    self._energySources = {}

    -- Enemy pathing. enemyPaths is a list of paths; each path is a list of nodes.
    self._enemyPaths = {}
    self._beginPaths = {}
    self._endPaths   = {}

    -- Waves and the index of the next wave to spawn (replaces the C++ iterator).
    self._waveList  = {}
    self._waveIndex = 1

    -- Live entity lists (plain arrays; removed back-to-front during iteration).
    self._cellList       = {}
    self._diseaseList    = {}
    self._projectileList = {}
    self._cellBarList    = {}

    -- Dump lists: entities flagged dead this frame, swept by _garbageCollect.
    self._cellDump       = {}
    self._diseaseDump    = {}
    self._projectileDump = {}

    -- Timing.
    self._timeCounter = 0.0
    self._isCounting  = false

    -- winTimeCounter < -0.5 means "win not yet scheduled". setWin() raises it to
    -- a positive countdown; when it decays to ~0 the actual win() fires.
    self._winTimeCounter = -1.0
    self._loseCheck      = false

    -- Economy. NumericModel is collapsed to a plain value plus a UI reference.
    self._energyValue = 0
    self._goldValue   = 0

    -- UI / engine references (wired up by the Stage; left nil here).
    self._progressor = nil -- UIProgressor
    self._pauser     = nil -- UIPause
    self._remover    = nil -- UIRemove
    self._control    = nil -- GSControlLayer (do GameScene inject sau khi dựng map)

    self._reward = 0

    self:readLevelFromJson(self._levelId)
end

--------------------------------------------------------------------------------
-- Simple accessors
--------------------------------------------------------------------------------

-- Return the level grid.
function LevelModel:getMap() return self._map end

-- Original exposed a const copy (getMap) and a mutable ref (__getMap). In Lua a
-- table is already a reference, so both map to the same accessor.
LevelModel.__getMap = LevelModel.getMap

-- True nếu ô (x, y) đang có cell chiếm (lớp động, col-major).
function LevelModel:isOccupied(x, y)
    local col = self._occupants[x]
    return col ~= nil and col[y] ~= nil
end

-- Cell đang chiếm ô (x, y), hoặc nil.
function LevelModel:getOccupant(x, y)
    local col = self._occupants[x]
    return col and col[y]
end

-- Return the list of waves.
function LevelModel:getWaveList() return self._waveList end

-- Live entity list accessors (the C++ "__" model-internal getters).
function LevelModel:getDiseaseList() return self._diseaseList end
function LevelModel:getCellList()    return self._cellList end
LevelModel.__getDiseaseList = LevelModel.getDiseaseList
LevelModel.__getCellList    = LevelModel.getCellList

-- Return a random enemy path (the C++ __getEnemyPath picked one at random).
function LevelModel:getEnemyPath()
    if #self._enemyPaths == 0 then return nil end
    local index = math.random(1, #self._enemyPaths)
    return self._enemyPaths[index]
end
LevelModel.__getEnemyPath = LevelModel.getEnemyPath

function LevelModel:getEndPaths()   return self._endPaths end
function LevelModel:getBeginPaths() return self._beginPaths end
function LevelModel:getLevelId()    return self._levelId end

-- Tầng đặt cell (do GameScene tạo và inject). Model giữ tham chiếu để điều phối
-- (chọn cell, bật chế độ remove...), KHÔNG tự dựng — giống _pauser/_remover.
function LevelModel:setControlLayer(control) self._control = control end
function LevelModel:getControlLayer()        return self._control end

-- Reward granted for clearing the level.
function LevelModel:getReward() return self._reward end

-- Reset the time counter and begin counting (gameplay actually starts).
function LevelModel:startCounting()
    self._timeCounter = 0.0
    self._isCounting  = true
end

-- Current elapsed level time.
function LevelModel:getTimeCounter() return self._timeCounter end

-- Schedule lose / win. setWin starts the short pre-win countdown.
function LevelModel:setLose() self._loseCheck = true end
function LevelModel:setWin()  self._winTimeCounter = 1.5 end

--------------------------------------------------------------------------------
-- Economy
--------------------------------------------------------------------------------

-- Current energy total.
function LevelModel:getEnergyValue() return self._energyValue end

-- Add (or subtract, with a negative n) energy and refresh its UI.
function LevelModel:addEnergyValue(n)
    self._energyValue = self._energyValue + n
    -- TODO: self.energy:setValue(self._energyValue) -- update energy UI
end

-- Add (or subtract) gold and refresh its UI.
function LevelModel:addGoldValue(n)
    self._goldValue = self._goldValue + n
    -- TODO: self.gold:setValue(self._goldValue) -- update gold UI
end

-- Briefly highlight the energy display (e.g. when the player can't afford a cell).
function LevelModel:emphasizeEnergy()
    -- TODO: self.energy:emphasize() -- flash/shake the energy UI
end

-- Spawn a collectable energy object at grid cell (cellX, cellY).
function LevelModel:addEnergyObject(cellX, cellY)
    -- col-major map[x][y]. Đánh dấu nguồn năng lượng ở lớp động riêng,
    -- KHÔNG ghi đè loại địa hình của ô.
    if self._map[cellX] and self._map[cellX][cellY] ~= nil then
        self._energySources[cellX] = self._energySources[cellX] or {}
        self._energySources[cellX][cellY] = true
    end
    -- TODO: spawn an EnergyObject game object in the stage's Area at this cell.
end

--------------------------------------------------------------------------------
-- Entity registration
--------------------------------------------------------------------------------

-- Place a cell at grid (cellX, cellY): track it, mark the tile occupied, and
-- hand it to the stage so it updates/draws.
function LevelModel:addCell(cell, cellX, cellY)
    cell.cellX = cellX
    cell.cellY = cellY
    table.insert(self._cellList, cell)

    -- Đánh dấu ô (x, y) bị chiếm ở lớp động (col-major).
    self._occupants[cellX] = self._occupants[cellX] or {}
    self._occupants[cellX][cellY] = cell
    -- TODO: register `cell` with the stage's Area for update/draw.
end

-- Track a newly spawned disease (enemy).
function LevelModel:addDisease(disease)
    table.insert(self._diseaseList, disease)
    -- TODO: register `disease` with the stage's Area for update/draw.
end

-- Track a newly fired projectile.
function LevelModel:addProjectile(projectile)
    table.insert(self._projectileList, projectile)
    -- TODO: register `projectile` with the stage's Area for update/draw.
end

--------------------------------------------------------------------------------
-- Deferred removal (never erase mid-loop; flag + sweep in _garbageCollect)
--------------------------------------------------------------------------------

-- Flag a cell dead and queue it for collection.
function LevelModel:dumpCell(cell)
    cell.dead = true
    table.insert(self._cellDump, cell)

    -- Giải phóng ô khi cell chết (col-major). Chỗ DUY NHẤT clear occupant.
    local col = cell.cellX and self._occupants[cell.cellX]
    if col then col[cell.cellY] = nil end
end

-- Flag a disease dead and queue it for collection.
function LevelModel:dumpDisease(disease)
    disease.dead = true
    table.insert(self._diseaseDump, disease)
end

-- Flag a projectile dead and queue it for collection.
function LevelModel:dumpProjectile(projectile)
    projectile.dead = true
    table.insert(self._projectileDump, projectile)
end

-- Find the cell occupying grid (x, y) and dump it, freeing the tile.
function LevelModel:findAndRemoveCell(x, y)
    local cell = self:getOccupant(x, y)   -- (x, y) col-major
    if cell then
        self:dumpCell(cell)               -- dumpCell tự clear occupant
    end
end

--------------------------------------------------------------------------------
-- Pause / resume
--------------------------------------------------------------------------------

-- Freeze gameplay updates.
function LevelModel:pause()
    self._isCounting = false
    -- TODO: self.pauser:show() / pause audio
end

-- Resume gameplay updates.
function LevelModel:resume()
    self._isCounting = true
    -- TODO: self.pauser:hide() / resume audio
end

--------------------------------------------------------------------------------
-- End-of-level
--------------------------------------------------------------------------------

-- Player won: grant reward and surface the win UI.
function LevelModel:win()
    self._isCounting = false
    -- TODO: play win sound, show win UI, award self._reward, advance progress.
end

-- Player lost: surface the lose UI.
function LevelModel:lose()
    self._isCounting = false
    -- TODO: play lose sound, show lose UI.
end

--------------------------------------------------------------------------------
-- Main update loop — preserves the original ordering exactly.
--------------------------------------------------------------------------------

-- Drive one frame of the level. `dt` is the LÖVE delta time in seconds.
function LevelModel:update(dt)
    -- a. Do nothing until counting has started.
    if not self._isCounting then return end

    -- b. Advance level time by real elapsed time.
    self._timeCounter = self._timeCounter + dt

    -- c. Update every live entity (cells, diseases, projectiles, cell bars).
    self:_updateList(self._cellList, dt)
    self:_updateList(self._diseaseList, dt)
    self:_updateList(self._projectileList, dt)
    self:_updateList(self._cellBarList, dt)

    -- d. Sweep anything flagged dead this frame.
    self:_garbageCollect()

    -- e. Spawn the next wave once its scheduled time arrives.
    local wave = self._waveList[self._waveIndex]
    if wave and self._timeCounter >= wave.time then
        self:_addEnemiesOnWave()
        -- TODO: self.progressor:updateOnWave() -- advance the wave progress UI
    end

    -- f. A queued loss takes priority and ends the update immediately.
    if self._loseCheck then
        self:lose()
        return
    end

    -- g. Schedule the win once every wave has spawned and no disease remains.
    local allWavesDone = self._waveIndex > #self._waveList
    if self._winTimeCounter < -0.5
        and #self._diseaseList == 0
        and allWavesDone then
        self:setWin()
    end

    -- h. Run the short pre-win countdown; fire win() when it elapses.
    if self._winTimeCounter > -0.5 then
        self._winTimeCounter = self._winTimeCounter - dt
        if self._winTimeCounter <= 0 then
            self:win()
        end
    end
end

--------------------------------------------------------------------------------
-- Debug
--------------------------------------------------------------------------------

-- Print a one-line snapshot of the current level state.
function LevelModel:printLevelState()
    print(string.format(
        "[LevelModel %d] t=%.2f energy=%d gold=%d cells=%d diseases=%d projectiles=%d wave=%d/%d",
        self._levelId, self._timeCounter, self._energyValue, self._goldValue,
        #self._cellList, #self._diseaseList, #self._projectileList,
        self._waveIndex, #self._waveList))
end

--------------------------------------------------------------------------------
-- Internal helpers (private in the original; prefixed with _ here)
--------------------------------------------------------------------------------

-- Update every object in `list`, passing dt. Iterated forward; dead objects are
-- left in place for _garbageCollect (objects must not be erased mid-loop).
function LevelModel:_updateList(list, dt)
    for i = 1, #list do
        local obj = list[i]
        if obj.update and not obj.dead then
            obj:update(dt)
        end
    end
end

-- Remove the entries of `dump` from `live`, then empty the dump. Iterates
-- back-to-front so removals don't shift unvisited indices.
local function sweep(live, dump)
    for d = 1, #dump do
        local target = dump[d]
        for i = #live, 1, -1 do
            if live[i] == target then
                if live[i].destroy then live[i]:destroy() end
                table.remove(live, i)
                break
            end
        end
    end
    for i = #dump, 1, -1 do
        dump[i] = nil
    end
end

-- Collect everything flagged dead this frame across all entity lists.
function LevelModel:_garbageCollect()
    sweep(self._cellList, self._cellDump)
    sweep(self._diseaseList, self._diseaseDump)
    sweep(self._projectileList, self._projectileDump)
end

-- Spawn the current wave's enemies, then advance to the next wave.
function LevelModel:_addEnemiesOnWave()
    local wave = self._waveList[self._waveIndex]
    if not wave then return end

    for _, enemy in ipairs(wave.enemies or {}) do
        -- enemy carries its spawn data (e.g. type, count, path). Actual
        -- DiseaseModel construction depends on that class.
        -- TODO: local disease = DiseaseModel(self, enemy); self:addDisease(disease)
        local _ = enemy
    end

    if wave.huge then
        -- TODO: trigger "huge wave" warning UI / sound.
    end

    self._waveIndex = self._waveIndex + 1
end

--------------------------------------------------------------------------------
-- Level loading
--------------------------------------------------------------------------------

-- Read data/level/level{N}.json and populate map, paths, waves and economy.
function LevelModel:readLevelFromJson(level)
    local path = string.format("data/level/level%d.json", level)

    local contents = love.filesystem.read(path)
    if not contents then
        print("[LevelModel] could not read " .. path)
        return
    end

    local data = json.decode(contents)

    self._energyValue = data.initialEnergy or 0
    self._map         = data.map or {}
    self._enemyPaths  = data.enemyPaths or {}
    self._beginPaths  = data.beginPaths or {}
    self._endPaths    = data.endPaths or {}
    self._reward      = data.reward or 0

    -- Each wave: { time = <seconds>, huge = <bool>, enemies = { ... } }.
    self._waveList  = data.waves or {}
    self._waveIndex = 1
end

return LevelModel
