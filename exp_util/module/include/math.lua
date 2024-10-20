-- luacheck:ignore global math

local floor = math.floor
local abs = math.abs

--- Constant value representing the square root of 2
math.sqrt2 = math.sqrt(2)

--- Constant value representing the reciprocal of square root of 2
math.inv_sqrt2 = 1 / math.sqrt2

--- Constant value representing the value of Tau aka 2*Pi
math.tau = 2 * math.pi

--- Rounds a number to certain number of decimal places, does not work on significant figures
--- @param num number The number to be rounded
--- @param idp number? The number of decimal places to round to
--- @return number
math.round = function(num, idp)
    local mult = 10 ^ (idp or 0)
    return floor(num * mult + 0.5) / mult
end

--- Clamp a number better a minimum and maximum value, preserves NaN (not the same as nil)
--- @param num number The number to be clamped
--- @param min number The lower bound of the accepted range
--- @param max number The upper bound of the accepted range
--- @return number
math.clamp = function(num, min, max)
    if num < min then
        return min
    elseif num > max then
        return max
    else
        return num
    end
end

--- Returns the slope / gradient of a line given two points on the line
--- @param x1 number The X coordinate of the first point on the line
--- @param y1 number The Y coordinate of the first point on the line
--- @param x2 number The X coordinate of the second point on the line
--- @param y2 number The Y coordinate of the second point on the line
--- @return number
math.slope = function(x1, y1, x2, y2)
    return abs((y2 - y1) / (x2 - x1))
end

--- Returns the y-intercept of a line given ibe point on the line and its slope
--- @param x number The X coordinate of point on the line
--- @param y number The Y coordinate of point on the line
--- @param slope number The slope / gradient of the line
--- @return number
math.y_intercept = function(x, y, slope)
    return y - (slope * x)
end

local deg_to_rad = math.tau / 360
--- Returns the angle x (given in radians) in degrees
--- @param x number
--- @return number
math.degrees = function(x)
    return x * deg_to_rad
end

--- Returns the sign of the input value
--- @param x number
--- @return number
math.sign = function(x)
    return x < 0 and -1 or 0
end

return math
