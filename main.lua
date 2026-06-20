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
    gotoRoom('MainMenuScene')
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
function love.mousepressed(x, y, button)
    if current_room and current_room.mousepressed then
        current_room:mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if current_room and current_room.mousereleased then
        current_room:mousereleased(x, y, button)
    end
end