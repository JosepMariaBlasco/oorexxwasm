# RFE #879 update, 11 October 2026: the five patches on Emscripten 6.0.12, tested on r13268

## What changed

The series now targets **Emscripten 6.0.12** (it was 6.0.9). Since 6.0.9,
Emscripten has fixed two problems the port worked around, so the series
drops both workarounds:

- `gethostbyname()` under `-sPROXY_TO_PTHREAD`: Emscripten 6.0.12 runs the
  fake-DNS lookup on the main thread itself
  ([emscripten-core/emscripten#27889](https://github.com/emscripten-core/emscripten/pull/27889)).
  Patch 1 no longer carries `wasm/emscripten-dns-proxy.js`.
- `fstat()` on the standard streams under NODERAWFS: fixed in Emscripten
  6.0.10 ([#27632](https://github.com/emscripten-core/emscripten/pull/27632)).
  Patch 2's `wasm/node-pre.js` no longer wraps `FS.fstat`.

Patch by patch:

- **Patch 1**: the workaround above is removed. The CMake cache is now
  `cmake/wasm-emscripten-6.0.12-cache.cmake` (same contents), and the build
  instructions in `wasm/README.md` say 6.0.12. `wasm/tests/qualify-node.sh`
  used to sleep half a second after starting its WebSocket echo server, which
  was too short on a loaded machine. It now waits until the server accepts
  connections.
- **Patch 2**: the `fstat` workaround is removed.
- **Patch 3**: no change (only the index lines and hunk offsets differ).
- **Patch 4**: real name resolution under Node (`orxNodeResolve`) moves to
  its own file, `wasm/node-resolve.js`. It is still needed: with real sockets,
  `gethostbyname()` still uses Emscripten's fake DNS
  ([#27887](https://github.com/emscripten-core/emscripten/issues/27887),
  open). Also, `wasm/node-sockets-pre.js` is ready for the next Emscripten
  release, whose socket backend rejects options it does not model
  ([#27921](https://github.com/emscripten-core/emscripten/pull/27921)).
- **Patch 5**: no change (only the index lines and hunk offsets differ).

The patches apply cleanly to trunk **r13268**, in order, with `svn patch`
or `git apply`. Everything was rebuilt there with Emscripten 6.0.12 and
retested. They still apply to r13254 as well; the baseline line in
`wasm/README.md` still says r13254.

## The patches

[`patches/` at commit 776747a](https://github.com/JosepMariaBlasco/oorexxwasm/tree/776747a/patches):
0001–0005 are the RFE, and `SHA256SUMS` lists their hashes. 0006–0010 build
on them and are not part of the RFE.

## Results on r13268

Official test suite, test/trunk r13268:

| platform | groups ok (of 402) | tests ran | failures | errors |
|---|---:|---:|---:|---:|
| native (Linux, series applied) | 400 | 24,283 | 2 | 0 |
| Node.js command line | 391 | 23,435 | 5 | 8 |
| Chromium | 366 | 23,427 | 84 | 81 |
| Firefox | 366 | 23,427 | 84 | 81 |
| WebKit | 366 | 23,427 | 84 | 81 |

There were no crashes and no timeouts on any platform. The results match the
same series built with Emscripten 6.0.9 exactly, group by group.

The suite now runs in this repository's CI (GitHub Actions,
[`suite.yml`](../../.github/workflows/suite.yml)), one job per platform. Each
job compares its results with the reference in [`results/`](../../results)
and fails on any regression. Compared with the update of 8 October (r13263,
posted on SourceForge):

- *POS runs fewer tests*: r13268 rewrote that group (67 tests instead of 103).
- *File, Stream and SysFileXXX now pass natively and under Node.* The CI
  runs the suite as an ordinary user. As root, as before, some of their
  tests fail.
- *TRACE passed under Node and in Chromium this time.* It depends on timing,
  as noted before.
- *WebKit: CALL fails on the CI machines.* Their WebKit allows only about
  3,600 levels of recursion, and the test needs more.

Everything else that fails has the causes listed before.

## Files

- [`results/suite-platforms.md`](results/suite-platforms.md): the
  side-by-side table, with the cause of every group that does not pass
  everywhere (also as [CSV](results/suite-platforms.csv)). The causes come
  from [`tests/suite-browser/known.tsv`](../../tests/suite-browser/known.tsv).
- The results of each platform as CSV:
  [native](results/suite-native.csv), [Node](results/suite-node.csv),
  [Chromium](results/suite-chromium.csv), [Firefox](results/suite-firefox.csv),
  [WebKit](results/suite-webkit.csv).
