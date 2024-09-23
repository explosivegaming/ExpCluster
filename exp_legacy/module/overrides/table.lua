--luacheck:ignore global table
local random = math.random
local floor = math.floor
local remove = table.remove
local tonumber = tonumber
local pairs = pairs
local table_size = table_size

--- Searches a table to remove a specific element without an index
-- @param t <table> to search
-- @param <any> table element to search for
function table.remove_element(t, element)
    for k, v in pairs(t) do
        if v == element then
            remove(t, k)
            break
        end
    end
end

--- Removes an item from an array in O(1) time.
-- The catch is that fast_remove doesn't guarantee to maintain the order of items in the array.
-- @param tbl <table> arrayed table
-- @param index <number> Must be >= 0. The case where index > #tbl is handled.
function table.remove_index(tbl, index)
    local count = #tbl
    if index > count then
        return
    elseif index < count then
        tbl[index] = tbl[count]
    end

    tbl[count] = nil
end

--- Adds the contents of table t2 to table t1
-- @param t1 <table> to insert into
-- @param t2 <table> to insert from
function table.merge_table(t1, t2)
    for k, v in pairs(t2) do
        if tonumber(k) then
            t1[#t1 + 1] = v
        else
            t1[k] = v
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

--- Checks if a table contains an element
-- @param t <table>
-- @param e <any> table element
-- @return <any> the index of the element or nil
function table.get_key(t, e)
    for k, v in pairs(t) do
        if v == e then
            return k
        end
    end
    return nil
end

--- Checks if the arrayed portion of a table contains an element
-- @param t <table>
-- @param e <any> table element
-- @return <number|nil> the index of the element or nil
function table.get_index(t, e)
    for i = 1, #t do
        if t[i] == e then
            return i
        end
    end
    return nil
end

--- Checks if a table contains an element
-- @param t <table>
-- @param e <any> table element
-- @return <boolean> indicating success
function table.contains(t, e)
    return table.get_key(t, e) and true or false
end

--- Checks if the arrayed portion of a table contains an element
-- @param t <table>
-- @param e <any> table element
-- @return <boolean> indicating success
function table.array_contains(t, e)
    return table.get_index(t, e) and true or false
end

--- Extracts certain keys from a table
-- @usage local key_three, key_one = extract({key_one='foo', key_two='bar', key_three=true}, 'key_three', 'key_one')
-- @tparam table tbl table the which contains the keys
-- @tparam string ... the names of the keys you want extracted
-- @return the keys in the order given
function table.extract_keys(tbl, ...)
    local values = {}
    for _, key in pairs({...}) do
        table.insert(values, tbl[key])
    end
    return table.unpack(values)
end

--- Adds an element into a specific index position while shuffling the rest down
-- @param t <table> to add into
-- @param index <number> the position in the table to add to
-- @param element <any> to add to the table
function table.set(t, index, element)
    local i = 1
    for k in pairs(t) do
        if i == index then
            t[k] = element
            return nil
        end
        i = i + 1
    end
    error('Index out of bounds', 2)
end

--- Chooses a random entry from a table
-- because this uses math.random, it cannot be used outside of events
-- @param t <table>
-- @param key <boolean> to indicate whether to return the key or value
-- @return <any> a random element of table t
function table.get_random_dictionary_entry(t, key)
    local target_index = random(1, table_size(t))
    local count = 1
    for k, v in pairs(t) do
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

--- Chooses a random entry from a weighted table
-- because this uses math.random, it cannot be used outside of events
-- @param weighted_table <table> of tables with items and their weights
-- @param item_index <number> of the index of items, defaults to 1
-- @param weight_index <number> of the index of the weights, defaults to 2
-- @return <any> table element
function table.get_random_weighted(weighted_table, item_index, weight_index)
    local total_weight = 0
    item_index = item_index or 1
    weight_index = weight_index or 2

    for _, w in pairs(weighted_table) do
        total_weight = total_weight + w[weight_index]
    end

    local index = random() * total_weight
    local weight_sum = 0
    for _, w in pairs(weighted_table) do
        weight_sum = weight_sum + w[weight_index]
        if weight_sum >= index then
            return w[item_index]
        end
    end
end

--- Clears all existing entries in a table
-- @param t <table> to clear
-- @param array <boolean> to indicate whether the table is an array or not
function table.clear_table(t, array)
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
-- @param t <table> to shuffle
-- @param rng <function> to provide random numbers
function table.shuffle_table(t, rng)
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
function table.alphanumsort(tbl)
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
function table.keysort(tbl)
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
-- @param table <table> the table to serialize
-- @param options <table> options are depth, newline, indent, process
-- depth sets the maximum depth that will be printed out. When the max depth is reached, inspect will stop parsing tables and just return {...}
-- process is a function which allow altering the passed object before transforming it into a string.
-- A typical way to use it would be to remove certain values so that they don't appear at all.
-- return <string> the prettied table
table.inspect = require 'overrides.inspect' --- @dep overrides.inspect

--- Takes a table and returns the number of entries in the table. (Slower than #table, faster than iterating via pairs)
table.size = table_size

--- Creates a deepcopy of a table. Metatables and LuaObjects inside the table are shallow copies.
-- Shallow copies meaning it copies the reference to the object instead of the object itself.
-- @param object <table> the object to copy
-- @return <table> the copied object
table.deep_copy = table.deepcopy

--- Merges multiple tables. Tables later in the list will overwrite entries from tables earlier in the list.
-- Ex. merge({{1, 2, 3}, {[2] = 0}, {[3] = 0}}) will return {1, 0, 0}
-- @param tables <table> takes a table of tables to merge
-- @return <table> a merged table
table.merge = util.merge

--- Determines if two tables are structurally equal.
-- Notice: tables that are LuaObjects or contain LuaObjects won't be compared correctly, use == operator for LuaObjects
-- @param tbl1 <table>
-- @param tbl2 <table>
-- @return <boolean>
table.equals = table.compare

return table