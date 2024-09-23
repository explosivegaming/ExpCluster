return {
    -- type of machine to handle together
    default_module_row_count = 9,
    module_slot_max = 4,
    copy_paste_module = true,
    copy_paste_rotation = false,
    machine = {
        ['electric-mining-drill'] = {
            ['module'] = 'effectivity-module',
            ['prod'] = true
        },
        ['pumpjack'] = {
            ['module'] = 'effectivity-module',
            ['prod'] = true
        },
        ['assembling-machine-2'] = {
            ['module'] = 'productivity-module',
            ['prod'] = true
        },
        ['assembling-machine-3'] = {
            ['module'] = 'productivity-module-3',
            ['prod'] = true
        },
        ['electric-furnace'] = {
            ['module'] = 'productivity-module-3',
            ['prod'] = true
        },
        ['beacon'] = {
            ['module'] = 'speed-module-3',
            ['prod'] = false
        },
        ['oil-refinery'] = {
            ['module'] = 'productivity-module-3',
            ['prod'] = true
        },
        ['chemical-plant'] = {
            ['module'] = 'productivity-module-3',
            ['prod'] = true
        },
        ['centrifuge'] = {
            ['module'] = 'productivity-module-3',
            ['prod'] = true
        },
        ['lab'] = {
            ['module'] = 'productivity-module-3',
            ['prod'] = true
        },
        ['rocket-silo'] = {
            ['module'] = 'productivity-module-3',
            ['prod'] = true
        }
    },
    module_allowed = {
        ['advanced-circuit'] = true,
        ['automation-science-pack'] = true,
        ['battery'] = true,
        ['chemical-science-pack'] = true,
        ['copper-cable'] = true,
        ['copper-plate'] = true,
        ['electric-engine-unit'] = true,
        ['electronic-circuit'] = true,
        ['empty-barrel'] = true,
        ['engine-unit'] = true,
        ['explosives'] = true,
        ['flying-robot-frame'] = true,
        ['iron-gear-wheel'] = true,
        ['iron-plate'] = true,
        ['iron-stick'] = true,
        ['logistic-science-pack'] = true,
        ['low-density-structure'] = true,
        ['lubricant'] = true,
        ['military-science-pack'] = true,
        ['nuclear-fuel'] = true,
        ['plastic-bar'] = true,
        ['processing-unit'] = true,
        ['production-science-pack'] = true,
        ['rocket-control-unit'] = true,
        ['rocket-fuel'] = true,
        ['rocket-part'] = true,
        ['steel-plate'] = true,
        ['stone-brick'] = true,
        ['sulfur'] = true,
        ['sulfuric-acid'] = true,
        ['uranium-fuel-cell'] = true,
        ['utility-science-pack'] = true,
        ['basic-oil-processing'] = true,
        ['advanced-oil-processing'] = true,
        ['coal-liquefaction'] = true,
        ['heavy-oil-cracking'] = true,
        ['light-oil-cracking'] = true,
        ['solid-fuel-from-light-oil'] = true,
        ['solid-fuel-from-petroleum-gas'] = true,
        ['solid-fuel-from-heavy-oil'] = true,
        ['uranium-processing'] = true,
        ['nuclear-fuel-reprocessing'] = true,
        ['kovarex-enrichment-process'] = true
    }
}
