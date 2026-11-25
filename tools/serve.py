# Serves ../web on 127.0.0.1:8765 for the preview scripts, with caching disabled so edits show up.
import functools
import http.server
import os


class NoCache(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


web = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "web")
handler = functools.partial(NoCache, directory=web)
http.server.ThreadingHTTPServer(("127.0.0.1", 8765), handler).serve_forever()
