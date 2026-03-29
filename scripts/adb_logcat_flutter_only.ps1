# Ikinci terminalde calistirin; birinci terminalde normal "flutter run" kullanin (hot reload bozulmaz).
# Sistem/Ads/chromium loglarini gostermez; yalnizca flutter etiketli satirlar.
$ErrorActionPreference = "Continue"
Write-Host "Yalnizca flutter loglari (Ctrl+C ile cik). Uygulama zaten calisiyor olmali." -ForegroundColor Cyan
adb logcat -c
adb logcat -v brief 'flutter:I' '*:S'
