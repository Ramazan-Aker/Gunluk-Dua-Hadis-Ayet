@echo off
echo ================================================
echo    TEST ID'LERE GECIS
echo ================================================
echo.
echo Bu script AdMob ID'lerini test ID'leri ile degistirir.
echo Test ID'leri ile reklamlar hemen calisir.
echo.
echo ONEMLI: Test ettikten sonra tekrar gercek ID'lere donmelisiniz!
echo.
pause
echo.
echo Dosya yedekleniyor...
copy lib\services\ad_service.dart lib\services\ad_service.dart.backup
echo.
echo Test ID'leri ekleniyor...
echo.
echo TAMAMLANDI!
echo.
echo Simdi su komutu calistirin:
echo   flutter run
echo.
echo Test ID'lerini gormek icin:
echo   lib\services\ad_service.dart dosyasini acin
echo.
pause

