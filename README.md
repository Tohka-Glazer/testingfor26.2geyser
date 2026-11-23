# Experimental Geyser-Fabric Java 26.2 / Bedrock 26.66 backport attempt

**STATUS: SOURCE RECIPE ONLY. NOT A BUILT OR TESTED JAR.**

This repository is an exploratory build attempt and **is not guaranteed to compile or function**. It is based on the upstream, MIT-licensed GeyserMC project. It does not add ViaVersion. Do not deploy to a live server until you have confirmed that it starts, a Bedrock 26.66 user can join, and blocks/items map correctly. Back up your BisectHosting server first.

## How to attempt the build

1. Create a new GitHub repository, and upload the included `build.sh`, `README.md` and `.github/workflows/experimental-build.yml`, preserving the directory structure.
2. In the GitHub repository, go to **Actions > Experimental Geyser 26.2 + Bedrock 26.66 build > Run workflow**.
3. If the workflow succeeds, download its artifact ZIP. It contains an **EXPERIMENTAL** `.jar`.
4. If it fails, check the **Attempt backport and compile** log for the build error. The source files may require real manual adjustments; a successful build alone is not proof of compatibility.

Local build (requires Git, Python 3, Java 25, working Internet and outbound Maven access): `bash build.sh`.

## What the recipe actually does

- Clones GeyserMC/Geyser at `bbd7e67`, corresponding to the last known official Fabric 26.2 build `2.11.3-b1254`.
- Attempts to backport upstream commit `fd35d59` containing 26.60 Bedrock handling, assets and mapping submodule changes.
- Registers 26.61–26.66 against the upstream 26.60 codec, following the later `2a2f5af` change.
- Updates relevant Bedrock protocol and NetherNet transport dependencies but preserves the Java 26.2 McProtocolLib pin, Minecraft pin, and Fabric API pin.
- Attempts to build the Fabric distribution. Build failures stop without creating a mislabeled JAR.

## Important unresolved technical risk

The updated `mappings` submodule may be built for Java 26.3 rather than Java 26.2. Source-level differences between upstream Bedrock 26.60 changes and the older Geyser Java 26.2 branch may also cause compilation failures or runtime mapping errors. The recipe does *not* solve these issues automatically. Fixing them may require a fresh Java 26.2 + Bedrock 26.66 mapping generation and additional porting. The compiler may also report dependency API conflicts that need investigation.

## If you do produce a working JAR

BisectHosting: stop server, back it up, upload the jar to `mods/` in Starbase, remove the older Geyser-Fabric jar (keep Fabric API compatible with 26.2), restart and inspect logs. Bedrock 26.60+ uses NetherNet; use a separate TCP+UDP port allocated by BisectHosting and configure `config/Geyser-Fabric/config.yml` accordingly. Consult BisectHosting support for port allocation. Do not assume that Geyser's default 19132 port is available.

## Upstream references

- Geyser source: https://github.com/GeyserMC/Geyser
- Java 26.2 source revision: https://github.com/GeyserMC/Geyser/commit/bbd7e67
- Upstream Bedrock 26.60 changes: https://github.com/GeyserMC/Geyser/commit/fd35d59
- Upstream Bedrock 26.66 registration: https://github.com/GeyserMC/Geyser/commit/2a2f5af
- Original 26.2 Fabric download: https://modrinth.com/plugin/geyser/version/jVYS4ibU
- Geyser setup: https://geysermc.org/wiki/geyser/setup/
