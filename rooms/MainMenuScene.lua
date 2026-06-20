local MMBackgroundLayer = require("rooms/MMBackgroundLayer")
local MMControl = require("rooms/MMControl")

MainMenuScene = Object:extend()

function MainMenuScene:new()
    self._mainMenuScene = self;
    self:addBackground()
    self:controlButton()
end



function MainMenuScene:addBackground()
    self._backgroundLayer = MMBackgroundLayer()

end


function MainMenuScene:controlButton()
    self._buttonLayer = MMControl()
end

function MainMenuScene:mousepressed(x, y, button)
    if self._buttonLayer then
        self._buttonLayer:mousepressed(x, y, button)
    end
end

function MainMenuScene:mousereleased(x, y, button)
    if self._buttonLayer then
        self._buttonLayer:mousereleased(x, y, button)
    end
end


function MainMenuScene:update(dt)
    -- Background trước (có thể có animation), rồi nút
    if self._backgroundLayer and self._backgroundLayer.update then
        self._backgroundLayer:update(dt)
    end
    if self._buttonLayer and self._buttonLayer.update then
        self._buttonLayer:update(dt)
    end
end

function MainMenuScene:draw()
    -- Thứ tự vẽ = thứ tự lớp: nền dưới cùng vẽ trước, nút trên cùng vẽ sau
    if self._backgroundLayer and self._backgroundLayer.draw then
        self._backgroundLayer:draw()
    end
    if self._buttonLayer and self._buttonLayer.draw then
        self._buttonLayer:draw()
    end
end


return MainMenuScene

