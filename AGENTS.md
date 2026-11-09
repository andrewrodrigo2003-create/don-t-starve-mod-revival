<!-- LOVABLE:BEGIN -->
> [!IMPORTANT]
> This project is connected to [Lovable](https://lovable.dev). Avoid rewriting
> published git history — force pushing, or rebasing/amending/squashing commits
> that are already pushed — as it rewrites history on Lovable's side and the
> user will likely lose their project history.
>
> Commits you push to the connected branch sync back to Lovable and show up in
> the editor, so keep the branch in a working state.
<!-- LOVABLE:END -->

## DST mods
- `dst-mods/` holds the user's fixed Don't Starve Together mods (Lua 5.1, not part of the web app); keep finished mods there because the sandbox /tmp is wiped and this folder syncs to GitHub.
- `dst-mods/tests/` are Lua harnesses that need the game scripts extracted at /tmp/game/scripts (from the DST dedicated server, app 343050) and lua5.1.
- Before changing a DST mod, read `docs/ENGINEERING_PLAYBOOK_DST_MODS.md`, `docs/CRASH_AND_COMPATIBILITY_TRIAGE.md`, the relevant master plan, and the current roadmap.
- For Metals and More Reforged, change only `dst-mods/metals_and_reforged/` unless a narrowly scoped shared test/workflow/documentation change is required.
- Never edit Better Lucy, Hydrated/Dehydrated, Uncompromising Mode, Better Wood Skill Tree, vanilla game files, or another Workshop mod to implement compatibility. Fix integration behavior on the Metals and More side.
- Preserve the user's requirement that spells do not require Metals and More weapons. Do not reintroduce a weapon ownership/equipment gate for spell casting.
- Do not claim universal Workshop compatibility. Record tested versions, mod IDs, load order, test level, and unverified combinations.
- Keep gameplay authority on the server; test Lua 5.1 syntax, real-module harnesses, game API contracts, and in-game/multiplayer behavior separately.
- Never claim a harness or static inspection is equivalent to an in-game test.
