# Installing ooRexx for WebAssembly

ooRexx 5.3.0 (SVN trunk with the patches in [`patches/`](patches/)) compiled
to WebAssembly. An experimental port, not an official RexxLA distribution.
There are three ways to get it:

| You want | Get |
|---|---|
| ooRexx under Node.js, as a command (`rexx-wasm program.rex`) | the npm package [`oorexxwasm`](https://www.npmjs.com/package/oorexxwasm) |
| ooRexx in your web pages | `oorexxwasm-web-X.Y.Z.zip`, from the [releases](https://github.com/JosepMariaBlasco/oorexxwasm/releases) |
| the [ooRexx Playground](https://rexx.epbcn.com/oorexx-wasm/) on your own server | `oorexxwasm-playground-X.Y.Z.zip`, from the releases |
| to build it, change it, or run the tests | the source: see [Building from source](#building-from-source) |

## Node.js

Linux, macOS or Windows, with Node.js 22 or later:

```bash
npm install -g oorexxwasm
rexx-wasm -v
rexx-wasm program.rex
```

The commands are `rexx-wasm`, `rexxc-wasm`, `rxqueue-wasm` and
`rxsubcom-wasm`, and also `rexx`, `rexxc`, `rxqueue` and `rxsubcom`. The
`-wasm` names never clash with a native ooRexx; with the plain names,
whichever comes first in `PATH` runs. Without installing:
`npx -p oorexxwasm rexx program.rex`. To remove it: `npm uninstall -g oorexxwasm`.

Programs use the host's files, environment and commands, real TCP/UDP
sockets, and a RexxAPI daemon shared between processes, as native ooRexx
does. The package's [README](npm/README.md) has the details, also for
Windows.

## Web pages

Download `oorexxwasm-web-X.Y.Z.zip` from the
[releases](https://github.com/JosepMariaBlasco/oorexxwasm/releases), unpack
it, and, with Node.js 18 or later:

```bash
cd oorexxwasm-web-X.Y.Z
node serve.mjs              # then open http://localhost:8000/
```

`index.html` is an example page: its `<script type="text/rexx">` elements
set the page's text, handle a button, and define a routine that the page's
JavaScript calls. It is also
[online](https://rexx.epbcn.com/oorexx-wasm/example/). Its `README.md` lists the files and shows the API.

To use ooRexx in your own pages, copy the seven interpreter files
(`ooRexx.js`, `ooRexx-worker.js`, `rexx.js`, `rexx.wasm`, `rexx.data`,
`js-realm.js`, `polygon-clipping.umd.min.js`) together into your site, and
load `ooRexx.js`:

```html
<script src="ooRexx.js"></script>
<script type="text/rexx">
  .js~page~document~getElementById("greeting")~textContent = "Hello from Rexx"
</script>
```

[*ooRexx/WASM and JavaScript*](docs/ooRexx-WASM-and-JavaScript.md) specifies
how Rexx reaches JavaScript and the page, and how the page runs Rexx.

### The headers every page needs

The interpreter uses threads, which browsers only allow in a *cross-origin
isolated* page. The page, and the files it loads, must be served with

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

and `rexx.wasm` as `application/wasm`. Without these headers ooRexx does not
start, and the browser's console says *ooRexx/WASM needs a cross-origin
isolated page*; opening a page as a file (`file://`) does not work either. With them, whatever the page
loads from other sites (scripts, fonts, images) must be sent by those sites
with `Cross-Origin-Resource-Policy: cross-origin` or CORS; files of your own
site are fine. Current Chrome, Edge, Firefox and Safari all work.

**Apache 2.4.** The zips include a `.htaccess` that sets everything. It
needs `mod_headers` (and uses `mod_deflate` if present: the files compress
to about 40%), and the directory must allow `.htaccess` overrides of type
`FileInfo` (`AllowOverride FileInfo`), or put the same directives in the
server's configuration. Check with:

```bash
curl -sI https://your.site/path/rexx.wasm | grep -i -E 'cross-origin|content-type'
```

**nginx.**

```nginx
location /path/ {
    add_header Cross-Origin-Opener-Policy same-origin always;
    add_header Cross-Origin-Embedder-Policy require-corp always;
    add_header Cross-Origin-Resource-Policy same-origin always;
}
```

(`mime.types` maps `.wasm` to `application/wasm` in current nginx; add
`application/wasm wasm;` to it if yours does not. `add_header` in a
`location` replaces the ones it would inherit: repeat those there.)

**Caddy.**

```
header /path/* {
    Cross-Origin-Opener-Policy same-origin
    Cross-Origin-Embedder-Policy require-corp
}
```

**Netlify, Cloudflare Pages:** a `_headers` file at the root of the site:

```
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
```

Hosts that do not let you set response headers, such as GitHub Pages, cannot
serve ooRexx pages.

## The Playground

`oorexxwasm-playground-X.Y.Z.zip` is the
[ooRexx Playground](https://rexx.epbcn.com/oorexx-wasm/) site, ready to copy
to a web server as is (`.htaccess` included; the headers above apply). To try
it locally: `node serve.mjs` in the unpacked directory. How it is built:
[`playground/README.md`](playground/README.md).

## Building from source

Linux (or WSL), with `bash`, `svn`, `python3`, `curl`, `zip` and Node.js 22
or later:

```bash
git clone https://github.com/JosepMariaBlasco/oorexxwasm
oorexxwasm/scripts/setup-env.sh
```

This checks out ooRexx at the base revision, applies the patches and installs
prebuilt binaries when they match the patches (otherwise it installs
Emscripten and compiles). See [the README](README.md#getting-started). Then
`scripts/npm-package.sh VERSION` and `scripts/web-package.sh VERSION` build
the npm package and the two zips from your build, and `tests/qualify.sh`
checks everything.
