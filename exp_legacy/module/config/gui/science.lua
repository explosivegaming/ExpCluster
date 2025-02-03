--- Config file for the science info gui
-- @config Science

return {
    -- list of all science packs to be shown in the gui
    show_eta = true, --- @setting show_eta when true the eta for research completion will be shown
    color_cutoff = 0.8, --- @setting color_cutoff the amount that production can fall before the text changes color
    color_flux = 0.1, --- @setting color_flux the amount of fluctuation allowed in production before the icon changes color
    "automation-science-pack",
    "logistic-science-pack",
    "military-science-pack",
    "chemical-science-pack",
    "production-science-pack",
    "utility-science-pack",
    "space-science-pack",
    "metallurgic-science-pack",
    "agricultural-science-pack",
    "electromagnetic-science-pack",
    "cryogenic-science-pack",
    "promethium-science-pack",
}
