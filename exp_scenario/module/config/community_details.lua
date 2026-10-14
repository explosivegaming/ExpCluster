--- Names and links of the community, shown in chat, the readme, and the greeting
-- @config Community-Details

local Feature = require("modules/exp_scenario/features")

--- The values are always used, disabling the feature changes nothing
return Feature.register("community_details", {
    community_name = "Explosive Gaming",
    discord = "https://discord.explosivegaming.nl",
    website = "https://www.explosivegaming.nl",
    status = "https://status.explosivegaming.nl",
    github = "https://github.com/explosivegaming/ExpCluster",
    patreon = "https://www.patreon.com/ExpGaming",
})
