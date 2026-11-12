# Metals and More Reforged 2.9.6 — consolidated in-game test

**Build:** 2.9.6 integrated test build  
**Target:** Don't Starve Together, dedicated test world `mundo de testes de mod`  
**Uncompromising Mode:** Public Beta 6.0.3.9 (`utw-beta`)  
**Important:** CI/static checks are not a substitute for an in-game multiplayer test.

## 1. Install and load
- [ ] Disable the old Workshop copy so two copies do not load at once.
- [ ] Install the ZIP from the GitHub Actions artifact.
- [ ] Confirm the mod version is 2.9.6.
- [ ] Start a fresh test world and confirm client/server logs contain no MAM Lua errors.
- [ ] Load an older save that already contains the retired metal chest; confirm it remains loadable. New worlds must not offer a recipe for that chest.

## 2. War Bench crafting matrix
- [ ] Confirm the War Bench can be crafted using the Science Two progression.
- [ ] Confirm golden tools, compass, razor, lightning rod, birdcage, dragonfly chest, marble/dragonfly/ruins armor, multitool axe-pickaxe, weather devices, portable cooking equipment, glasscutter, archive resonator, moondial, moonrock crater and moonglass axe appear in the War Bench filter.
- [ ] Confirm each recipe remains an individual recipe and keeps its live ingredient costs.
- [ ] Confirm researchlab, researchlab2 and transistor remain on the science progression.
- [ ] Confirm forge weapons and the existing MAM equipment recipes still appear at the War Bench.
- [ ] Test with another recipe-changing mod enabled; verify MAM does not replace the other mod's ingredient list.

## 3. Metallurgy reference book
- [ ] Craft the Metallurgy Guide at the War Bench.
- [ ] Read it using the normal book action.
- [ ] Test previous/next page, close button and controller back.
- [ ] Confirm the guide displays the active smelting product list, ingredient tags, base times, material chain, mining/source notes, station progression, salvage and robot automation.
- [ ] Confirm reading the guide does not unlock or remotely craft recipes.

## 4. Deconstruction and salvage
- [ ] Confirm the dismantle action appears only when right-clicking supported metal materials/equipment near the War Bench.
- [ ] Confirm it does not appear away from the War Bench.
- [ ] Standard characters: test multiple samples; expected recovery is 75% per ingredient unit on average, not a guaranteed 75% from each single item.
- [ ] Wilson: verify 100% recovery of listed ingredients.
- [ ] Winona: verify 100% recovery of non-magical metal components; other recipe ingredients remain at the standard rate.
- [ ] Maxwell: verify 100% recovery of shadow components (e.g. nightmare fuel); other ingredients remain at the standard rate.
- [ ] WX-78 and Wickerbottom use the standard rate in this build.
- [ ] Dismantle damaged equipment at different durability levels; confirm returned components scale with remaining durability.
- [ ] Fill inventory and backpack; confirm the action refuses before consuming the input when output capacity is insufficient.
- [ ] Confirm a zero-recovery roll still consumes the dismantled item; repeated clicking must not reroll the same item.
- [ ] Confirm the returned materials match the live recipe for crafted equipment.
- [ ] Wilson's separate cross-material transmutation is not in this build; this test covers exact ingredient recovery only.

## 5. Collector robot forge automation
- [ ] Confirm the option **Collector robot forge automation** defaults Off.
- [ ] With Off, confirm nearby robots do not pull ingredients or deposit output automatically.
- [ ] Turn it On. With a fueled active W.O.B.O.T. nearby, place registered smelting ingredients in a normal compatible chest.
- [ ] Confirm the smelter pulls only the exact ingredients selected by the normal batch planner.
- [ ] Confirm leftover ingredients remain in the source chest.
- [ ] Confirm the smelter processes the planned batch without rolling a different product after transfer.
- [ ] Confirm completed output is deposited into the nearest compatible chest/pack with enough capacity.
- [ ] Fill nearby storage; confirm the finished product remains ready in the smelter for manual collection.
- [ ] Repeat with a deployed, fueled, active W.I.N.bot.
- [ ] Confirm player inventories and portable storage are never scanned or drained.
- [ ] Test a compatible external storage mod and a container that rejects the output.

## 6. Forge reliability
- [ ] Test single and batch smelting with each registered metal family.
- [ ] Compare preview name, image and quantity with the actual result.
- [ ] Interrupt a batch, hammer the forge and test pending refunds.
- [ ] Save/reload while idle, processing, refund-pending and ready-to-harvest.
- [ ] Confirm no missing or duplicated ingredients/products.
- [ ] Test full output inventory and retry behavior.

## 7. Uncompromising Mode Public Beta 6.0.3.9
- [ ] Enable UM Beta branch `utw-beta`.
- [ ] Keep MAM hound drops on Auto for the first pass.
- [ ] Keep MAM recipe overrides on Safe.
- [ ] Enable UM `celestialitems_revert`; inspect glasscutter/moonglassaxe and MAM logs.
- [ ] Kill firehound and icehound; confirm MAM fragments are not added over UM's gem loot.
- [ ] Kill a normal shark and a burning shark; confirm both mods' distinct loot behavior.
- [ ] Confirm the War Bench, book, salvage and robot automation load with UM enabled.

## 8. Full mod collection
- [ ] Add the user's mod collection in groups after the isolated test passes.
- [ ] Test storage mods and furnace mods separately before enabling the complete collection.
- [ ] Keep client and server logs from the same session.

## Expected report
Send `client_log.txt` and `server_log.txt` from the same test session, plus any screenshot/video of a broken UI or unexpected recipe. Do not use the main world until the consolidated test passes.
