return {
    ignore_admins = true, --- @setting ignore_admins If admins are ignored by the protection filter
    ignore_permission = 'bypass-entity-protection', --- @setting ignore_permission Players with this permission will be ignored by the protection filter, leave nil if expcore.roles is not used
    repeat_count = 5, --- @setting repeat_count Number of protected entities that must be removed within repeat_lifetime in order to trigger repeated removal protection
    repeat_lifetime = 3600*20, --- @setting repeat_lifetime The length of time, in ticks, that protected removals will be remembered for
    refresh_rate = 3600*5, --- @setting refresh_rate How often the age of protected removals are checked against repeat_lifetime
    always_protected_names = { --- @setting always_protected_names Names of entities which are always protected

    },
    always_protected_types = { --- @setting always_protected_types Types of entities which are always protected
        'boiler', 'generator', 'offshore-pump', 'power-switch', 'reactor', 'rocket-silo'
    },
    always_trigger_repeat_names = { --- @setting always_trigger_repeat_names Names of entities which always trigger repeated removal protection

    },
    always_trigger_repeat_types = { --- @setting always_trigger_repeat_types Types of entities which always trigger repeated removal protection
        'reactor', 'rocket-silo'
    }
}