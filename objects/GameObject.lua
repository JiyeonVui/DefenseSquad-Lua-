GameObject = Object:extend()

function GameObject:new(area, x, y, opts)
    opts = opts or {}
    for k, v in pairs(opts) do self[k] = v end
    self.area = area
    self.x = x or 0
    self.y = y or 0
    self.dead = false
end

function GameObject:update(dt) end
function GameObject:draw() end

function GameObject:destroy()
    self.dead = true
end

return GameObject
