--- This controls how pollution is viewed on the map
-- @config Pollution-Grading

return {
    reference_point = { x = 0, y = 0 }, --- @setting reference_point where pollution is read from
    max_scalar = 0.5, --- @setting max_scalar the scale between true max and max
    min_scalar = 0.17, --- @setting min_scalar the scale between the lowest max and min
    update_delay = 15, --- @setting update_delay time in minutes between view updates
}
