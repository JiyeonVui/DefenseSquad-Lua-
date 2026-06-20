function random(min, max)
    min = min or 0
    max = max or 1
    return min + math.random() * (max - min)
end

function clamp(x, lower, upper)
    return math.max(lower, math.min(upper, x))
end

function distance(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end
