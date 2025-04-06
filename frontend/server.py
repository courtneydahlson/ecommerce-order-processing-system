from http.server import HTTPServer, SimpleHTTPRequestHandler

# Define the server address and port
host = 'localhost'
port = 8080

# Create the HTTP server
server = HTTPServer((host, port), SimpleHTTPRequestHandler)

print(f"Server running on http://{host}:{port}")
try:
    # Start the server
    server.serve_forever()
except KeyboardInterrupt:
    print("\nShutting down the server...")
    server.server_close()