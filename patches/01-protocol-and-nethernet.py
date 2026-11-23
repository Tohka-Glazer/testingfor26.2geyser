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
