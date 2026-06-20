Shooter = Object:extend()

function Shooter:new()
    self._projectileId = nil
    self._shootRechargeTime = 0
    self._shootTimeCounter = 0
end


function Shooter:shoot(target)
    
end

function Shooter:setProjectileId( projectileId )
    self._projectileId = projectileId
end