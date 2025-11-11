return {
    inventories = {
        {
            inventory = defines.inventory.character_ammo,
            event = defines.events.on_player_ammo_inventory_changed,
            items = {
                ["atomic-bomb"] = true,
            },
        },
        {
            inventory = defines.inventory.character_armor,
            event = defines.events.on_player_armor_inventory_changed,
            items = {},
        },
        {
            inventory = defines.inventory.character_guns,
            event = defines.events.on_player_gun_inventory_changed,
            items = {},
        },
        {
            inventory = defines.inventory.character_main,
            event = defines.events.on_player_main_inventory_changed,
            items = {
                ["atomic-bomb"] = true,
            },
        },
    },
    ignore_permission = "bypass-nukeprotect", -- @setting ignore_permission The permission that nukeprotect will ignore
    ignore_admins = true, -- @setting ignore_admins Ignore admins, true by default. Allows usage outside of the roles module
}
