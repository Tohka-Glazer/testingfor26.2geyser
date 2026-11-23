#!/usr/bin/env bash
# EXPERIMENTAL backport attempt; this has NOT been compiled or tested.
# Uses MIT-licensed upstream GeyserMC source; no ViaVersion dependency is added.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
if [[ -e geyser-src ]]; then
  echo 'ERROR: geyser-src already exists; delete it to start over.' >&2
  exit 1
fi

# bbd7e67: last known source revision corresponding to Geyser-Fabric 2.11.3-b1254, Java 26.2.
git clone https://github.com/GeyserMC/Geyser.git geyser-src
cd geyser-src
git checkout --detach bbd7e67

# Backport Geyser's large Bedrock 26.60 implementation, including Bedrock assets.
# An unsuccessful cherry-pick stops here rather than silently creating an invalid jar.
git -c user.email='local-build@example.invalid' -c user.name='Local Backport' cherry-pick --no-commit fd35d59

# Geyser's 26.66 change is a registration on top of the 26.60 codec.
python3 - <<'PY'
from pathlib import Path
import re
p = Path('core/src/main/java/org/geysermc/geyser/network/bedrock/GameProtocol.java')
s = p.read_text()
old = 'register(Bedrock_v2225.CODEC, "26.60");'
new = 'register(Bedrock_v2225.CODEC, "26.60", "26.61", "26.62", "26.63", "26.64", "26.65", "26.66");'
if s.count(old) != 1:
    raise SystemExit('ERROR: Bedrock_v2225 registration not found exactly once; inspect source changes.')
p.write_text(s.replace(old, new))

# IMPORTANT: Keep the Java 26.2 McProtocolLib version and Fabric API/Minecraft pins.
# Bring in Bedrock 26.60 Cloudburst libraries and its newer transport as used upstream.
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
        raise SystemExit(f'ERROR: Expected exactly one {key} pin; found {changes}.')
for key, expected in {
    'minecraft': '26.2', 'fabric-api': '0.152.0+26.2',
    'mcprotocollib': '26.2-20261009.175004-20',
}.items():
    if not re.search(rf'(?m)^{re.escape(key)}\s*=\s*"{re.escape(expected)}"', s):
        raise SystemExit(f'ERROR: Expected Java 26.2 pin {key}={expected}.')
p.write_text(s)
print('Protocol versions patched; Java 26.2 dependencies preserved.')
PY

git submodule update --init --recursive

# Build fabric distribution only. Gradle should produce Geyser-Fabric.jar.
chmod +x gradlew
./gradlew :fabric:build --no-daemon --stacktrace
artifact=bootstrap/mod/fabric/build/libs/Geyser-Fabric.jar
if [[ ! -s "$artifact" ]]; then
  echo "ERROR: missing or empty build output at $artifact" >&2
  exit 1
fi
mkdir -p "$ROOT/out"
cp "$artifact" "$ROOT/out/Geyser-Fabric-Java26.2-Bedrock26.66-EXPERIMENTAL.jar"
sha256sum "$ROOT/out/"*.jar
printf '\nBUILT but NOT verified with a running 26.2 Minecraft server or Bedrock client.\n'
