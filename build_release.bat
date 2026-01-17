@echo off
echo ================================================
echo    GUNLUK DUA ^& HADIS - PLAY STORE BUILD
echo ================================================
echo.

echo [1/5] Cache temizleniyor...
call flutter clean
echo.

echo [2/5] Dependencies yukleniyor...
call flutter pub get
echo.

echo [3/5] AAB (App Bundle) olusturuluyor...
echo Bu islem birka dakika surebilir...
call flutter build appbundle --release
echo.

if %ERRORLEVEL% EQU 0 (
    echo ================================================
    echo    BUILD BASARILI! 
    echo ================================================
    echo.
    echo AAB dosyasi konumu:
    echo build\app\outputs\bundle\release\app-release.aab
    echo.
    echo Bu dosyayi Play Store Console'a yukleyebilirsiniz.
    echo.
    echo ONEMLI: AndroidManifest.xml'de AdMob test ID'sini
    echo gercek ID ile degistirmeyi unutmayin!
    echo.
    echo Detayli bilgi icin: PLAY_STORE_YAYINLAMA.md
    echo ================================================
) else (
    echo ================================================
    echo    BUILD HATASI!
    echo ================================================
    echo.
    echo Hata ayiklama icin su komutu deneyin:
    echo flutter build appbundle --release --verbose
    echo ================================================
)

echo.
pause

