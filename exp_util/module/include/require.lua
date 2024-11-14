-- luacheck:ignore global require
--- @diagnostic disable

local package = require("modules/exp_util/include/package")
local loaded = package.loaded
local _require = require

-- This replace function is used to avoid additional lines in stack traces during control stage
local function replace()
    require = function(path)
        --- @cast path string
        if package.lifecycle == package.lifecycle_stage.runtime then
            local replaced = path:gsub("%.", "/")
            if not replaced:match("^__(.-)__") then
                replaced = "__level__/" .. replaced
            end
            if not replaced:match(".lua$") then
                replaced = replaced .. ".lua"
            end
            return loaded[path]
                or loaded[replaced]
                or error("Can only require files at runtime that have been required in the control stage.", 2)
        else
            return _require(path)
        end
    end
end

return setmetatable({
    on_init = replace,
    on_load = replace,
}, {
    __call = _require,
})
