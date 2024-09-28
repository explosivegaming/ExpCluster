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
-- @tparam number num The number to be rounded
-- @tparam[opt=0] number idp The number of decimal places to round to
-- @treturn number The input number rounded to the given number of decimal places
math.round = function(num, idp)
    local mult = 10 ^ (idp or 0)
    return floor(num * mult + 0.5) / mult
end

--- Clamp a number better a minimum and maximum value, preserves NaN (not the same as nil)
-- @tparam number num The number to be clamped
-- @tparam number min The lower bound of the accepted range
-- @tparam number max The upper bound of the accepted range
-- @treturn number The input number clamped to the given range
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
-- @tparam number x1 The X coordinate of the first point on the line
-- @tparam number y1 The Y coordinate of the first point on the line
-- @tparam number x2 The X coordinate of the second point on the line
-- @tparam number y2 The Y coordinate of the second point on the line
-- @treturn number The slope of the line
math.slope = function(x1, y1, x2, y2)
    return abs((y2 - y1) / (x2 - x1))
end

--- Returns the y-intercept of a line given ibe point on the line and its slope
-- @tparam number x The X coordinate of point on the line
-- @tparam number y The Y coordinate of point on the line
-- @tparam number slope The slope / gradient of the line
-- @treturn number The y-intercept of the line
math.y_intercept = function(x, y, slope)
    return y - (slope * x)
end

local deg_to_rad = math.tau / 360
--- Returns the angle x (given in radians) in degrees
math.degrees = function(x)
    return x * deg_to_rad
end

return math
