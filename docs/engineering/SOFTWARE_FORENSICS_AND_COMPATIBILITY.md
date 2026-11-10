# Software forensics, debugging and compatibility engineering

**Status:** engineering standard, first implementation 2026-11-09  
**Scope:** user-owned projects, open-source software, public interfaces, and third-party code the user is authorized to inspect.

## Objective
Turn unfamiliar software into testable evidence: identify inputs, lifecycle, dependencies, hooks, state transitions and failure modes; reproduce a defect; isolate the responsible interaction; implement the smallest safe fix; and prove what was and was not validated. This is not a promise of universal compatibility.

## 1. Evidence hierarchy
1. Exact source tree and binary/archive supplied by the user or legitimately installed locally.
2. Exact game/runtime scripts and API implementation for the tested version.
3. Official documentation, release notes and security advisories.
4. Upstream source, issues, pull requests, tags and commit history.
5. Maintainer discussions and established community forums.
6. Public mirrors, archives and search indexes, marked as secondary.
7. Inference from behavior, symbols, strings or disassembly, labeled as hypothesis until reproduced.

Search snippets, AI-generated API docs and stale mirrors are discovery aids, not authoritative implementation evidence.

## 2. Intake and preservation
- Preserve originals read-only; work on copies.
- Record origin, acquisition date, version/tag/commit, size, archive format and SHA-256.
- Inventory archives before extraction. Reject absolute paths and path traversal; never blindly extract untrusted archives.
- Identify file types by content as well as extension.
- Record license, attribution and redistribution permissions.
- Do not upload proprietary game files or third-party assets to a public repository.
- Never execute an unknown mod or binary on the host; use an isolated disposable test environment.

The helper tools/dst_mod_audit.py inventories folders/ZIPs, computes SHA-256 and reports source indicators without executing scanned code. Matches are leads, not verdicts.

## 3. Static source analysis
For Lua/DST:
- Search definitions and call sites, not only error text.
- Trace each receiver to its constructor and component registration.
- Map AddPrefabPostInit, AddComponentPostInit, player/sim hooks, prefab constructors, modmain.lua, modimport, modrequire, config gates and load order.
- Find global mutations, monkey patches, metatable changes, wrapped methods and assumptions about component existence.
- Compare APIs with the exact game's scripts.zip; verify component creation order and server/client authority.
- For recipe compatibility, compare recipe IDs, tech requirements, ingredients, filters, builders, unlock paths and mod enablement. Prefer explicit adapters over broad global overrides.
- Treat SetSpellFn and projectile methods as component-specific; never assume every entity exposes them.

For native/compiled code, choose tools after identifying format/platform:
- file, hashes, strings, symbol tables and metadata for initial triage.
- Ghidra or Rizin/Cutter for authorized static disassembly/decompilation.
- GDB/LLDB or WinDbg for debugging owned/test binaries.
- Frida or equivalent runtime instrumentation only in a controlled environment and where permitted.
- Compare versions and symbols before interpreting decompiler output. Decompiled code is approximation, not original source.

## 4. Debugging workflow
1. Convert the report into expected-vs-actual behavior.
2. Preserve the complete stack trace and environment (game build, OS, mod versions/IDs, load order, server/client role, config).
3. Identify the first relevant frame owned by the project; distinguish throw site from root cause.
4. Form competing hypotheses and list evidence that would falsify each.
5. Reduce to a minimal reproduction by enabling one dependency at a time and testing load-order permutations.
6. Instrument boundaries: arguments, receiver/component type, lifecycle phase, authority, return values and state before/after.
7. Reproduce against a clean baseline; use controlled stubs only for narrow unit tests.
8. Fix the smallest causal layer. Do not add silent broad fallbacks that hide invalid state.
9. Add a regression test for the original failure and adjacent edge cases.
10. Re-run baseline, targeted test, full suite, syntax checks and real game/multiplayer scenarios.
11. Record evidence, uncertainty and rollback instructions.

## 5. Test ladder
| Level | Method | Evidence | Does not prove |
|---|---|---|---|
| 1 | Inventory, hashes, static search | Artifact identity and integration leads | Runtime behavior |
| 2 | Lua 5.1 parser/lint | Syntax and selected static defects | DST API correctness |
| 3 | Unit tests with narrow stubs | Local function behavior | Real game lifecycle |
| 4 | Harness with exact extracted game scripts | API contracts and module interactions | Full world behavior |
| 5 | Disposable in-game world | Prefab, recipe, UI and gameplay | Multiplayer correctness |
| 6 | Dedicated server + client(s) | Authority, replication, save/load | Every mod/load order |
| 7 | Matrix with named versions | Evidence for tested combinations | Universal compatibility |

Never label a syntax or harness pass as an in-game fix.

## 6. Compatibility architecture for Metals and More
- Keep a vanilla-compatible baseline.
- Maintain explicit, versioned adapters for known mods.
- Detect mods using supported mod-index APIs; guard optional dependencies.
- Translate recipes through stable identifiers and documented recipe APIs.
- Preserve external item identity while mapping materials/tech to Metals and More progression.
- Do not mutate every recipe globally or patch another Workshop mod's files.
- Make adapters idempotent and order-safe; avoid duplicate registration.
- Log adapter activation and unsupported versions without flooding logs.
- Unknown mods remain unchanged unless a safe generic integration is proven.
- Test with and without Metals and More, dependencies present/absent, and multiple load orders.
- Preserve the user's requirement that spell casting must not require Metals and More weapons.

## 7. Encryption, encoding and protected formats
Identify the actual transformation:
- Encoding (Base64, hex, URL encoding) is reversible representation, not encryption.
- Compression (ZIP, gzip, zlib) needs the matching decompressor.
- Encryption requires the correct algorithm, mode, key and often nonce/IV and authentication tag.
- Hashes are one-way integrity identifiers; they are not decrypted.
- Compiled bytecode can sometimes be disassembled, but source recovery is approximate and version-dependent.
- Proprietary asset containers may require a documented/open-source parser or a tool permitted by the license.

Allowed: decode/decompress user-owned data, inspect open formats, analyze code the user owns or may inspect, recover metadata, compare binaries and document format hypotheses.

Out of scope: bypassing DRM, Steam/Klei entitlements, authentication, access controls, encryption protecting third-party content without authorization, credential extraction, or covert access to private servers/accounts. Never upload keys, secrets, private certificates or protected assets to GitHub.

## 8. Public research and unusual but legitimate sources
Search broadly, but keep a source ledger:
- Official docs, source repositories, commit history, tags, issue/PR discussions and release artifacts.
- Maintainer forums, modding forums, public Discord material actually public/authorized.
- Public package registries, source indexes, public mirrors and archived snapshots where terms permit.
- Search engine caches/snippets as discovery leads; verify against original sources.
- Compare forks and historical revisions to find when behavior changed.
- Search exact error strings, symbols, Workshop IDs, prefab/component names, paths and commit hashes.
- Record URL, retrieval date, author/source, version, evidence excerpt and confidence.

Do not evade logins, paywalls, private Discord permissions, rate limits, robots/access controls or API restrictions. A strange endpoint is not permission to access it.

## 9. AI-assisted engineering protocol
Each agent must state repository, branch, commit and files inspected; separate facts, hypotheses and recommendations; cite paths/lines or immutable URLs; never invent tests, access, logs or successful fixes; use a second reviewer for high-risk changes; avoid sending secrets or proprietary assets to external models; keep changes small, reversible and tested; and save durable findings to the shared knowledge base.

## 10. DST-specific workflow
The source of truth is the user's exact local DST build at Don't Starve Together/data/databundles/scripts.zip. Extract to a disposable source directory; never edit installed game files. Record game build and scripts.zip hash. Every compatibility claim must record Workshop ID/version/commit, DST build, enabled mods and load order, world/server configuration, reproduction steps, test level, logs, result and limitations.

## 11. Implementation and next steps
Implemented in this PR:
- tools/dst_mod_audit.py: read-only folder/ZIP inventory, SHA-256 and Lua integration signal scan.
- tests/test_dst_mod_audit.py: regression tests for folder/ZIP inventory, source signals and unsafe archive paths.
- Dedicated CI workflow runs audit-tool tests and generates a Metals and More source report.

Next:
- optional RAR/7z listing/extraction through an installed extractor with safe path validation;
- baseline comparison and machine-readable compatibility matrix;
- API/recipe cross-reference against exact extracted DST scripts;
- controlled integration harnesses for Lucy/Woodie and recipe registration;
- optional Lua linting and test coverage reports;
- repeatable dedicated-server/client test harness where environment permits.

## References
- Klei modding guidance: https://support.klei.com/hc/en-us/articles/360029555992-Modding-Don-t-Starve-and-Don-t-Starve-Together
- Klei Workshop workflow: https://support.klei.com/hc/en-us/articles/360029556512-How-do-I-download-mods-for-Don-t-Starve-Together-Steam
- DST scripts.zip notes: https://kleiforums.com/forums/topic/136505-how-to-get-developer-tools/
- DST vanilla script reference (secondary/generated; verify locally): https://vietnd69.github.io/dst-api-webdocs/
- Lua 5.1 manual: https://www.lua.org/manual/5.1/
- Ghidra: https://github.com/NationalSecurityAgency/ghidra
- OWASP SBOM guidance: https://owasp.github.io/DevSecOpsGuideline/2-Process/2-3-Build/2-3-6-1-SBOM/


Additional DST security context:
- Klei's January 2025 mod API discussion describes emergency changes after malicious code abused permissive mod APIs to spread through other mods and use command-and-control behavior: https://kleiforums.com/forums/topic/163519-mod-api-discussion-thread/


## 12. Cross-mod conflict candidate scanner (2026-11-10)

The read-only audit tool now emits two additional report sections:
- `registration_candidates`: source path/line, API family, target symbol, operation type and provisional severity.
- `potential_cross_mod_conflicts`: repeated targets observed across top-level mod folders.

Current recognized surfaces:
- AddComponentPostInit, AddPrefabPostInit/AddPrefabPostInitAny, AddStategraphPostInit;
- AddStategraphActionHandler keyed by graph + ACTIONS identifier;
- AddStategraphState keyed by graph + state name;
- AddAction identifiers;
- direct ACTIONS/global assignments;
- EntityScript method overrides and containers.widgetsetup replacement.

Interpretation rules:
- Repeated component/prefab/StateGraph post-init hooks are informational because multiple callbacks can be valid and additive.
- Repeated StateGraph action handlers, state names, AddAction IDs and direct global/action assignments are high-priority candidates for manual inspection.
- A candidate is not proof of a runtime collision. The scanner does not evaluate load order, callback bodies, conditional registration, dynamic names, function delegation or actual registry semantics.
- Scan a collection root containing one folder per mod to obtain cross-mod grouping. Scanning a single mod folder inventories its own hooks but cannot infer conflicts with absent mods.
- The scanner is conservative regex-based triage, not a complete Lua parser. Dynamically constructed registrations may be missed; unusual syntax and strings may create false positives. Every report must be reviewed against source and actual load logs.

New regression fixtures cover competing global assignments, duplicate StateGraph handlers, additive component post-init hooks, Lua comments, and a single-mod ZIP containing multiple internal folders. The existing CI workflow already runs `tests/test_dst_mod_audit.py`, so no new framework or dependency is introduced.

This extension does not change gameplay code, install software, execute scanned Lua, extract ZIPs, or prove in-game compatibility.


### Mod metadata enrichment

The scanner also reads only simple literal assignments from `modinfo.lua`: `name`, numeric `priority`, and string entries in `mod_dependencies`. The values are emitted in `mod_metadata` and attached to conflict records as `mod_details`. It does not execute modinfo, resolve expressions/variables, or claim to know the effective load order. Treat priority/dependency values as declared metadata only; confirm actual order from the DST startup log and the exact loader build.

A regression fixture verifies numeric priority, declared dependency extraction, and metadata association with a synthetic conflict. The scanner still requires a collection root (one directory per mod) to compare separate mods.


## 13. AST-based wrapper-chain triage (2026-11-10)

An optional, isolated Python tool was added at `tools/dst_wrapper_audit.py`, using pinned `luaparser==4.2.0` and a dedicated requirements file/workflow. The core regex scanner remains independent of this optional dependency.

Current prototype recognizes a conservative same-block pattern:
1. A local alias captures a dotted receiver method (for example, `local previous = self.SetVal`).
2. The same lexical block assigns an anonymous function or named method back to that target.
3. The wrapper body is inspected for calls to the captured alias, direct return of that call, basic `self` forwarding, vararg presence/forwarding, and conditional control-flow nodes.

The report distinguishes no delegation, direct delegation, previous-call return placement, and simple argument evidence. It reports parser errors and applies per-file/total source-size caps. It never executes scanned Lua.

### Prototype limits
- Same-block matching is not a complete Lua lexical-scope resolver. Shadowing, alias reassignment, aliases passed through tables/closures, bracket/dynamic keys, and cross-file chains may be missed or misassociated.
- A call appearing inside a conditional is not proof every path delegates. The current conditional flag is a coarse signal, not path-sensitive analysis.
- Parameter-name matching cannot infer API semantics, intentional transformations, optional arguments, or all multiple-return behavior.
- The parser's Lua 5.1 grammar pass is not a substitute for the exact game's `luac` or engine runtime.
- Findings are medium-confidence review candidates, not confirmed defects.

### Regression corpus
The isolated test module covers cooperative return, missing delegation, previous call without direct return, vararg forwarding and omission, missing `self`, nested closures, conditional calls, unrelated assignments, and captures in different blocks. A dedicated CI workflow installs only the AST tool's optional dependencies and runs both scanner test modules. The workflow result must be checked before calling this extension verified.

### Research decision
Python `luaparser` was selected over a first Tree-sitter integration because the current scanner is Python and the library exposes typed Lua AST nodes, traversal and source line information. The parser is MIT licensed and supports Lua 5.1; its AST analysis remains optional to avoid coupling the core inventory tool to parser dependencies. Tree-sitter Lua remains a candidate for a future independent comparison, especially if parser resilience/performance becomes a problem.

Sources:
- https://py-lua-parser.readthedocs.io/en/latest/astnodes.html
- https://py-lua-parser.readthedocs.io/en/latest/api.html
- https://pypi.org/project/luaparser/4.2.0/
- https://tree-sitter-grammars.github.io/tree-sitter-lua/
