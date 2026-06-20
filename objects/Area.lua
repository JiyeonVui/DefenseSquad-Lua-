Area = Object:extend()

function Area:new(room)
    self.room = room
    self.game_objects = {}
end

function Area:update(dt)
    for i = #self.game_objects, 1, -1 do
        local obj = self.game_objects[i]
        obj:update(dt)
        if obj.dead then
            table.remove(self.game_objects, i)
        end
    end
end

function Area:draw()
    for _, obj in ipairs(self.game_objects) do
        obj:draw()
    end
end

function Area:addGameObject(class, x, y, opts)
    local obj = class(self, x, y, opts)
    table.insert(self.game_objects, obj)
    return obj
end

function Area:queryByTag(tag)
    local result = {}
    for _, obj in ipairs(self.game_objects) do
        if obj[tag] then table.insert(result, obj) end
    end
    return result
end

function Area:destroy()
    self.game_objects = {}
end

return Area
