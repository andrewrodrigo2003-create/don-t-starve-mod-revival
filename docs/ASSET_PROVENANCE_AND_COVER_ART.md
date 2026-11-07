# Artwork provenance and cover replacement

## Original cover artwork draft

- Source: `dst-mods/metals_and_reforged/images/branding/metals_and_more_reforged_cover.svg`
- Created specifically for Metals and More Reforged.
- The composition is an original vector illustration: forge, anvil, hammer, ore and refined ingots.
- It does not reuse the previous `modicon.tex` image or trace the original creator's cover.
- No Don't Starve character artwork, logos, textures, or extracted game assets are included in this SVG.

## Important technical status

This SVG is a source artwork draft for a workshop/banner cover. It is **not yet the in-game mod icon**. The current `modinfo.lua` points to `modicon.xml` and `modicon.tex`; DST expects Klei texture assets for that path. Do not point `icon` at this SVG or rename it to `.tex`.

Before replacing the in-game icon:
1. Export a correctly sized PNG from this SVG.
2. Convert it to Klei's texture/atlas format with the official or verified Klei texture tools.
3. Update the atlas XML only after validating the generated texture in-game.
4. Keep the original texture available in Git history; do not delete history.

## Authorship and provenance

The art replacement does not change the provenance of the inherited mod code. The current legacy `modinfo.lua` credits NevilleDST. Preserve appropriate credit for inherited code and assets unless a documented license or permission authorizes a different treatment. Do not imply that a new cover makes inherited code wholly original or guarantees immunity from a copyright claim.

The project should keep a clear changelog distinguishing newly created artwork, inherited code, and independently implemented changes.
