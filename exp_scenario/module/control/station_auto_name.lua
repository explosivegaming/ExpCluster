--[[-- Control - Station Auto Name
Automatically name stations when they are placed based on closest resource and direction from spawn
]]

local config = require("modules.exp_legacy.config.station_auto_name")

local get_direction do
    local directions = {
        ["W"] = -0.875,
        ["NW"] = -0.625,
        ["N"] = -0.375,
        ["NE"] = -0.125,
        ["E"] = 0.125,
        ["SE"] = 0.375,
        ["S"] = 0.625,
        ["SW"] = 0.875,
    }

    --- Get the direction of a position from the centre of the surface
    --- @param position MapPosition
    --- @return string
    function get_direction(position)
        local angle = math.atan2(position.y, position.x) / math.pi
        for direction, required_angle in pairs(directions) do
            if angle < required_angle then
                return direction
            end
        end

        return "W"
    end
end

-- Custom strings are used to detect backer names from ghosts
local custom_string = " *"
local custom_string_len = #custom_string

--- Change the name of a station when it is placed
--- @param event EventData.on_built_entity | EventData.on_robot_built_entity
local function rename_station(event)
    local entity = event.entity
    local name = entity.name
    if name == "entity-ghost" and entity.ghost_name == "train-stop" then
        local backer_name = entity.backer_name
        if backer_name ~= "" then
            entity.backer_name = backer_name .. custom_string
        end

    elseif name == "train-stop" then
        -- Restore the backer name
        local backer_name = entity.backer_name or ""
        if backer_name:sub(-custom_string_len) == custom_string then
            entity.backer_name = backer_name:sub(1, -custom_string_len - 1)
            return
        end

        -- Find the closest resource
        local icon = ""
        local item_name = ""
        local bounding_box = entity.bounding_box
        local resources = entity.surface.find_entities_filtered{ position = entity.position, radius = 250, type = "resource" }
        if #resources > 0 then
            local closest_recourse --- @type LuaEntity?
            local closest_distance = 250 * 250 -- search radius + 1
            local px, py = bounding_box.left_top.x, bounding_box.left_top.y

            -- Check which recourse is closest
            for _, resource in ipairs(resources) do
                local dx = px - resource.bounding_box.left_top.x
                local dy = py - resource.bounding_box.left_top.y
                local distance = (dx * dx) + (dy * dy)
                if distance < closest_distance then
                    closest_distance = distance
                    closest_recourse = resource
                end
            end

            -- Set the item name and icon
            if closest_recourse then
                item_name = closest_recourse.name:gsub("^%l", string.upper):gsub("-", " ") -- remove dashes and making first letter capital
                local product = closest_recourse.prototype.mineable_properties.products[1]
                icon = string.format("[img=%s.%s]", product.type, product.name)
            end
        end

        -- Rename the station
        entity.backer_name = config.station_name
            :gsub("__icon__", icon)
            :gsub("__item_name__", item_name)
            :gsub("__backer_name__", entity.backer_name)
            :gsub("__direction__", get_direction(entity.position))
            :gsub("__x__", math.floor(entity.position.x))
            :gsub("__y__", math.floor(entity.position.y))
    end
end

local e = defines.events

return {
    events = {
        [e.on_built_entity] = rename_station,
        [e.on_robot_built_entity] = rename_station,
    }
}
