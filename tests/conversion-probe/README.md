# Conversion probe

`edges.rex` sends edge values across the JavaScript bridge (`.JSObject`) in
both directions and prints, one per line, what was sent and what arrived:
numbers and strings that look like numbers, `.Boolean`, `.nil`, Arrays,
Directories, Rexx objects as RexxProxy, binary strings, errors.
`edges.out` is its expected output.

The ooRexx bridges (Python, .NET, Lua, JavaScript, BSF4ooRexx's Java) keep
a common table of their conversion rules, measured with one such probe per
bridge; this is the JavaScript bridge's. `tests/qualify.sh` runs it with the
Node command-line build (`bin-node/rexx`) and fails when the output differs
from `edges.out`; the same `js.cls` and bridge code run in the browser
builds.

When a conversion changes on purpose, regenerate the expected output in the
same commit:

```bash
BUILD/bin-node/rexx tests/conversion-probe/edges.rex > tests/conversion-probe/edges.out
```

The output must stay stable: no addresses, hashes, timings or paths.
