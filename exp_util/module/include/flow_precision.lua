--[[-- ExpUtil - Flow Precision
Simple lookup tables for working with flow precisions
]]

local fp = defines.flow_precision_index

--- @class ExpUtil_FlowPrecision
return {
    --- The defines index
    index = fp,
    --- The number of ticks represented by a precision index
    --- @type table<defines.flow_precision_index, number>
    ticks = {
        [fp.five_seconds] = 300,
        [fp.one_minute] = 3600,
        [fp.ten_minutes] = 36000,
        [fp.one_hour] = 216000,
        [fp.ten_hours] = 2160000,
        [fp.fifty_hours] = 10800000,
        [fp.two_hundred_fifty_hours] = 54000000,
        [fp.one_thousand_hours] = 216000000,
    },
    --- The next larger interval precision index
    --- @type table<defines.flow_precision_index, defines.flow_precision_index>
    next = {
        [fp.five_seconds] = fp.one_minute,
        [fp.one_minute] = fp.ten_minutes,
        [fp.ten_minutes] = fp.one_hour,
        [fp.one_hour] = fp.ten_hours,
        [fp.ten_hours] = fp.fifty_hours,
        [fp.fifty_hours] = fp.two_hundred_fifty_hours,
        [fp.two_hundred_fifty_hours] = fp.one_thousand_hours,
        [fp.one_thousand_hours] = fp.one_thousand_hours,
    },
    --- The previous smaller interval precision index
    --- @type table<defines.flow_precision_index, defines.flow_precision_index>
    prev = {
        [fp.five_seconds] = fp.five_seconds,
        [fp.one_minute] = fp.five_seconds,
        [fp.ten_minutes] = fp.one_minute,
        [fp.one_hour] = fp.ten_minutes,
        [fp.ten_hours] = fp.one_hour,
        [fp.fifty_hours] = fp.ten_hours,
        [fp.two_hundred_fifty_hours] = fp.fifty_hours,
        [fp.one_thousand_hours] = fp.two_hundred_fifty_hours,
    },
    --- The multiplicative increase to the next larger interval
    --- @type table<defines.flow_precision_index, number>
    next_change = {
        [fp.five_seconds] = 60,
        [fp.one_minute] = 10,
        [fp.ten_minutes] = 6,
        [fp.one_hour] = 10,
        [fp.ten_hours] = 5,
        [fp.fifty_hours] = 5,
        [fp.two_hundred_fifty_hours] = 4,
        [fp.one_thousand_hours] = 1,
    },
    --- The multiplicative decrease to the previous smaller interval
    --- @type table<defines.flow_precision_index, number>
    prev_change = {
        [fp.five_seconds] = 1,
        [fp.one_minute] = 60,
        [fp.ten_minutes] = 10,
        [fp.one_hour] = 6,
        [fp.ten_hours] = 10,
        [fp.fifty_hours] = 5,
        [fp.two_hundred_fifty_hours] = 5,
        [fp.one_thousand_hours] = 4,
    },
}
