local _levelModelDefinition = require("LevelModelDefinition") 

ProjectileModel = Object:extend()

function ProjectileModel:new(projectileId, cellModel, diseasesTarget)
    self._levelModel = nil
    self._projectileId = projectileId
    self._cellX = cellModel.getPositionCellX()
    self._cellY = cellModel.getPositionCellY()

    self._targetX = diseasesTarget.getPositionCellX()
    self._targetY = diseasesTarget.getPositionCellY()

    local distance = math.sqrt((self._cellX - self._targetX) * (self._cellX - self._targetX) + (self._cellY - self._targetY) * (self._cellY - self._targetY));
    self._directionVectorX = (self._targetX - self._cellX) / distance
    self._directionVectorY = (self._targetY - self._cellY) / distance

    self._speed = 0;
    self._damage = 0
    self._diseaseModelTarget = diseasesTarget
    self._isDestroyed = false
    self._uIProjectile = nil;
end

function ProjectileModel:effectOnHit()

end

function ProjectileModel:update()
    if !self._isDestroyed then
        if (self._cellX - self._targetX) * self._directionVectorX >= 0 and 
        (self._cellY - self._targetY) * self._directionVectorY >= 0 then
            self.hitTarget(self);
        else
            self._cellX = self._cellX + self._directionVectorX * _levelModelDefinition.UPDATING_FREQUENCY * self._speed;
            self._cellY = self._cellY + self._directionVectorY * _levelModelDefinition.UPDATING_FREQUENCY * self._speed;
            -- update ui
        end
    end
end

function ProjectileModel:getPositionCellX()
    return self._cellX
end

function ProjectileModel:getPositionCellY();
    return self._cellY
end

function ProjectileModel:getPosition();
    return { cellX = self._cellX, cellY = self._cellY }
end

function ProjectileModel:hitTarget()
    if self._isDestroyed then 
        self._targetX.takeDamage(self._damage)
        if self._diseaseModelTarget.getHP() > 0 then
            self._diseaseModelTarget.getUIObject().hitAnimate(self._diseaseModelTarget.getDirection())
        end
        self.effectOnHit(self)
        self._isDestroyed = true
        LevelModel.dumpProjectile(self)
        self._uIProjectile.destroyAnimate()
    end
end

function ProjectileModel:__setLevel(levelModel)
    self._levelModel = levelModel
end

function ProjectileModel:setUIObject(uiProjectile)
    self._uIProjectile = uiProjectile
    self._uIProjectile.idleAnimate();
end

function ProjectileModel:getProjectileId() 
    return self._projectileId
end