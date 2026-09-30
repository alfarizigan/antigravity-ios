@echo off
echo ========================================================
echo   Push Google Antigravity iOS ke GitHub @alfarizigan
echo ========================================================
echo.

cd /d "%~dp0"

echo Memeriksa remote origin...
git remote remove origin 2>nul
git remote add origin https://github.com/alfarizigan/antigravity-ios.git

echo.
echo Melakukan Push ke https://github.com/alfarizigan/antigravity-ios ...
echo Jendela browser atau autentikasi mungkin akan muncul sebentar untuk konfirmasi.
echo.

git push -u origin main

echo.
if %ERRORLEVEL% EQU 0 (
    echo ========================================================
    echo   BERHASIL! Kode berhasil di-push ke GitHub!
    echo   Buka: https://github.com/alfarizigan/antigravity-ios/actions
    echo   untuk melihat proses kompilasi IPA otomatis!
    echo ========================================================
) else (
    echo ========================================================
    echo   Gagal push. Pastikan repo 'antigravity-ios' sudah dibuat
    echo   di https://github.com/new terlebih dahulu.
    echo ========================================================
)
echo.
pause
