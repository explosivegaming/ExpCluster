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

local function Angle(entity)
    local angle = math.atan2(entity.position.y, entity.position.x) / math.pi
    for direction, requiredAngle in pairs(directions) do
        if angle < requiredAngle then
            return direction
        end
    end

    return "W"
end

local custom_string = " *"
local custom_string_len = #custom_string

local function station_name_changer(event)
    local entity = event.created_entity
    local name = entity.name
    if name == "entity-ghost" then
        if entity.ghost_name ~= "train-stop" then return end
        local backername = entity.backer_name
        if backername ~= "" then
            entity.backer_name = backername .. custom_string
        end
    elseif name == "train-stop" then -- only do the event if its a train stop
        local backername = entity.backer_name
        if backername:sub(-custom_string_len) == custom_string then
            entity.backer_name = backername:sub(1, -custom_string_len - 1)
            return
        end

        local boundingBox = entity.bounding_box
        -- expanded box for recourse search:
        local bounding2 = { { boundingBox.left_top.x - 100, boundingBox.left_top.y - 100 }, { boundingBox.right_bottom.x + 100, boundingBox.right_bottom.y + 100 } }
        -- gets all resources in bounding_box2:
        local recourses = game.surfaces[1].find_entities_filtered{ area = bounding2, type = "resource" }
        if #recourses > 0 then -- save cpu time if their are no recourses in bounding_box2
            local closest_distance
            local px, py = boundingBox.left_top.x, boundingBox.left_top.y
            local recourse_closed

            -- Check which recourse is closest
            for i, item in ipairs(recourses) do
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
                    :gsub("__direction__", Angle(entity))
                    :gsub("__x__", math.floor(entity.position.x))
                    :gsub("__y__", math.floor(entity.position.y))
            end
        end
    end
end

-- Add handler to robot and player build entities
Event.add(defines.events.on_built_entity, station_name_changer)
Event.add(defines.events.on_robot_built_entity, station_name_changer)
