from pathlib import Path
import re

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
