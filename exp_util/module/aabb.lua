--[[-- ExpUtil - AABB
Provides a set of common functions for working with axis aligned bounding boxes
]]

local floor = math.floor
local ceil = math.ceil
local min = math.min
local max = math.max

--- @class ExpUtil_AABB
local AABB = {}

--- Check if an area is valid
--- @param aabb BoundingBox
--- @return boolean # True if the area is valid
function AABB.valid(aabb)
    return aabb.left_top.x < aabb.right_bottom.x and aabb.left_top.y < aabb.right_bottom.y
end

--- Clone an area, allows for safe mutation of an input value
--- @param aabb BoundingBox
--- @return BoundingBox
function AABB.clone(aabb)
    return {
        left_top = { x = aabb.left_top.x, y = aabb.left_top.y },
        right_bottom = { x = aabb.right_bottom.x, y = aabb.right_bottom.y },
    }
end

--- Expand an area to be integer aligned, expanding away from 0
--- @param aabb BoundingBox
--- @return BoundingBox
function AABB.expand(aabb)
    return {
        left_top = { x = floor(aabb.left_top.x), y = floor(aabb.left_top.y) },
        right_bottom = { x = ceil(aabb.right_bottom.x), y = ceil(aabb.right_bottom.y) },
    }
end

--- Contract an area to be integer aligned, contracting towards 0
--- @param aabb BoundingBox
--- @return BoundingBox
function AABB.contract(aabb)
    return {
        left_top = { x = ceil(aabb.left_top.x), y = ceil(aabb.left_top.y) },
        right_bottom = { x = floor(aabb.right_bottom.x), y = floor(aabb.right_bottom.y) },
    }
end

--- Expand an area to include all other areas
--- @param aabb BoundingBox
--- @param ... BoundingBox
--- @return BoundingBox
function AABB.union(aabb, ...)
    local rtn = AABB.clone(aabb)
    for _, next_aabb in ipairs{ ... } do
        rtn.left_top.x = min(rtn.left_top.x, next_aabb.left_top.x)
        rtn.left_top.y = min(rtn.left_top.y, next_aabb.left_top.y)
        rtn.right_bottom.x = max(rtn.right_bottom.x, next_aabb.right_bottom.x)
        rtn.right_bottom.y = max(rtn.right_bottom.y, next_aabb.right_bottom.y)
    end
    return rtn
end

--- Contract an area to include to the overlap of all areas
--- @param aabb BoundingBox
--- @param ... BoundingBox
--- @return BoundingBox? # Nil if there is no intersection
function AABB.intersect(aabb, ...)
    local rtn = AABB.clone(aabb)
    for _, next_aabb in ipairs{ ... } do
        rtn.left_top.x = max(rtn.left_top.x, next_aabb.left_top.x)
        rtn.left_top.y = max(rtn.left_top.y, next_aabb.left_top.y)
        rtn.right_bottom.x = min(rtn.right_bottom.x, next_aabb.right_bottom.x)
        rtn.right_bottom.y = min(rtn.right_bottom.y, next_aabb.right_bottom.y)
        if not AABB.valid(rtn) then
            return nil
        end
    end
    return rtn
end

--- Check if a point is contained within an area
--- @param aabb BoundingBox
--- @param point MapPosition
--- @return boolean # True if the point is within or on the edge of the bounding box
function AABB.contains_point(aabb, point)
    return point.x >= aabb.left_top.x and point.y >= aabb.left_top.y
        and point.x <= aabb.right_bottom.x and point.y <= aabb.right_bottom.y
end

--- Check if an area is fulling contained within another area
--- @param aabb BoundingBox
--- @param other BoundingBox
--- @return boolean # True if the point is within or on the edge of the bounding box
function AABB.contains_area(aabb, other)
    return AABB.contains_point(aabb, other.left_top) and AABB.contains_point(aabb, other.right_bottom)
end

return AABB
