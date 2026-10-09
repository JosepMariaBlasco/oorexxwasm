/* json.cls ships with ooRexx and is preloaded here, like the other       */
/* extension classes: ::REQUIRES finds it in REXX_PATH.                   */
text = '{"name": "ooRexx", "version": 5.3, "tags": ["rexx", "oo", "wasm"],',
       '"threads": true}'
d = .json~fromJSON(text)
say "name:   " d["name"]
say "version:" d["version"]
say "tags:   " d["tags"]~makeString("L", ", ")
say "threads:" d["threads"]

d["engine"] = "WebAssembly"
d["tags"]~append("browser")
say
say .json~toJSON(d)
::requires "json.cls"
