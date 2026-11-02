"""Every file a player downloads must fit Windows' 260-character path limit.

The client unpacks a server's resources to
  <game>\\red4ext\\plugins\\Open77\\cache\\server-resources\\sets\\<64-hex digest>\\resources\\<resource>\\<file>
and opens them with plain paths (no \\\\?\\ prefix). A default Steam install
(C:\\Program Files (x86)\\Steam\\steamapps\\common\\Cyberpunk 2077\\, 61 characters)
leaves 259 - 61 - 126 = 72 characters for "<resource>\\<file>"; a longer one fails
the resource's discovery and the whole server with resource_activation_failed
(2026-11-02: op77_ripperdoc's cw_integumentary_neuroactivearmor_capacitors.webp).
LIMIT keeps a few characters for deeper Steam libraries.

    python tools/test-resource-paths.py
"""
import sys
from pathlib import Path

LIMIT = 68
root = Path(__file__).resolve().parents[1] / 'resources'
resources = sorted({p.parent for p in root.rglob('open77.lua')})
worst, failures, count = (0, ''), [], 0
for resource in resources:
    for f in resource.rglob('*'):
        if not f.is_file():
            continue
        count += 1
        rel = resource.name + '\\' + str(f.relative_to(resource))
        if len(rel) > worst[0]:
            worst = (len(rel), rel)
        if len(rel) > LIMIT:
            failures.append(rel)
for rel in failures:
    print('TOO LONG (%d > %d): %s' % (len(rel), LIMIT, rel))
if failures:
    sys.exit('FAIL: %d path(s) over %d characters; shorten the file names' % (len(failures), LIMIT))
print('PASS: %d files in %d resources, longest %d characters (%s)' % (count, len(resources), worst[0], worst[1]))
