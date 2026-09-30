import uuid
import base64
import os

icon_path = r"C:\Users\User\.gemini\antigravity\scratch\Antigravity-iOS\AppIcon512.png"
with open(icon_path, "rb") as f:
    icon_b64 = base64.b64encode(f.read()).decode("utf-8")

payload_uuid_1 = str(uuid.uuid4()).upper()
payload_uuid_2 = str(uuid.uuid4()).upper()

mobileconfig_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ConsentText</key>
    <dict>
        <key>default</key>
        <string>Profil ini memasang Google Antigravity sebagai Web App mandiri (Full Screen Standalone) di Layar Utama iPhone Anda tanpa batas kadaluarsa 7 hari.</string>
    </dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>FullScreen</key>
            <true/>
            <key>Icon</key>
            <data>
{icon_b64}
            </data>
            <key>IsRemovable</key>
            <true/>
            <key>Label</key>
            <string>Google Antigravity</string>
            <key>PayloadDescription</key>
            <string>Menambahkan Google Antigravity ke Home Screen sebagai WebClip Fullscreen</string>
            <key>PayloadDisplayName</key>
            <string>Google Antigravity WebClip</string>
            <key>PayloadIdentifier</key>
            <string>com.google.antigravity.webclip</string>
            <key>PayloadType</key>
            <string>com.apple.webClip.managed</string>
            <key>PayloadUUID</key>
            <string>{payload_uuid_1}</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>Precomposed</key>
            <true/>
            <key>URL</key>
            <string>https://antigravity.google</string>
        </dict>
    </array>
    <key>PayloadDescription</key>
    <string>Profil instalasi Web App Google Antigravity untuk iOS</string>
    <key>PayloadDisplayName</key>
    <string>Google Antigravity</string>
    <key>PayloadIdentifier</key>
    <string>com.google.antigravity.ios.profile</string>
    <key>PayloadOrganization</key>
    <string>Google Antigravity</string>
    <key>PayloadRemovalDisallowed</key>
    <false/>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>{payload_uuid_2}</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
"""

out_path = r"C:\Users\User\.gemini\antigravity\scratch\Antigravity-iOS\GoogleAntigravity.mobileconfig"
with open(out_path, "w", encoding="utf-8") as f:
    f.write(mobileconfig_content)

print(f"Created {out_path} ({os.path.getsize(out_path)} bytes)")
