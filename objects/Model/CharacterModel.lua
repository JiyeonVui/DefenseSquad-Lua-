CharacterModel = Object:extend()

function CharacterModel:new(charType)
    self._level = nil;
    self._type = charType;
    self._hp = 0;
    self._status = CharacterModelDefinition.CharacterStatus[1];
    self._frozenStatusCounter = 0;
    self._alive = true;
    self._cellX = 0;
    self._cellY = 0;
end

function CharacterModel:takeDamage(damage);
    self._hp = self.hp - damage
end
function CharacterModel:setStatus(characterStatus)
    self._status = characterStatus
end
function CharacterModel:getStatus() 
    return self._status
end

function CharacterModel:setFronzenCounter(fronzenCounter)
    self._frozenStatusCounter = fronzenCounter
end

function CharacterModel:isAlive()
    return self._alive
end

function CharacterModel:setPosition(cellX, cellY)
    self._cellX = cellX
    self._cellY = cellY
end

function CharacterModel:getPosition()
    return { cellX = self._cellX, cellY = self._cellY }
end

function CharacterModel:getPositionCellX()
    return self._cellX
end

function CharacterModel:getPositionCellY()
    return self._cellY
end

function CharacterModel:update()

end

function CharacterModel:getDistanceToOther(other)
    local dx = self._cellX - other._cellX
    local dy = self._cellY - other._cellY
    return math.sqrt(dx * dx + dy * dy)
end

function CharacterModel:getHP() 
    return self._hp
end

function CharacterModel:__setLevel(levelModel)
    self._level = levelModel
end

