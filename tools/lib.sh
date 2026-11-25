# Shared by the render scripts in tools/. Source it after setting TAB (a built-in browser tab id).
# The scene is served by `python3 tools/serve.py` on 127.0.0.1:8765.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Runs JavaScript in the tab, e.g. `js "cat.reset(); return 1"`.
js() { cxb browser js "$1" --tab "$TAB" >/dev/null; }

# open_scene <width> <height> [query]: sizes the tab and loads the dev scene on the test background.
# The timestamp defeats any cached copy of the page.
open_scene() {
    cxb browser viewport --width "$1" --height "$2" --tab "$TAB" >/dev/null
    cxb browser goto "http://127.0.0.1:8765/index.html?dev&nopointer&bg=f8d987${3:+&$3}&v=$(date +%s)" --tab "$TAB" >/dev/null
    sleep 1
}

# snap <file.png>: screenshots the tab.
snap() { cxb browser screenshot --tab "$TAB" --out "$1" >/dev/null; }
