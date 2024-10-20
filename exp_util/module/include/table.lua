--luacheck:ignore global table

local random = math.random
local floor = math.floor
local remove = table.remove
local tonumber = tonumber
local pairs = pairs
local table_size = table_size

--- Adds all keys of the source table to destination table as a shallow copy
-- @tparam table dst The table to insert into
-- @tparam table src The table to insert from
function table.merge(dst, src)
    local dst_len = #dst
    for k, v in pairs(src) do
        if tonumber(k) then
            dst_len = dst_len + 1
            dst[dst_len] = v
        else
            dst[k] = v
        end
    end
end

--[[-- Much faster method for inserting items into an array
@tparam table tbl the table that will have the values added to it
@tparam[opt] number start_index the index at which values will be added, nil means end of the array
@tparam table values the new values that will be added to the table
@treturn table the table that was passed as the first argument
@usage-- Adding 1000 values into the middle of the array
local tbl = {}
local values = {}
for i = 1, 1000 do tbl[i] = i values[i] = i end
table.array_insert(tbl, 500, values) -- around 0.4ms
]]
function table.array_insert(tbl, start_index, values)
    if not values then
        values = start_index
        start_index = nil
    end

    if start_index then
        local starting_length = #tbl
        local adding_length = #values
        local move_to = start_index+adding_length+1
        for offset = starting_length-start_index, 0, -1 do
            tbl[move_to+offset] = tbl[starting_length+offset]
        end
        start_index = start_index-1
    else
        start_index = #tbl
    end

    for offset, item in ipairs(values) do
        tbl[start_index+offset] = item
    end

    return tbl
end

--[[-- Much faster method for inserting keys into a table
@tparam table tbl the table that will have keys added to it
@tparam[opt] number start_index the index at which values will be added, nil means end of the array, numbered indexs only
@tparam table tbl2 the table that may contain both string and numbered keys
@treturn table the table passed as the first argument
@usage-- Merging two tables
local tbl = {}
local tbl2 = {}
for i = 1, 100 do tbl[i] = i tbl['_'..i] = i tbl2[i] = i tbl2['__'..i] = i end
table.table_insert(tbl, 50, tbl2)
]]
function table.table_insert(tbl, start_index, tbl2)
    if not tbl2 then
        tbl2 = start_index
        start_index = nil
    end

    table.array_insert(tbl, start_index, tbl2)
    for key, value in pairs(tbl2) do
        if not tonumber(key) then
            tbl[key] = value
        end
    end

    return tbl
end

--- Searches an array to remove a specific element without an index
-- @tparam table tbl The array to remove the element from
-- @param element The element to search for
function table.remove_element(tbl, element)
    for k, v in pairs(tbl) do
        if v == element then
            remove(tbl, k)
            break
        end
    end
end

--- Removes an item from an array in O(1) time. Does not guarantee the order of elements.
-- @tparam table tbl The array to remove the element from
-- @tparam number index Must be >= 0. The case where index > #tbl is handled.
function table.remove_index(tbl, index)
    local count = #tbl
    if index > count then
        return
    end

    tbl[index] = tbl[count]
    tbl[count] = nil
end

--- Removes an item from an array in O(1) time. Does not guarantee the order of elements.
-- @tparam table tbl The array to remove the element from
-- @tparam number index Must be >= 0. The case where index > #tbl is handled.
table.fast_remove = table.remove_index

--- Return the key which holds this element element
-- @tparam table tbl The table to search
-- @param element The element to find
-- @return The key of the element or nil
function table.get_key(tbl, element)
    for k, v in pairs(tbl) do
        if v == element then
            return k
        end
    end
    return nil
end

--- Checks if the arrayed portion of a table contains an element
-- @tparam table tbl The table to search
-- @param element The element to find
-- @treturn ?number The index of the element or nil
function table.get_index(tbl, element)
    for i = 1, #tbl do
        if tbl[i] == element then
            return i
        end
    end
    return nil
end

--- Checks if a table contains an element
-- @tparam table tbl The table to search
-- @param e The element to find
-- @treturn boolean True if the element was found
function table.contains(tbl, element)
    return table.get_key(tbl, element) and true or false
end

--- Checks if the arrayed portion of a table contains an element
-- @tparam table tbl The table to search
-- @param e The element to find
-- @treturn boolean True if the element was found
function table.array_contains(tbl, element)
    return table.get_index(tbl, element) and true or false
end

--[[-- Extracts certain keys from a table, similar to deconstruction in other languages
@tparam table tbl table the which contains the keys
@tparam string ... the names of the keys you want extracted
@return the keys in the order given
@usage -- Deconstruction of a required module
local format_number, distance = table.deconstruct(require('util'), 'format_number', 'distance')
]]
function table.deconstruct(tbl, ...)
    local values = {}
    for _, key in pairs({...}) do
        table.insert(values, tbl[key])
    end
    return table.unpack(values)
end

--- Chooses a random entry from a table, can only be used during runtime
-- @tparam table tbl The table to select from
-- @tparam[opt=false] boolean key When true the key will be returned rather than the value
-- @return The selected element from the table
function table.get_random(tbl, key)
    local target_index = random(1, table_size(tbl))
    local count = 1
    for k, v in pairs(tbl) do
        if target_index == count then
            if key then
                return k
            else
                return v
            end
        end
        count = count + 1
    end
end

--- Chooses a random entry from a weighted table, can only be used during runtime
-- @tparam table weighted_table The table of items and their weights
-- @param[opt=1] item_key The index / key of items within each element
-- @param[opt=2] weight_key The index / key of the weights within each element
-- @return The selected element from the table
function table.get_random_weighted(weighted_table, item_key, weight_index)
    local total_weight = 0
    item_key = item_key or 1
    weight_index = weight_index or 2

    for _, w in pairs(weighted_table) do
        total_weight = total_weight + w[weight_index]
    end

    local index = random() * total_weight
    local weight_sum = 0
    for _, w in pairs(weighted_table) do
        weight_sum = weight_sum + w[weight_index]
        if weight_sum >= index then
            return w[item_key]
        end
    end
end

--- Clears all existing entries in a table
-- @tparam table tbl The table to clear
-- @tparam[opt=false] boolean array When true only the array portion of the table is cleared
function table.clear(t, array)
    if array then
        for i = 1, #t do
            t[i] = nil
        end
    else
        for i in pairs(t) do
            t[i] = nil
        end
    end
end

--- Creates a fisher-yates shuffle of a sequential number-indexed table
-- because this uses math.random, it cannot be used outside of events if no rng is supplied
-- from: http://www.sdknews.com/cross-platform/corona/tutorial-how-to-shuffle-table-items
-- @tparam table tbl The table to shuffle
-- @tparam[opt=math.random] function rng The function to provide random numbers
function table.shuffle(t, rng)
    local rand = rng or math.random
    local iterations = #t
    if iterations == 0 then
        error('Not a sequential table')
        return
    end
    local j

    for i = iterations, 2, -1 do
        j = rand(i)
        t[i], t[j] = t[j], t[i]
    end
end

--- Default table comparator sort function.
-- @local
-- @param x one comparator operand
-- @param y the other comparator operand
-- @return true if x logically comes before y in a list, false otherwise
local function sortFunc(x, y) --sorts tables with mixed index types.
    local tx = type(x)
    local ty = type(y)
    if tx == ty then
        if type(x) == 'string' then
            return string.lower(x) < string.lower(y)
        else
            return x < y
        end
    elseif tx == 'number' then
        return true --only x is a number and goes first
    else
        return false --only y is a number and goes first
    end
end

--- Returns a copy of all of the values in the table.
-- @tparam table tbl the to copy the keys from, or an empty table if tbl is nil
-- @tparam[opt] boolean sorted whether to sort the keys (slower) or keep the random order from pairs()
-- @tparam[opt] boolean as_string whether to try and parse the values as strings, or leave them as their existing type
-- @treturn array an array with a copy of all the values in the table
function table.get_values(tbl, sorted, as_string)
    if not tbl then return {} end
    local valueset = {}
    local n = 0
    if as_string then --checking as_string /before/ looping is faster
        for _, v in pairs(tbl) do
            n = n + 1
            valueset[n] = tostring(v)
        end
    else
        for _, v in pairs(tbl) do
            n = n + 1
            valueset[n] = v
        end
    end
    if sorted then
        table.sort(valueset, sortFunc)
    end
    return valueset
end

--- Returns a copy of all of the keys in the table.
-- @tparam table tbl the to copy the keys from, or an empty table if tbl is nil
-- @tparam[opt] boolean sorted whether to sort the keys (slower) or keep the random order from pairs()
-- @tparam[opt] boolean as_string whether to try and parse the keys as strings, or leave them as their existing type
-- @treturn array an array with a copy of all the keys in the table
function table.get_keys(tbl, sorted, as_string)
    if not tbl then return {} end
    local keyset = {}
    local n = 0
    if as_string then --checking as_string /before/ looping is faster
        for k, _ in pairs(tbl) do
            n = n + 1
            keyset[n] = tostring(k)
        end
    else
        for k, _ in pairs(tbl) do
            n = n + 1
            keyset[n] = k
        end
    end
    if sorted then
        table.sort(keyset, sortFunc)
    end
    return keyset
end

--- Returns the list is a sorted way that would be expected by people (this is by key)
-- @tparam table tbl the table to be sorted
-- @treturn table the sorted table
function table.alphanum_sort(tbl)
    local o = table.get_keys(tbl)
    local function padnum(d) local dec, n = string.match(d, "(%.?)0*(.+)")
        return #dec > 0 and ("%.12f"):format(d) or ("%s%03d%s"):format(dec, #n, n) end
    table.sort(o, function(a, b)
        return tostring(a):gsub("%.?%d+", padnum)..("%3d"):format(#b)
           < tostring(b):gsub("%.?%d+", padnum)..("%3d"):format(#a) end)
    local _tbl = {}
    for _, k in pairs(o) do _tbl[k] = tbl[k] end
    return _tbl
end

--- Returns the list is a sorted way that would be expected by people (this is by key) (faster alternative than above)
-- @tparam table tbl the table to be sorted
-- @treturn table the sorted table
function table.key_sort(tbl)
    local o = table.get_keys(tbl, true)
    local _tbl = {}
    for _, k in pairs(o) do _tbl[k] = tbl[k] end
    return _tbl
end

--[[
  Returns the index where t[index] == target.
  If there is no such index, returns a negative value such that bit32.bnot(value) is
  the index that the value should be inserted to keep the list ordered.
  t must be a list in ascending order for the return value to be valid.

  Usage example:
  local t = {1, 3,5, 7,9}
  local x = 5
  local index = table.binary_search(t, x)
  if index < 0 then
    game.print("value not found, smallest index where t[index] > x is: " .. bit32.bnot(index))
  else
    game.print("value found at index: " .. index)
  end
]]
function table.binary_search(t, target)
    --For some reason bit32.bnot doesn't return negative numbers so I'm using ~x = -1 - x instead.

    local lower = 1
    local upper = #t

    if upper == 0 then
        return -2 -- ~1
    end

    repeat
        local mid = floor((lower + upper) * 0.5)
        local value = t[mid]
        if value == target then
            return mid
        elseif value < target then
            lower = mid + 1
        else
            upper = mid - 1
        end
    until lower > upper

    return -1 - lower -- ~lower
end

-- add table-related functions that exist in base factorio/util to the 'table' table
require 'util'

--- Similar to serpent.block, returns a string with a pretty representation of a table.
-- Notice: This method is not appropriate for saving/restoring tables. It is meant to be used by the programmer mainly while debugging a program.
-- @tparam table root tTe table to serialize
-- @tparam table options Options are depth, newline, indent, process
-- depth sets the maximum depth that will be printed out. When the max depth is reached, inspect will stop parsing tables and just return {...}
-- process is a function which allow altering the passed object before transforming it into a string.
-- A typical way to use it would be to remove certain values so that they don't appear at all.
-- return <string> the prettied table
table.inspect = require 'modules.exp_util.include.inspect' --- @dep modules.exp_util.includes.inspect

--- Takes a table and returns the number of entries in the table. (Slower than #table, faster than iterating via pairs)
table.size = table_size

--- Creates a deepcopy of a table. Metatables and LuaObjects inside the table are shallow copies.
-- Shallow copies meaning it copies the reference to the object instead of the object itself.
-- @tparam table object The object to copy
-- @treturn table The copied object
table.deep_copy = table.deepcopy -- added by util

--- Merges multiple tables. Tables later in the list will overwrite entries from tables earlier in the list.
-- Ex. merge({{1, 2, 3}, {[2] = 0}, {[3] = 0}}) will return {1, 0, 0}
-- @tparam table tables A table of tables to merge
-- @treturn table The merged table
table.deep_merge = util.merge

--- Determines if two tables are structurally equal.
-- Notice: tables that are LuaObjects or contain LuaObjects won't be compared correctly, use == operator for LuaObjects
-- @tparam table tbl1 The first table
-- @tparam table tbl2 The second table
-- @treturn boolean True if the tables are equal
table.equals = table.compare -- added by util

return table
