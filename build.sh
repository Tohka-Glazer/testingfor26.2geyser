#!/usr/bin/env bash
# EXPERIMENTAL, unverified source backport for Java 26.2 / Bedrock 26.66.
# v6: builds on v5 and maps Java 26.2 redstone-wire connections to Bedrock 26.60 directional states, retaining fire/chorus fixes.
# Does not invent runtime IDs. NOT YET BUILD/STARTUP/CLIENT TESTED.
# This version deliberately DOES NOT cherry-pick fd35d59 because it conflicts
# with Java 26.2's registries and mapping submodule.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
if [[ -e geyser-src ]]; then
  echo 'ERROR: geyser-src already exists; delete it to start over.' >&2
  exit 1
fi

git clone https://github.com/GeyserMC/Geyser.git geyser-src
cd geyser-src
git checkout --detach bbd7e67

# Copy ONLY new Bedrock 26.60 data files; do not touch Java 26.2 mappings.
# The full upstream commit includes newer Java registry code that does not
# cleanly merge onto the 26.2 branch.
git restore --source=fd35d59 -- \
  core/src/main/resources/bedrock/block_palette.26_60.nbt \
  core/src/main/resources/bedrock/creative_items.26_60.json \
  core/src/main/resources/bedrock/data_driven_blocks.26_60.nbt \
  core/src/main/resources/bedrock/item_components.26_60.nbt \
  core/src/main/resources/bedrock/runtime_item_states.26_60.json

# Carefully add 26.60 codec and palette wiring without replacing Java 26.2
# block/item registry logic or 26.2's mappings submodule.
# Use separately validated Python patch scripts. This avoids nested here-document
# parsing errors (the specific cause of the original V4 Actions failure).
python3 "$ROOT/patches/01-protocol-and-nethernet.py"
python3 "$ROOT/patches/02-directional-block-mappings.py"
python3 "$ROOT/patches/03-dependencies.py"

# The submodule pointer stays EXACTLY at the Java 26.2 source commit.
git submodule update --init --recursive

echo '--- Java and Bedrock dependency versions ---'
grep -E '^\s*(minecraft|fabric-api|mcprotocollib|protocol-codec|network|netty)\s*=' gradle/libs.versions.toml || true

echo '--- Compile Fabric build ---'
chmod +x gradlew
./gradlew :fabric:build --no-daemon --stacktrace
artifact=bootstrap/mod/fabric/build/libs/Geyser-Fabric.jar
if [[ ! -s "$artifact" ]]; then
  echo "ERROR: compiled build did not generate $artifact" >&2
  exit 1
fi
mkdir -p "$ROOT/out"
cp "$artifact" "$ROOT/out/Geyser-Fabric-Java26.2-Bedrock26.66-EXPERIMENTAL.jar"
sha256sum "$ROOT/out/"*.jar
printf '\nEXPERIMENTAL artifact only. Not tested with a Minecraft 26.2 server or 26.66 client.\n'
