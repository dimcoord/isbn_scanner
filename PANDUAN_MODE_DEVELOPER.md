# 🛠️ Panduan Masuk ke Mode Developer (Pengaturan API & IP Server)
**Aplikasi: Perpus Dupat Scanner (SMAN 24 Bandung)**

---

## 📌 Mengapa Mode Ini Disembunyikan?
Untuk keperluan uji coba di sekolah (SMAN 24 Bandung), antarmuka publik dibuat **bersih & profesional**:
- Pengguna umum (siswa / petugas pemindai) hanya melihat **2 tab utama**:
  1. **Pindai ISBN** (Kamera Scanner & Input Manual)
  2. **Riwayat Buku** (Daftar buku hasil scan & status sinkronisasi)
- Tab **API Config** sengaja disembunyikan dari navigasi bawah agar pengguna tidak sengaja mengubah IP server atau token otentikasi.

---

## 🚀 Cara Membuka Mode Developer

Ada **2 cara mudah** bagi developer/admin/penguji untuk membuka pengaturan API:

### 🔹 Cara 1: Ketuk Judul 5x Berturut-turut (Secret Tap) — *Paling Direkomendasikan*
1. Masuk ke halaman utama kamera pemindai (**Pindai ISBN**).
2. Perhatikan teks judul di bagian atas layar:  
   👉 **`Perpus Dupat Scanner`** (kotak kapsul gelap di tengah atas).
3. **Ketuk / tap kotak judul tersebut sebanyak 5 kali berturut-turut** dengan cepat (dalam rentang waktu 2.5 detik).
4. Ponsel akan bergetar dan memunculkan pesan:
   > *🔓 Mode Developer: Membuka Pengaturan API...*
5. Halaman **Konfigurasi API Laravel** akan langsung terbuka otomatis.

---

### 🔹 Cara 2: Lewat Tombol Info Aplikasi (Alternatif)
Jika Anda lupa ketukan atau butuh cara visual:
1. Di halaman **Pindai ISBN**, klik ikon info **`( i )`** di pojok kiri atas.
2. Pada jendela popup *Perpus Dupat Scanner* yang muncul, klik tombol:  
   👉 **`Konfigurasi API / IP (Developer)`**
3. Halaman pengaturan API akan langsung terbuka.

---

## ⚙️ Apa Saja yang Bisa Diatur di Mode Ini?
Di halaman pengaturan ini, Anda dapat:
1. **IP Server / Host**: Ubah IP sesuai dengan IP laptop server di jaringan WiFi sekolah (misal `192.168.1.100` atau `10.x.x.x`).
2. **Port**: Default `8000`.
3. **API Token (Sanctum)**: Token otentikasi API Laravel untuk sinkronisasi buku.
4. **Uji Koneksi (Test Connection)**: Memastikan HP dan server Laravel terhubung dengan baik sebelum memindai buku.

---

## 💡 Tips Penting untuk Uji Coba Besok di Sekolah:
1. **Pastikan Laptop & HP Terhubung ke WiFi yang Sama** (atau gunakan Hotspot HP ke Laptop).
2. **Cek IP Laptop**:
   Buka terminal/PowerShell di laptop dan ketik:
   ```powershell
   ipconfig
   ```
   Cari alamat `IPv4 Address` pada adapter WiFi yang terhubung (misal `192.168.1.45`).
3. **Jalankan Server Laravel dengan Host 0.0.0.0**:
   ```bash
   cd d:\perpus24\perpusdupat
   php artisan serve --host=0.0.0.0 --port=8000
   ```
4. **Buka Mode Developer di HP**, ganti IP dengan IP laptop tersebut, lalu klik **Simpan & Uji Koneksi**. Jika status *Online*, aplikasi siap digunakan untuk pemindaian!
