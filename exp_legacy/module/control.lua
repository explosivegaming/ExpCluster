
--- Please go to ./config if you want to change settings, each file is commented with what it does
-- if it is not in ./config then you should not attempt to change it unless you know what you are doing
-- all files which are loaded (including the config files) are present in ./config/file_loader.lua
-- this file is the landing point for all scenarios please DO NOT edit directly, further comments are to aid development

log('[START] -----| Explosive Gaming Scenario Loader |-----')
log('[INFO] Setting up lua environment')

-- Require the global overrides
require 'overrides.stages' -- Data stages used in factorio, often used to test for runtime
require 'overrides.print' -- Overrides the _G.print function
require 'overrides.math' -- Omitting the math library is a very bad idea
require 'overrides.table' -- Adds alot more functions to the table module
global.version = require 'overrides.version' -- The current version for exp gaming scenario
inspect = require 'overrides.inspect' -- Used to covert any value into human readable string
Debug = require 'overrides.debug' -- Global Debug module
_C = require 'expcore.common' -- _C is used to store lots of common functions expected to be used
_CHEATS = false
_DEBUG = false

-- Please go to config/file_loader.lua to edit the files that are loaded
log('[INFO] Reading loader config')
local files = require 'config._file_loader'

-- Error handler for loading files
local errors = {}
local error_count = 0
local error_format = '[ERROR] %s :: %s'
local currently_loading = nil
local function error_handler(err)
    error_count = error_count + 1
    if err:find('module '..currently_loading..' not found;', nil, true) then
        log('[ERROR] File not found: '..currently_loading)
        errors[error_count] = error_format:format(currently_loading, err)
    else
        log('[ERROR] Failed to load: '..currently_loading)
        errors[error_count] = debug.traceback(error_format:format(currently_loading, err))
    end
end

-- Loads all files from the config and logs that they are loaded
local total_file_count = string.format('%3d', #files)
for index, path in pairs(files) do
    currently_loading = path
    log(string.format('[INFO] Loading file %3d/%s (%s)', index, total_file_count, path))
    xpcall(require, error_handler, path)
end

-- Override the default require; require can no longer load new scripts
log('[INFO] Require Overwrite! No more requires can be made!')
require 'overrides.require'

-- Logs all errors again to make it make it easy to find
log('[INFO] All files loaded with '..error_count..' errors:')
for _, error in ipairs(errors) do log(error) end
log('[END] -----| Explosive Gaming Scenario Loader |-----')