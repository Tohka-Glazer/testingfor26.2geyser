# V6: Geyser-Fabric Java 26.2 / Bedrock 26.66 block-state backport

**Source recipe — NOT a prebuilt, compiled, or fully validated JAR.** Does not install or require ViaProxy. Uses the existing Geyser-Fabric mod and Fabric 26.2 branch.

## What failed in the latest BisectHosting startup log

Geyser 2.11.3-SNAPSHOT (git-DEV-bbd7e67) loads, then aborts while resolving the Bedrock `26_60` block registry:

`Unable to find minecraft:redstone_wire[east=up,north=up,power=0,south=up,west=up] Bedrock runtime ID for 26_60!`

The Java 26.2 mapping NBT contains `redstone_signal: 0`, but the Bedrock 26.60 palette also requires `redstone_north`, `redstone_east`, `redstone_south`, `redstone_west`, with string values `none`, `side`, or `up`. V5's converter covers `fire` and `chorus_plant` only, so the redstone state fails to resolve.

## V6 changes

- Extends `patches/02-directional-block-mappings.py` with redstone wire handling. Reads all four directions directly from the Java block-state ID, preserves the original `redstone_signal`, builds a full Bedrock NBT state, and looks it up in the authoritative 26.60 palette.
- Accepts only `none`, `side`, or `up` directional values. An unrecognized value or unmatchable state fails visibly (no made-up runtime IDs, substitutions, or crash suppression).
- Keeps V5's fire/chorus-plant directional handling, Bedrock 26.60–26.66 protocol registration, Java 26.2/Fabric dependency pins, NetherNet compatibility adjustment, and syntax checks.
- Does not replace the Java 26.2 mapping submodule with newer 26.3 mappings.

## Build using GitHub Actions

1. Replace the build-recipe repository files with **all contents** of this ZIP, preserving `.github/workflows/` and `patches/`.
2. Run **Actions → Experimental Geyser 26.2 + Bedrock 26.66 build → Run workflow**. The workflow syntax-checks scripts, clones the Java 26.2 Geyser source revision, applies the patches, and attempts `:fabric:build` using Java 25.
3. If successful, download the `.jar` inside the Actions artifact. The output is experimental, not verified as a working Bedrock connection.
4. Back up your BisectHosting server and preferably test on a clone. Stop the server, remove the previous `geyser-fabric` jar from `mods/` (never keep both), upload the newly built jar, keep Floodgate and Fabric API, and restart.
5. If it still fails, check the **first** `26_60 missing block mapping` / `Unable to find ... Bedrock runtime ID` message or compile error and use that for the next targeted diagnosis.

For NetherNet (Bedrock 26.60+), BisectHosting must provide a reachable Geyser port for TCP signaling **and** UDP gameplay. Configure Geyser's Bedrock transport correctly; a working server boot alone doesn't prove clients can connect.

## Source references

- Original Geyser 26.2 source: https://github.com/GeyserMC/Geyser/commit/bbd7e67
- Geyser 26.60 upstream changes: https://github.com/GeyserMC/Geyser/commit/fd35d59
- Upstream 26.60 state converter: https://github.com/GeyserMC/Geyser/blob/fd35d59/core/src/main/java/org/geysermc/geyser/registry/populator/conversion/ICanHasMoreStates.java

**Limitations:** The full Geyser/Fabric Gradle build and a real server/client test could not be run here. There could be additional 26.60 mapping changes, item translation issues, custom-block issues, or NetherNet networking problems after this specific redstone failure is fixed. This patch must not be treated as a production-ready release until those tests pass.
