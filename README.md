# Geyser-Fabric 26.2 + Bedrock 26.66 — backport experiment v3

**NOT a compiled or tested JAR.** v3 addresses a newer API mismatch after v2 reached the Java compiler (`NetherNetServer.java` uses the removed `setProxyProtocol(boolean)` method). v2 addressed the GitHub Actions failure where cherry-picking `fd35d59` reported conflicts in `BlockRegistryPopulator.java`, `ItemRegistryPopulator.java`, the removed `WildernessBoundConverter.java`, and `core/src/main/resources/mappings`.

## What changed in v3

The newer Cloudburst Network dependency removed the `NetherNetHTTPServerSignaling.Builder.setProxyProtocol(boolean)` method. Geyser's current upstream source likewise omits this call and retains `.setProxyProtocolProxies(...)`. v3 removes only that obsolete setter call; it does not disable all proxy handling or change your Fabric 26.2 mappings. This specifically fixes the Java compilation error shown at `NetherNetServer.java:222`.

This is based on inspection of upstream Geyser source, **not** a verified compilation or game-connection test. A successful build may still have runtime problems.

## What changed from v1

Instead of trying to cherry-pick the entire Java-26.3-era commit, this script:

1. Clones the official Java 26.2 revision (`bbd7e67`).
2. Retrieves the official Bedrock 26.60 palette and item data files from Geyser's `fd35d59` commit, **without modifying the Java 26.2 `mappings` submodule**.
3. Adds the Bedrock 26.60–26.66 codec and palette registrations to the existing Java 26.2 registry classes, and adds the 26.60 matchmaking packet serializers.
4. Updates the same Cloudburst codec/transport dependency pins as the first attempt, preserving Minecraft 26.2, Fabric API and McProtocolLib pins.
5. Tries to compile a Fabric JAR using GitHub Actions.

It avoids the **specific Git merge conflicts** in v1. It does not guarantee a successful Gradle compile or working gameplay.

## Run on GitHub Actions

Replace the original `build.sh` with this v3 `build.sh`. The `.github/workflows/experimental-build.yml` workflow can remain the same; it's included for convenience. Commit and push the change, then go to **Actions → Experimental Geyser 26.2 + Bedrock 26.66 build → Run workflow**.

If the build succeeds, the Actions artifact ZIP should contain a `.jar`. This is *still not validated* as compatible. Before trying it on BisectHosting, back up the server and test on a separate copy first.

## Important compatibility risks

- New Bedrock 26.60 block palettes may require block-state conversion rules not present in 26.2. This script uses the old Java 26.2 mapping set and identity mapping for 26.60; the server may fail to initialize or blocks may appear incorrectly.
- The original 26.60 commit included additional remappers that v2 doesn't import because its newer Java registry code conflicts with 26.2. Additional manual backporting may be needed after compilation.
- Newer Bedrock protocol dependencies may be incompatible with older Geyser APIs.
- The port is NOT verified by compilation or an actual Bedrock 26.66 connection. No ViaVersion is used.

**Do not upload this ZIP to BisectHosting's mods directory.** Use only a successfully compiled, tested `.jar` in a test server.

Upstream: https://github.com/GeyserMC/Geyser/commit/fd35d59
