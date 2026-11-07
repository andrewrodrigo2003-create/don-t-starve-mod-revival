# Artwork provenance and cover replacement

## Original cover artwork draft

- Source: `dst-mods/metals_and_reforged/images/branding/metals_and_more_reforged_cover.svg`
- Created specifically for Metals and More Reforged.
- The composition is an original vector illustration: forge, anvil, hammer, ore and refined ingots.
- It does not reuse the previous `modicon.tex` image or trace the original creator's cover.
- No Don't Starve character artwork, logos, textures, or extracted game assets are included in this SVG.
- A 1200×675 PNG export is supplied separately as the workshop/banner image; the SVG remains the editable source.

## Important technical status

This SVG is a source artwork for a workshop/banner cover. It is **not yet the in-game mod icon**. The current `modinfo.lua` points to `modicon.xml` and `modicon.tex`; DST expects Klei texture assets for that path. Do not point `icon` at this SVG or rename it to `.tex`.

For the in-game icon, create a separate square icon composition (for example, 512×512 PNG), then convert it to KTEX. The open-source [ktools project](https://github.com/nsimplex/ktools) documents its `ktech` utility for bidirectional PNG/KTEX conversion. Example after installing a verified build:

```powershell
ktech .\modicon.png .\modicon.tex
```

The new square texture needs a matching atlas entry in `modicon.xml` (full-image UVs if it contains only one icon). Validate the generated texture in DST before changing the live `modinfo.lua` reference. Do not use the 1200×675 workshop banner as a direct substitute for a square icon.

## Authorship and provenance

The art replacement does not change the provenance of the inherited mod code. The legacy `modinfo.lua` credits NevilleDST. The reworked Workshop page itself identifies the project as a rework of the earlier **Metals and More!** by Benzoquinone (Workshop item 1861463010), while the reworked page is item 2792388184 by NevilleDST. Preserve this upstream chain in project documentation and public credits unless a documented license or permission authorizes a different treatment. Do not imply that a new cover makes inherited code wholly original or guarantees immunity from a copyright claim.

Both Workshop pages currently display Steam's notice that the items were removed for violating Community & Content Guidelines. That notice does **not** establish that either author filed a copyright complaint, and we should not guess why Steam removed them. It does mean the repository should not treat either mod as freely reusable without checking the original permissions.

Klei's [modding guidance](https://support.klei.com/hc/en-us/articles/360029555992-Modding-Don-t-Starve-and-Don-t-Starve-Together) says that work from others must be used with credited permission and that absent explicit permission is treated as no permission. Before publicly redistributing inherited code/assets, confirm the original mod's license or obtain permission if needed.

The project should keep a clear changelog distinguishing newly created artwork, inherited code, and independently implemented changes.
