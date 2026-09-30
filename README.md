# Google Antigravity for iOS (iPhone / iPad)

Proyek ini menyediakan solusi lengkap untuk menjalankan **Google Antigravity** sebagai aplikasi mandiri di iOS (iPhone 11, iOS 18.x) tanpa harus terus-menerus membuka browser Safari yang berat dengan tab dan address bar.

---

## 🚀 3 Cara Menjalankan Google Antigravity di iPhone

### Cara 1: Standalone PWA (Paling Cepat, Ringan & Tanpa Kadaluarsa 7 Hari) — ⭐ DIREKOMENDASIKAN
Apple iOS mendukung Progressive Web App yang dapat berjalan **fullscreen** tanpa bar URL Safari dan tanpa frame browser:
1. Buka **Safari** di iPhone Anda.
2. Akses `https://antigravity.google`.
3. Tekan ikon **Bagikan (Share)** di bagian bawah (ikon kotak dengan panah panah ke atas).
4. Gulir ke bawah lalu pilih **"Tambahkan ke Layar Utama" (Add to Home Screen)**.
5. Beri nama **Antigravity** lalu tekan **Tambah (Add)** di pojok kanan atas.
6. **Selesai!** Ikon Antigravity akan muncul di Home Screen iPhone Anda. Saat dibuka, aplikasi akan berjalan penuh (fullscreen) layaknya aplikasi native tanpa tampilan browser.

---

### Cara 2: Install Profil WebClip (`GoogleAntigravity.mobileconfig`)
Kami sudah membuat file konfigurasi Apple Profile `GoogleAntigravity.mobileconfig` yang secara otomatis mengunci tampilan ke mode Fullscreen mandiri:
1. Kirim file `GoogleAntigravity.mobileconfig` ke iPhone Anda (via iCloud Drive, Google Drive, WhatsApp, Telegram, atau AirDrop).
2. Ketuk file tersebut di iPhone -> pilih **Izinkan (Allow)** saat muncul notifikasi unduh profil.
3. Buka **Pengaturan (Settings)** di iPhone -> ketuk **Profil Diunduh (Profile Downloaded)** di bagian paling atas.
4. Ketuk **Pasang (Install)** di pojok kanan atas -> masukkan PIN iPhone Anda -> ketuk **Pasang**.
5. Ikon aplikasi langsung terpasang di Home Screen dengan logo Antigravity.

---

### Cara 3: Build & Sideload `.ipa` (Sideloadly / AltStore)
Jika Anda tetap ingin file biner `.ipa` murni untuk di-sideload:
1. Repositori ini sudah dilengkapi dengan kode native Swift/WebKit (`Antigravity/`) dan **GitHub Actions Workflow** (`.github/workflows/build-ipa.yml`).
2. Buat repositori baru di akun GitHub Anda dan push folder ini.
3. Buka tab **Actions** di GitHub -> workflow **Build Antigravity iOS IPA** akan berjalan otomatis di mesin macOS Apple Cloud.
4. Setelah selesai (sekitar 1-2 menit), unduh artifact `GoogleAntigravity.ipa`.
5. Buka **Sideloadly** atau **AltStore** di komputer -> hubungkan iPhone 11 Anda via kabel USB -> drag and drop `GoogleAntigravity.ipa` -> Masukkan Apple ID untuk install ke iPhone.

> ⚠️ **Catatan Penting untuk iOS 18:**
> Pada iOS 18, TrollStore tidak dapat digunakan (Apple telah menambal bug CoreTrust). Sideload menggunakan AltStore atau Sideloadly gratis memiliki batas masa aktif sertifikat 7 hari (aplikasi harus di-refresh tiap minggu). Oleh karena itu, **Cara 1 (PWA)** atau **Cara 2 (MobileConfig)** jauh lebih praktis dan permanen untuk penggunaan harian.
