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
