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
     * Adapt Java 26.2-era fire, chorus, and redstone-wire block states to the
     * Bedrock 26.60 palette. Match against the palette itself; never guess a
     * runtime ID, or silently degrade to a different block state.
     */
    private static GeyserBedrockBlock findDirectional26_60Block(NbtMap source, String javaId,
                                                                  Map<NbtMap, GeyserBedrockBlock> palette) {
        String blockName = source.getString("name");
        if ("minecraft:redstone_wire".equals(blockName)) {
            // Java 26.2 mapping NBT has redstone_signal but not the four
            // directional redstone_* properties required by Bedrock 26.60.
            // The Java block state has exactly the direction strings we need.
            NbtMapBuilder states = source.getCompound("states").toBuilder();
            for (String direction : new String[]{"north", "east", "south", "west"}) {
                String connection = javaBlockProperty(javaId, direction);
                if (!"none".equals(connection) && !"side".equals(connection) && !"up".equals(connection)) {
                    return null;
                }
                states.putString("redstone_" + direction, connection);
            }
            NbtMapBuilder corrected = source.toBuilder();
            corrected.putCompound("states", states.build());
            return palette.get(corrected.build());
        }
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

    private static String javaBlockProperty(String javaId, String propertyName) {
        int start = javaId.indexOf('[');
        int end = javaId.indexOf(']', start + 1);
        if (start < 0 || end < 0) {
            return null;
        }
        for (String property : javaId.substring(start + 1, end).split(",")) {
            if (property.startsWith(propertyName + "=")) {
                return property.substring(propertyName.length() + 1);
            }
        }
        return null;
    }

    private static Boolean javaDirection(String javaId, String direction) {
        String value = javaBlockProperty(javaId, direction);
        if ("true".equals(value)) {
            return true;
        }
        if ("false".equals(value)) {
            return false;
        }
        return null;
    }

'''
s=s.replace(method_anchor,method+method_anchor)
p.write_text(s)
print('Added strict Bedrock 26.60 redstone/fire/chorus state adapters and palette diagnostics')
