local loaded = package.loaded
local raw_require = require

function require(path)
    return loaded[path] or error('Can only require files at runtime that have been required in the control stage.', 2)
end

return raw_require