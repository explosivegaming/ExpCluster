--- The items the vlayer can hold and what they do, see control/vlayer.lua
-- @config Vlayer-Items

return {
    --- @type table<string, string>
    allowed_categories = { -- List of categories allowed in vlayer storage
        ["production"] = {
            "solar-panel"
        },
        ["storage"] = {
            "accumulator"
        },
    }
}
