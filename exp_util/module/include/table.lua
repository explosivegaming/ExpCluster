--- @diagnostic disable: duplicate-set-field
-- luacheck:ignore global table

local random = math.random
local floor = math.floor
local remove = table.remove
local unpack = table.unpack
local tonumber = tonumber
local pairs = pairs
local table_size = table_size

--- Adds all keys of the source table to destination table as a shallow copy
--- @generic K, V
--- @param dst table<K, V> Table to insert into
--- @param src table<K, V> Table to insert from
--- @return table<K, V> # Table that was passed as the first argument
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

    return dst
end

--- Much faster method for inserting items into an array
--- @generic V
--- @param dst V[] Array that will have the values added to it
--- @param start_index number|table|nil Index at which values will be added, nil means end of the array
--- @param src V[]? Array of values that will be added
--- @return V[] # Array that was passed as the first argument
function table.insert_array(dst, start_index, src)
    if not src then
        assert(type(start_index) == "table")
        src = start_index
        start_index = nil
    end

    if start_index then
        local starting_length = #dst
        local adding_length = #src
        local move_to = start_index + adding_length + 1
        for offset = starting_length - start_index, 0, -1 do
            dst[move_to + offset] = dst[starting_length + offset]
        end

        start_index = start_index - 1
    else
        start_index = #dst
    end

    for offset, item in ipairs(src) do
        dst[start_index + offset] = item
    end

    return dst
end

--- Much faster method for inserting keys into a table
--- @generic K, V
--- @param dst table<K, V> Table that will have keys added to it
--- @param start_index number|table|nil Index at which values will be added, nil means end of the array, numbered indexes only
--- @param src table<K, V> ? Table that may contain both string and numbered keys
--- @return table<K, V>  # Table passed as the first argument
function table.insert_table(dst, start_index, src)
    if not src then
        assert(type(start_index) == "table")
        src = start_index
        start_index = nil
    end

    table.insert_array(dst, start_index, src)
    for key, value in pairs(src) do
        if not tonumber(key) then
            dst[key] = value
        end
    end

    return dst
end

--- Searches a table to remove a specific element without an index
--- @generic V
--- @param tbl table<any, V> Table to remove the element from
--- @param element V Element to remove
function table.remove_element(tbl, element)
    for k, v in pairs(tbl) do
        if v == element then
            remove(tbl, k)
            break
        end
    end
end

--- Removes an item from an array in O(1) time. Does not guarantee the order of elements.
--- @generic V
--- @param tbl V[] Array to remove the element from
--- @param index number Must be >= 0. The case where index > #tbl is handled.
--- @return V? # Element which was removed or nil
function table.remove_index(tbl, index)
    local count = #tbl
    if index > count then
        return
    end

    local rtn = tbl[count]
    tbl[index] = tbl[count]
    tbl[count] = nil
    return rtn
end

--- Return the key which holds this element element
--- @generic K, V
--- @param tbl table<K, V> Table to search
--- @param element V Element to find
--- @return K? # Key of the element or nil
function table.get_key(tbl, element)
    for k, v in pairs(tbl) do
        if v == element then
            return k
        end
    end

    return nil
end

--- Checks if the arrayed portion of a table contains an element
--- @generic V
--- @param tbl V[] Table to search
--- @param element V Element to find
--- @return number? # Index of the element or nil
function table.get_index(tbl, element)
    for i = 1, #tbl do
        if tbl[i] == element then
            return i
        end
    end

    return nil
end

--- Checks if a table contains an element
--- @generic V
--- @param tbl table<any, V> Table to search
--- @param element V Element to find
--- @return boolean # True if the element was found
function table.contains(tbl, element)
    return table.get_key(tbl, element) and true or false
end

--- Checks if the arrayed portion of a table contains an element
--- @generic V
--- @param tbl V[] Table to search
--- @param element V Element to find
--- @return boolean # True if the element was found
function table.array_contains(tbl, element)
    return table.get_index(tbl, element) and true or false
end

--- Extracts certain keys from a table, similar to deconstruction in other languages
--- @generic K, V
--- @param tbl table<K, V> Table the which contains the keys
--- @param ... K Keys to extracted
--- @return V ... Values in the order given
function table.deconstruct(tbl, ...)
    local values = {}
    for index, key in pairs{ ... } do
        values[index] = tbl[key]
    end

    return unpack(values)
end

--- Chooses a random entry from a table, can only be used during runtime
--- @generic K, V
--- @param tbl table<K, V> Table to select from
--- @param rtn_key boolean? True when the key will be returned rather than the value
--- @return K | V # Selected element from the table
function table.get_random(tbl, rtn_key)
    local target_index = random(1, table_size(tbl))
    local count = 1
    for k, v in pairs(tbl) do
        if target_index == count then
            if rtn_key then
                return k
            else
                return v
            end
        end
        count = count + 1
    end
    error("Unreachable")
end

--- Chooses a random entry from a weighted table, can only be used during runtime
--- @generic V, VK, WK
--- @param weighted_table table<any, { [VK]: V, [WK]: number }> Table of items and their weights
--- @param value_key VK? Index / key of value to within each element
--- @param weight_index WK? Index / key of the weights within each element
--- @return V # Selected element from the table
function table.get_random_weighted(weighted_table, value_key, weight_index)
    local total_weight = 0
    value_key = value_key or 1
    weight_index = weight_index or 2

    for _, w in pairs(weighted_table) do
        total_weight = total_weight + w[weight_index]
    end

    local index = random() * total_weight
    local weight_sum = 0
    for _, w in pairs(weighted_table) do
        weight_sum = weight_sum + w[weight_index]
        if weight_sum >= index then
            return w[value_key]
        end
    end
    error("Unreachable")
end

--- Clears all existing entries in a table
--- @param tbl table Table to clear
--- @param array boolean? True when only the array portion of the table is cleared
function table.clear(tbl, array)
    if array then
        for i = 1, #tbl do
            tbl[i] = nil
        end
    else
        for i in pairs(tbl) do
            tbl[i] = nil
        end
    end
end

--- Creates a fisher-yates shuffle of a sequential number-indexed table
-- because this uses math.random, it cannot be used outside of events if no rng is supplied
-- from: http://www.sdknews.com/cross-platform/corona/tutorial-how-to-shuffle-table-items
--- @generic K
--- @param tbl table<K, any> Table to shuffle
--- @param rng fun(iter: number): K Function to provide random numbers
function table.shuffle(tbl, rng)
    local rand = rng or math.random
    local iterations = assert(#tbl > 0, "Not a sequential table")
    local j
    for i = iterations, 2, -1 do
        j = rand(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

--- Default table comparator sort function.
--- @param lhs any LHS comparator operand
--- @param rhs any RHS comparator operand
--- @return boolean True if lhs logically comes before rhs in a list, false otherwise
local function sort_func(lhs, rhs) -- sorts tables with mixed index types.
    local tx = type(lhs)
    local ty = type(rhs)
    if tx == ty then
        if type(lhs) == "string" then
            return string.lower(lhs) < string.lower(rhs)
        else
            return lhs < rhs
        end
    elseif tx == "number" then
        return true -- only x is a number and goes first
    else
        return false -- only y is a number and goes first
    end
end

--- Returns a copy of all of the values in the table.
--- @generic V
--- @param tbl table<any, V> Table to copy the values from, or an empty table if tbl is nil
--- @param sorted boolean? True to sort the keys (slower) or keep the random order from pairs()
--- @param as_string boolean? True to try and parse the values as strings, or leave them as their existing type
--- @return V[] # Array with a copy of all the values in the table
function table.get_values(tbl, sorted, as_string)
    if not tbl then return {} end
    local value_set = {}
    local n = 0
    if as_string then -- checking as_string before looping is faster
        for _, v in pairs(tbl) do
            n = n + 1
            value_set[n] = tostring(v)
        end
    else
        for _, v in pairs(tbl) do
            n = n + 1
            value_set[n] = v
        end
    end
    if sorted then
        table.sort(value_set, sort_func)
    end
    return value_set
end

--- Returns a copy of all of the keys in the table.
--- @generic K
--- @param tbl table<K, any> Table to copy the keys from, or an empty table if tbl is nil
--- @param sorted boolean? True to sort the keys (slower) or keep the random order from pairs()
--- @param as_string boolean? True to try and parse the keys as strings, or leave them as their existing type
--- @return K[] # Array with a copy of all the keys in the table
function table.get_keys(tbl, sorted, as_string)
    if not tbl then return {} end
    local key_set = {}
    local n = 0
    if as_string then -- checking as_string /before/ looping is faster
        for k, _ in pairs(tbl) do
            n = n + 1
            key_set[n] = tostring(k)
        end
    else
        for k, _ in pairs(tbl) do
            n = n + 1
            key_set[n] = k
        end
    end
    if sorted then
        table.sort(key_set, sort_func)
    end
    return key_set
end

--- Returns the list is a sorted way that would be expected by people (this is by key)
--- @generic K, V
--- @param tbl table<K, V> Table to be sorted
--- @return table<K, V> # Sorted table
function table.alphanum_sort(tbl)
    local o = table.get_keys(tbl)
    local function padnum(d)
        local dec, n = string.match(d, "(%.?)0*(.+)")
        return #dec > 0 and ("%.12f"):format(d) or ("%s%03d%s"):format(dec, #n, n)
    end

    table.sort(o, function(a, b)
        return tostring(a):gsub("%.?%d+", padnum) .. ("%3d"):format(#b)
            < tostring(b):gsub("%.?%d+", padnum) .. ("%3d"):format(#a)
    end)

    local _tbl = {}
    for _, k in pairs(o) do _tbl[k] = tbl[k] end
    return _tbl
end

--- Returns the list is a sorted way that would be expected by people (this is by key) (faster alternative than above)
--- @generic K, V
--- @param tbl table<K, V> Table to be sorted
--- @return table<K, V> # Sorted table
function table.key_sort(tbl)
    local o = table.get_keys(tbl, true)
    local _tbl = {}
    for _, k in pairs(o) do _tbl[k] = tbl[k] end
    return _tbl
end

--- Returns the index where t[index] == target.
-- If there is no such index, returns a negative value such that bit32.bnot(value) is
-- the index that the value should be inserted to keep the list ordered.
-- It must be a list in ascending order for the return value to be valid.
--- @generic V
--- @param tbl V[] Array to search
--- @param target V Target to find
--- @return number # Index the value was at
function table.binary_search(tbl, target)
    -- For some reason bit32.bnot doesn't return negative numbers so I'm using ~x = -1 - x instead.
    local lower = 1
    local upper = #tbl

    if upper == 0 then
        return -2 -- ~1
    end

    repeat
        local mid = floor((lower + upper) * 0.5)
        local value = tbl[mid]
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

-- Add table-related functions that exist in base factorio/util to the 'table' table
require "util"

--- Similar to serpent.block, returns a string with a pretty representation of a table.
-- Notice: This method is not appropriate for saving/restoring tables. It is meant to be used by the programmer mainly while debugging a program.
table.inspect = require("modules/exp_util/include/inspect").inspect

--- Takes a table and returns the number of entries in the table. (Slower than #table, faster than iterating via pairs)
table.size = table_size

--- Creates a deepcopy of a table. Metatables and LuaObjects inside the table are shallow copies.
-- Shallow copies meaning it copies the reference to the object instead of the object itself.
table.deep_copy = table.deepcopy -- added by util

--- Merges multiple tables. Tables later in the list will overwrite entries from tables earlier in the list.
-- Ex. merge({{1, 2, 3}, {[2] = 0}, {[3] = 0}}) will return {1, 0, 0}
table.deep_merge = util.merge

--- Determines if two tables are structurally equal.
table.equals = table.compare -- added by util

return table
