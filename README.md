# Experimental Geyser Fabric 26.2 + Bedrock 26.66 backport — V4

## Why the previous custom JAR crashed

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
