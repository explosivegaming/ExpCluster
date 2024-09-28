--- Preset colours that players get when they join the server, if not in the list then will be given a random colour (which isnt disallowed)
-- @config Preset-Player-Colours

return {
    players = { --- @setting players list of all players and the colour in rgb256 that they will recive upon joining
        PHIDIAS0303 = { r = 255, g = 255, b = 255 },
        BADgamerNL = { r = 255, g = 20, b = 147 },
        arty714 = { r = 150, g = 68, b = 161 },
        Cooldude2606 = { r = 57, g = 192, b = 207 },
        mark9064 = { r = 99, g = 0, b = 255 },
        eissturm = { r = 25, g = 25, b = 112 },
        Sakama = { r = 20, g = 213, b = 80 },
        freek18 = { r = 50, g = 0, b = 255 },
        aldldl = { r = 0, g = 131, b = 255 },
        NAD4X4 = { r = 135, g = 206, b = 250 },
        cydes = { r = 82, g = 249, b = 155 },
        UUBlueFire = { r = 0, g = 204, b = 255 },
        CmonMate497 = { r = 103, g = 224, b = 194 },
        s4sh = { r = 255, g = 120, b = 0 },
        ArPiiX = { r = 0, g = 255, b = 0 },
        NextIdea = { r = 255, g = 255, b = 255 },
        hamsterbryan = { r = 0, g = 255, b = 0 },
        XenoCyber = { r = 0, g = 128, b = 255 },
    },
    disallow = { --- @setting disallow colours which will not given to players; the value does not matter it is only the key which is checked
        black = { r = 0, g = 0, b = 0 },
        white = { r = 255, g = 255, b = 255 },
        success = { r = 0, g = 255, b = 0 },
        warning = { r = 255, g = 255, b = 0 },
        fail = { r = 255, g = 0, b = 0 },
        info = { r = 255, g = 255, b = 255 },
    },
}
