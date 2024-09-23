--luacheck:ignore global print
local locale_string = {'', '[PRINT] ', nil}
local raw_print = print

function print(str)
    locale_string[3] = str
    log(locale_string)
end

return raw_print