BETTER LUCY - LOYAL, QUIRKY & POSSESSIVE
Version 0.4.0
Author: Sharethylove

NEW IN 0.2.0
------------
Huge dialogue expansion with personality presets.

VOICE
-----
Normal
Quiet (50%)
Very Quiet (25%)
Muted

DIALOGUE MODE
-------------
Vanilla + Custom
Custom Only
Vanilla Only

PERSONALITY
-----------
Classic+
  Funny, quirky, loyal Lucy.

Wife Mode
  Classic+ plus wife/husband and romantic lines.

Yandere Mode
  Wife Mode plus stronger clingy/possessive dialogue.

Spicy Innuendo
  Yandere Mode plus cheeky double-entendres.
  Intentionally suggestive rather than explicit.

Everything
  All current custom dialogue pools.

EDITING
-------
Open:
scripts/better_lucy_lines.lua

The file is split into:
classic
wife
yandere
spicy

and then into situations such as:
equipped
on_chopped
on_ground
on_dropped
on_pickedup
in_container
other_owner
transform_beaver
transform_woodie
etc.

IMPORTANT TEST NOTE
-------------------
Lucy uses DST's existing sentient-axe dialogue events. Some dialogue
categories are dependent on which events the current game build fires.
If a category does not trigger reliably (especially other_owner), the
next version can directly hook equip/pickup events to guarantee it.

No combat, damage, durability, or chopping balance changes are included
yet. This version focuses entirely on Lucy's personality and audio.


0.2.1 FIXES
-----------
Dialogue Display Time:
- Vanilla: 2.5 seconds
- A Little Longer: 3.25 seconds [default]
- Longer: 4 seconds
- Extra Long: 5 seconds
- Very Long: 6 seconds

Voice volume was rewritten. Quiet/Very Quiet now stop Lucy's vanilla
loop and immediately replay the same Lucy sound at the selected volume.
Muted stops both the normal and special Lucy voice channels entirely.


0.3.0 GAMEPLAY OPTIONS
----------------------
Lucy's Combat Damage:
- Vanilla
- 1.5x
- 2x [default]
- 3x
- 5x

Lucy's Chopping Power:
- Vanilla
- 2x [default]
- 4x
- 10x
- Instant

"Instant" sets Lucy's CHOP effectiveness to 100, which is enough to
drop normal trees in one swing and mirrors the very high effectiveness
used by DST's developer tool.

These options only affect Lucy and do not globally modify other axes.


0.3.1 AUDIO HOTFIX
------------------
If Quiet/Very Quiet/Muted did nothing in 0.3.0, this build changes the timing.

Lucy starts her vanilla chatter from an "ontalk" event. Better Lucy now waits
until that event has finished, then applies the selected volume. It repeats the
change one frame later as a fallback.

TEST:
1. Set Lucy Voice Sound = Muted.
2. Start the world fresh.
3. Wait for Lucy to speak.
4. You should see her text but hear no Lucy chatter.

Then test Very Quiet and Quiet.


0.3.2 AUDIO FIX
---------------
The actual bug was identified in current DST's Lucy prefab.

Lucy does not play her normal chatter from:
    inst.SoundEmitter

She creates a separate local-only sound object:
    inst.localsounds.SoundEmitter

This build now changes/kills the "talk" channel on that emitter directly.


0.4.0 IMPORTANT AUDIO TEST
--------------------------
Muted now prevents Lucy's vanilla "ontalk" sound listener from firing at all.
This is different from 0.3.x, which muted the sound AFTER it had already
started and could produce a tiny audible chirp.

Test with:
Lucy Voice Sound = Muted

Expected:
- Lucy text appears.
- No initial Lucy chatter/blip.
- No Lucy loop afterward.

Then test Very Quiet and Quiet.

Fan lore is included in BETTER_LUCY_LORE.txt.


0.5.1 VOICE TEST
----------------
Normal:
- Klei's original Lucy chatter at normal volume.

Quiet:
- Lucy chatter at 50% volume.

Very Quiet:
- Lucy chatter at 25% volume.

Muted:
- Text remains visible.
- Lucy chatter does not start.

IMPORTANT:
After changing the mod configuration, leave the world and load it again so the
new VOICE_MODE value is applied when the mod initializes.

ICON
----
The mod now uses:
    icon_atlas = "better_lucy.xml"
    icon = "better_lucy.tex"
