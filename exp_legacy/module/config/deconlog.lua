--- This config controls whether actions such as deconning by players without sufficient permissions is logged or not
-- @config Deconlog

return {
    decon_area = true, --- @setting decon_area whether to log when an area is being deconstructed
    built_entity = true, --- @setting built_entity whether to log when an entity is built
    mined_entity = true, --- @setting mined_entity whether to log when an entity is mined
    fired_rocket = true, --- @setting fired_nuke whether to log when a rocket is fired
    fired_explosive_rocket = true, --- @setting fired_nuke whether to log when a explosive rocket is fired
    fired_nuke = true, --- @setting fired_nuke whether to log when a nuke is fired
}
