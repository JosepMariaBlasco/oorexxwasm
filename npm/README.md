# oorexxwasm

[ooRexx](https://www.oorexx.org/) 5.3.0 (SVN trunk r13344) compiled to
WebAssembly, for Node.js 22 or later: `rexx`, `rexxc`, `rxqueue` and
`rxsubcom`. It runs on Linux, macOS and Windows.

This is an experimental port, not an official distribution of the Rexx
Language Association. The port, its patches and its documentation are at
[github.com/JosepMariaBlasco/oorexxwasm](https://github.com/JosepMariaBlasco/oorexxwasm),
and it can be tried in a browser at
[rexx.epbcn.com/oorexx-wasm](https://rexx.epbcn.com/oorexx-wasm/).

## Install

```bash
npm install -g oorexxwasm
rexx -v
rexx myprogram.rex
```

Or without installing: `npx -p oorexxwasm rexx myprogram.rex`.

If a native ooRexx is installed, its `rexx` and this one have the same name,
and whichever comes first in `PATH` runs (npm only refuses to replace a
command it did not install in its own directory). The same commands are
also installed as `rexx-wasm`, `rexxc-wasm`, `rxqueue-wasm` and
`rxsubcom-wasm`, which never clash with a native ooRexx:

```bash
rexx-wasm myprogram.rex
```

## What works

Programs use the host's files, environment and commands as native ooRexx
does. Sockets are real TCP and UDP. Queues, registrations and the
macrospace are shared between processes through a daemon, as with native
`rxapi`. The extension classes (`socket.cls`, `json.cls`, `yaml.cls`,
`csvStream.cls`, `dateparser.cls`, `rxftp.cls`, `smtp.cls`, ...) are
included.

On Windows, file names are Windows names written with forward slashes
(`C:/Users/me/data.txt`; backslashes are accepted too), `PATH`-like lists
are separated by `;`, environment variable names are not case-sensitive,
and commands go to `cmd.exe`: the initial `ADDRESS` environment is `CMD`,
as with ooRexx for Windows. Windows-only parts of ooRexx (OLE, ooDialog,
`winsystm.cls`) are not included.

JavaScript, and Node's modules, are available from Rexx with
`::requires "js.cls"`:

```rexx
say .js~Math~max(3, 7)                        -- 7
fs = .js~require("node:fs")
say fs~readFileSync("data.txt", "utf8")
::requires "js.cls"
```

See [the specification](https://github.com/JosepMariaBlasco/oorexxwasm/blob/main/docs/ooRexx-WASM-and-JavaScript.md).

## License

ooRexx is distributed under the Common Public License 1.0 (`CPLv1.0.txt`).
