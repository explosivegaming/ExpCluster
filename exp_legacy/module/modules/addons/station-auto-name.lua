--- LuaPlayerBuiltEntityEventFilters
--- Events.set_event_filter(defines.events.on_built_entity, {{filter = "name", name = "fast-inserter"}})
local Event = require("modules/exp_legacy/utils/event") --- @dep utils.event
local config = require("modules.exp_legacy.config.station_auto_name") --- @dep config.chat_reply

-- Credit to Cooldude2606 for using his lua magic to make this function.
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

--- @param entity LuaEntity
--- @return string
local function get_direction(entity)
    local angle = math.atan2(entity.position.y, entity.position.x) / math.pi
    for direction, required_angle in pairs(directions) do
        if angle < required_angle then
            return direction
        end
    end

    return "W"
end

local custom_string = " *"
local custom_string_len = #custom_string

--- @param event EventData.on_built_entity | EventData.on_robot_built_entity
local function station_name_changer(event)
    local entity = event.entity
    local name = entity.name
    if name == "entity-ghost" then
        if entity.ghost_name ~= "train-stop" then return end
        local backer_name = entity.backer_name
        if backer_name ~= "" then
            entity.backer_name = backer_name .. custom_string
        end
    elseif name == "train-stop" then -- only do the event if its a train stop
        local backer_name = entity.backer_name or ""
        if backer_name:sub(-custom_string_len) == custom_string then
            entity.backer_name = backer_name:sub(1, -custom_string_len - 1)
            return
        end

        local bounding_box = entity.bounding_box
        -- expanded box for recourse search:
        local bounding2 = { { bounding_box.left_top.x - 100, bounding_box.left_top.y - 100 }, { bounding_box.right_bottom.x + 100, bounding_box.right_bottom.y + 100 } }
        -- gets all resources in bounding_box2:
        local resources = game.surfaces[1].find_entities_filtered{ area = bounding2, type = "resource" }
        if #resources > 0 then -- save cpu time if their are no resources in bounding_box2
            local closest_distance
            local px, py = bounding_box.left_top.x, bounding_box.left_top.y
            local recourse_closed

            -- Check which recourse is closest
            for i, item in ipairs(resources) do
                local dx, dy = px - item.bounding_box.left_top.x, py - item.bounding_box.left_top.y
                local distance = (dx * dx) + (dy * dy)
                if not closest_distance or distance < closest_distance then
                    recourse_closed = item
                    closest_distance = distance
                end
            end

            local item_name = recourse_closed.name
            if item_name then -- prevent errors if something went wrong
                local item_name2 = item_name:gsub("^%l", string.upper):gsub("-", " ") -- removing the - and making first letter capital

                local item_type = "item"
                if item_name == "crude-oil" then
                    item_type = "fluid"
                end

                entity.backer_name = config.station_name:gsub("__icon__", "[img=" .. item_type .. "." .. item_name .. "]")
                    :gsub("__item_name__", item_name2)
                    :gsub("__backer_name__", entity.backer_name)
                    :gsub("__direction__", get_direction(entity))
                    :gsub("__x__", math.floor(entity.position.x))
                    :gsub("__y__", math.floor(entity.position.y))
            end
        end
    end
end

-- Add handler to robot and player build entities
Event.add(defines.events.on_built_entity, station_name_changer)
Event.add(defines.events.on_robot_built_entity, station_name_changer)
