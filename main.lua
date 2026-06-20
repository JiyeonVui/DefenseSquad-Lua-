require 'globals'

local current_room = nil

function gotoRoom(room_type, ...)
    if current_room and current_room.destroy then
        current_room:destroy()
    end
    current_room = _G[room_type](...)
end

function love.load()
    love.graphics.setDefaultFilter('nearest', 'nearest')
    gotoRoom('GameScene', 0)
end

function love.update(dt)
    if current_room then current_room:update(dt) end
end

function love.draw()
    if current_room then current_room:draw() end
end

function love.keypressed(key)
    if key == 'escape' then love.event.quit() end
end
