# V5 syntax-fixed Geyser Fabric Java 26.2 / Bedrock 26.66 experiment

**STATUS: NOT A COMPILED OR VERIFIED JAR.** This ZIP corrects the V4 GitHub Actions `SyntaxError` and keeps the V4 Java block-state backport. A successful shell/Python syntax test does **not** establish that Gradle builds, that the server starts, or that Bedrock players can join.

## What caused V4's error

`build.sh` opened a Python heredoc with `python3 - <<'PY'` and, before closing it, included a second Bash `python3 - <<'PY_V4'` command. The first Python interpreter hit this Bash command on line 75 and returned `SyntaxError: invalid syntax`.

V5 moves each Python patch into a separate file in `patches/`. They run consecutively via Bash, removing the nested heredoc risk. The GitHub Actions workflow now uses `bash -n` and `python3 -m py_compile` before cloning.

## Recommended alternative: supported external proxy

The Geyser team's documented path for an older Fabric server is **ViaProxy with the Geyser-ViaProxy plugin**. This usually avoids maintaining a custom Geyser-Fabric backport and lets the BisectHosting server stay on Fabric 26.2. ViaProxy must run as a **separate Java process** (not in the Fabric `mods/` folder), on a host or hosting plan that can run it. Install the latest compatible Geyser-ViaProxy, enable `bedrock.transport: nethernet`, ensure a reachable separate TCP + UDP port for Bedrock players, and point ViaProxy at the existing Java 26.2 server. Check that the Geyser build advertises Bedrock 26.66 before deploying; use staging first. With the CLI and Java online-mode authentication, account setup/Floodgate may be needed.

Official instructions:
- https://geysermc.org/wiki/geyser/supported-versions/
- https://geysermc.org/wiki/geyser/setup/
- https://github.com/ViaVersion/ViaProxy
- https://geysermc.org/download/

## To test the corrected experimental V5 build recipe

1. Upload **all** contents of this ZIP (including `patches/` and `.github/`) to your GitHub recipe repository, replacing V4 files.
2. Run **Actions → Experimental Geyser 26.2 + Bedrock 26.66 build → Run workflow**.
3. The first step checks shell and Python syntax. The next attempts the Geyser source backport and Gradle compile. On failure inspect the **first real error**, not just the final `Process completed with exit code 1`.
4. An artifact is uploaded **only if Gradle succeeds**. It remains experimental; test on a backed-up server with a real Bedrock 26.66 client.

No compiled `.jar` is included. For Bedrock 26.60+, a Bedrock-facing Geyser port must work over **both TCP and UDP**, independently of the Java server port. Contact BisectHosting support about network allocation and whether a separate proxy process is allowed. This V5 deliberately leaves Java/Fabric dependency pins and the original mapping submodule untouched, so further failures are possible.

---

## Technical background from V4



V3 successfully compiled, but your BisectHosting log reported `Unable to find minecraft:fire[age=0,...] Bedrock runtime ID for 26_60!`. The Java 26.2 mapping submodule contains `minecraft:fire` with `age` only, while Bedrock 26.60 added the `minecraft:connection_*` directional block states. V3's 26.60 palette mapping used `tag -> tag`, so the block state had no matching Bedrock runtime ID.

See the official Geyser Bedrock-26.60 conversion source:
https://github.com/GeyserMC/Geyser/blob/fd35d59/core/src/main/java/org/geysermc/geyser/registry/populator/conversion/ICanHasMoreStates.java

## V4 changes

- Retains V3's exact Java 26.2 mappings, Fabric dependencies and NetherNet API fix.
- On a missing 26.60 mapping for **fire** or **chorus plant**, examines the 26.60 palette entries. It matches pre-existing states exactly, and matches any newly-added `minecraft:connection_*` Boolean properties to the Java block-state direction flags.
- Rejects missing, non-Boolean or ambiguous candidate mappings instead of inventing a runtime ID or silently selecting a wrong block.
- For all remaining mismatches, logs 3 examples of the matching Bedrock palette entry so we can diagnose subsequent fixes.
- Does **not** alter the world, repair corrupted chunks, turn off validations, replace fire with another block, or change authentication/ports.

**Important:** this only addresses the category of failure exposed by the current log. Other Java26.2/Bedrock26.60 mismatches may still exist (redstone wire, items, other Bedrock protocol changes). This build has **not** been compiled or tested here, and may fail at build time, startup, or connection. The current Bedrock 26.66 connection is not verified. This is a build recipe, not a functioning JAR.

## GitHub Actions steps

1. Copy `build.sh` from this ZIP to the root of the same GitHub Actions recipe repository, replacing the V3 version.
2. Commit changes; open Actions and run the existing experimental workflow.
3. If Actions succeeds, download the `.jar` from the artifact ZIP.
4. **Use a separate/staging server or fully backed-up copy of BisectHosting server** to test. Do not deploy experimental jars into a production server where players have data at risk.
5. If the test server still crashes, provide the FIRST new `Unable to find ...` error and the `26_60 missing block mapping` line. Those lines will show the next missing conversion.

To immediately restore the server, stop it, remove the experimental V3 JAR, reinstall the last known-good matching Java 26.2 Geyser build (which may not support latest Bedrock), and restart.
