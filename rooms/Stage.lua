Stage = Object:extend()

function Stage:new()
    self.area = Area(self)
end

function Stage:update(dt)
    self.area:update(dt)
end

function Stage:draw()
    love.graphics.print("Stage room — code base san sang.", 20, 20)
    self.area:draw()
end

function Stage:destroy()
    self.area:destroy()
    self.area = nil
end

return Stage
