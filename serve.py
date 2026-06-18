#!/usr/bin/env python3
import http.server
import socketserver
import webbrowser
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 9876
DIR = os.path.dirname(os.path.abspath(__file__))

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIR, **kwargs)
    def log_message(self, format, *args):
        try:
            print(f"[{self.log_date_time_string()}] {args[0]} {args[1]} {args[2]}")
        except: pass

if __name__ == '__main__':
    print(f"Server started at http://localhost:{PORT}")
    print(f"Open http://localhost:{PORT}/annotate.html in your browser")
    webbrowser.open(f"http://localhost:{PORT}/annotate.html")
    try:
        with socketserver.TCPServer(("", PORT), Handler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
