function love.conf(t)
    t.identity = nil
    t.version = "11.5"
    t.console = false
    t.window.title = "DefenseSquad"
    t.window.width = 960
    t.window.height = 540
    t.window.resizable = false
    t.window.vsync = 1
    t.modules.joystick = false
    t.modules.physics = false
end
