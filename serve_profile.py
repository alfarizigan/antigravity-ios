import http.server
import socketserver
import os

PORT = 8080
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class MobileConfigHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def guess_type(self, path):
        if path.endswith(".mobileconfig"):
            return "application/x-apple-aspen-config"
        return super().guess_type(path)

if __name__ == "__main__":
    with socketserver.TCPServer(("", PORT), MobileConfigHandler) as httpd:
        print(f"Server berjalan di port {PORT}")
        print(f"Buka tautan ini di Safari iPhone Anda (pastikan terhubung ke Wi-Fi yang sama):")
        print(f"http://192.168.18.2:{PORT}/GoogleAntigravity.mobileconfig")
        print("Tekan Ctrl+C untuk berhenti.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nServer dihentikan.")
