# Contributing

All are welcome to make bug reports, feature requests, and pull requests for our scenario. We do not require you to have any coding knowledge to make bug reports and feature requests. If you have any questions ask us in our discord.

For developers wanting to add features please follow these guidelines:

- All lua code is documented using ldoc.
- Set the `CLUSTERIO` environment variable to your clusterio development install path, the lint needs it to resolve `modules/clusterio/*`.
- Lua is checked with [emmylua](https://github.com/EmmyLuaLs/emmylua-analyzer-rust), configured by `.emmyrc.json`. Install the EmmyLua extension rather than sumnekolua / luals, and use factoriomod-debug to generate the factorio api types. Note that an inline cast must be written `--[[@as T]]`, the spaced form is not parsed.
- Changes should be made on your own fork and merged into `main` through a pull request.
- Each pull request should be limited to one feature or a few bug fixes and link to the related issue page.
- Pull requests are automatically linted, then built and tested against the latest clusterio `master`.
- Pull requests are manually reviewed to maintain code and language quality.
- New features should have the branch names: `feature/feature-name`
- Bug fixes should have the branch names: `fix/bug-name`
- Commits should have meaningful messages.
