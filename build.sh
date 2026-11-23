#!/usr/bin/env bash
# EXPERIMENTAL, unverified source backport for Java 26.2 / Bedrock 26.66.
# v4: adds a narrow Java 26.2 -> Bedrock 26.60 directional state bridge.
# It strictly checks all required palette states; it DOES NOT invent runtime IDs.
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
python3 - <<'PY'
from pathlib import Path
import re

src = Path('core/src/main/java/org/geysermc/geyser')

def modify(path, pairs):
    p = src / path
    s = p.read_text()
    for original, replacement in pairs:
        if s.count(original) != 1:
            raise SystemExit(f'ERROR: expected exactly one anchor in {p}: {original!r}, saw {s.count(original)}')
        s = s.replace(original, replacement)
    p.write_text(s)
    print(f'Patched {path}')

v2193 = 'import org.cloudburstmc.protocol.bedrock.codec.v2193.Bedrock_v2193;'
v2225 = 'import org.cloudburstmc.protocol.bedrock.codec.v2225.Bedrock_v2225;'
modify(Path('network/bedrock/GameProtocol.java'), [
    (v2193, v2193 + '\n' + v2225),
    ('register(Bedrock_v2193.CODEC, "26.50", "26.51", "26.52");',
     'register(Bedrock_v2193.CODEC, "26.50", "26.51", "26.52");\n'
     '        register(Bedrock_v2225.CODEC, "26.60", "26.61", "26.62", "26.63", "26.64", "26.65", "26.66");'),
])

modify(Path('registry/populator/BlockRegistryPopulator.java'), [
    (v2193, v2193 + '\n' + v2225),
    ('.put(ObjectIntPair.of("26_50", Bedrock_v2193.CODEC.getProtocolVersion()), tag -> tag)',
     '.put(ObjectIntPair.of("26_50", Bedrock_v2193.CODEC.getProtocolVersion()), tag -> tag)\n'
     '                .put(ObjectIntPair.of("26_60", Bedrock_v2225.CODEC.getProtocolVersion()), tag -> tag)'),
])

modify(Path('registry/populator/ItemRegistryPopulator.java'), [
    (v2193, v2193 + '\n' + v2225),
    ('paletteVersions.add(new PaletteVersion("26_50", Bedrock_v2193.CODEC.getProtocolVersion()));',
     'paletteVersions.add(new PaletteVersion("26_50", Bedrock_v2193.CODEC.getProtocolVersion()));\n'
     '        paletteVersions.add(new PaletteVersion("26_60", Bedrock_v2225.CODEC.getProtocolVersion()));'),
])

modify(Path('registry/populator/TagRegistryPopulator.java'), [
    (v2193, v2193 + '\n' + v2225),
    ('ObjectIntPair.of("26_30", Bedrock_v2193.CODEC.getProtocolVersion())',
     'ObjectIntPair.of("26_30", Bedrock_v2193.CODEC.getProtocolVersion()),\n'
     '            ObjectIntPair.of("26_30", Bedrock_v2225.CODEC.getProtocolVersion())'),
])

modify(Path('network/bedrock/CodecProcessor.java'), [
    ('import org.cloudburstmc.protocol.bedrock.packet.ClientToServerHandshakePacket;',
     'import org.cloudburstmc.protocol.bedrock.packet.ClientToServerHandshakePacket;\n'
     'import org.cloudburstmc.protocol.bedrock.packet.ClientboundMatchmakingStatePacket;'),
    ('import org.cloudburstmc.protocol.bedrock.packet.ScriptMessagePacket;',
     'import org.cloudburstmc.protocol.bedrock.packet.ScriptMessagePacket;\n'
     'import org.cloudburstmc.protocol.bedrock.packet.ServerboundMatchmakingCancelPacket;'),
    ('        return codecBuilder.build();',
     '        // 26.60+ packets that Geyser should ignore.\n'
     '        if (codec.getProtocolVersion() >= 2225) {\n'
     '            codecBuilder.updateSerializer(ClientboundMatchmakingStatePacket.class, IGNORED_SERIALIZER);\n'
     '            codecBuilder.updateSerializer(ServerboundMatchmakingCancelPacket.class, IGNORED_SERIALIZER);\n'
     '        }\n'
     '        return codecBuilder.build();'),
])

# New Cloudburst Network Builder removed setProxyProtocol(boolean).
# Follow Geyser upstream: the trusted-proxies setter remains, but there is
# no longer a separate Boolean switch on the signaling Builder.
modify(Path('network/bedrock/nethernet/NetherNetServer.java'), [
    ('                    .setProxyProtocol(geyser.config().advanced().bedrock().useHaproxyProtocol())\n',
     ''),
])

# Minecraft Bedrock 26.60 adds directional connection states to fire/chorus
# (see Geyser upstream ICanHasMoreStates converter). The Java 26.2 mapping
# submodule's block NBT lacks these states. Select a Bedrock palette entry
# only when its existing NBT states AND every new directional Boolean match
# the actual Java block state. Otherwise keep the original hard failure.
python3 - <<'PY_V4'
from pathlib import Path
p = Path('core/src/main/java/org/geysermc/geyser/registry/populator/BlockRegistryPopulator.java')
s = p.read_text()
anchor = 'GeyserBedrockBlock vanillaBedrockDefinition = blockStateOrderedMap.get(bedrockTag);'
if s.count(anchor) != 1:
    raise SystemExit(f'ERROR: expected one Bedrock block lookup, got {s.count(anchor)}')
replacement = '''GeyserBedrockBlock vanillaBedrockDefinition = blockStateOrderedMap.get(bedrockTag);
            if (vanillaBedrockDefinition == null && "26_60".equals(palette.key())) {
                vanillaBedrockDefinition = findDirectional26_60Block(bedrockTag, javaId, blockStateOrderedMap);
                if (vanillaBedrockDefinition == null) {
                    var sample = blockStateOrderedMap.keySet().stream()
                            .filter(tag -> tag.getString("name").equals(bedrockTag.getString("name")))
                            .limit(3).toList();
                    GeyserImpl.getInstance().getLogger().error("26_60 missing block mapping: " + javaId +
                            "; target palette examples: " + sample);
                }
            }'''
s=s.replace(anchor, replacement)
method_anchor='    private static NbtMap buildBedrockState(BlockState state, NbtMap nbt) {'
if s.count(method_anchor) != 1:
    raise SystemExit(f'ERROR: expected one buildBedrockState declaration, got {s.count(method_anchor)}')
method = '''    /**
     * Adapt 26.2-era fire and chorus states to the Bedrock 26.60 palette.
     * This is intentionally strict: never choose a palette entry unless all
     * pre-existing states and all new directional Boolean states match.
     */
    private static GeyserBedrockBlock findDirectional26_60Block(NbtMap source, String javaId,
                                                                  Map<NbtMap, GeyserBedrockBlock> palette) {
        String blockName = source.getString("name");
        if (!"minecraft:fire".equals(blockName) && !"minecraft:chorus_plant".equals(blockName)) {
            return null;
        }
        NbtMap oldStates = source.getCompound("states");
        GeyserBedrockBlock found = null;
        for (Map.Entry<NbtMap, GeyserBedrockBlock> entry : palette.entrySet()) {
            NbtMap tag = entry.getKey();
            if (!blockName.equals(tag.getString("name"))) {
                continue;
            }
            NbtMap newStates = tag.getCompound("states");
            boolean matches = true;
            for (Map.Entry<String, Object> oldState : oldStates.entrySet()) {
                if (!java.util.Objects.equals(oldState.getValue(), newStates.get(oldState.getKey()))) {
                    matches = false;
                    break;
                }
            }
            if (!matches) {
                continue;
            }
            boolean sawNewConnection = false;
            for (Map.Entry<String, Object> added : newStates.entrySet()) {
                if (oldStates.containsKey(added.getKey())) {
                    continue;
                }
                final String prefix = "minecraft:connection_";
                if (!added.getKey().startsWith(prefix)) {
                    matches = false;
                    break;
                }
                sawNewConnection = true;
                String direction = added.getKey().substring(prefix.length());
                Boolean javaValue = javaDirection(javaId, direction);
                Object paletteValue = added.getValue();
                Boolean bedrockValue = paletteValue instanceof Number n ? n.intValue() != 0
                        : paletteValue instanceof Boolean b ? b : null;
                if (javaValue == null || !javaValue.equals(bedrockValue)) {
                    matches = false;
                    break;
                }
            }
            if (matches && sawNewConnection) {
                if (found != null) {
                    throw new IllegalStateException("Ambiguous Bedrock 26_60 " + blockName + " mapping for " + javaId);
                }
                found = entry.getValue();
            }
        }
        return found;
    }

    private static Boolean javaDirection(String javaId, String direction) {
        int start = javaId.indexOf('[');
        int end = javaId.indexOf(']', start + 1);
        if (start < 0 || end < 0) {
            return null;
        }
        String[] properties = javaId.substring(start + 1, end).split(",");
        for (String property : properties) {
            if (property.startsWith(direction + "=")) {
                String value = property.substring(direction.length() + 1);
                if ("true".equals(value)) {
                    return true;
                }
                if ("false".equals(value)) {
                    return false;
                }
                return null;
            }
        }
        return null;
    }

'''
s=s.replace(method_anchor,method+method_anchor)
p.write_text(s)
print('Added strict 26_60 fire/chorus state adapter and palette diagnostics')
PY_V4

# Keep Minecraft Java 26.2 pins, but use the updated Cloudburst Bedrock transport
# and codec libraries from the first attempt.
p = Path('gradle/libs.versions.toml')
s = p.read_text()
versions = {
    'protocol-connection': '3.0.0.Beta15-20261026.210753-2',
    'protocol-common': '3.0.0.Beta15-20261026.210753-2',
    'protocol-codec': '3.0.0.Beta15-20261026.210753-2',
    'network': '2.0.0.CR6-20261030.131938-23',
    'libdatachannel': '0.24.6.0-20261029.091642-10',
    'netty': '4.2.20.Final',
}
for key, value in versions.items():
    s, changes = re.subn(rf'(?m)^({re.escape(key)}\s*=\s*)"[^"]+"',
                         lambda m: m.group(1) + '"' + value + '"', s)
    if changes != 1:
        raise SystemExit(f'ERROR: expected one {key} dependency pin, saw {changes}')
for key, expected in {
    'minecraft': '26.2',
    'fabric-api': '0.152.0+26.2',
    'mcprotocollib': '26.2-20261009.175004-20',
}.items():
    if not re.search(rf'(?m)^{re.escape(key)}\s*=\s*"{re.escape(expected)}"', s):
        raise SystemExit(f'ERROR: Java 26.2 dependency changed: {key} expected {expected}')
p.write_text(s)
print('Preserved Java 26.2 pins; added Bedrock codec and assets.')
PY

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
