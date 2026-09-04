# Android emülatörü ve Firebase doğrulaması — 4 Eylül 2026

Ortam: Android 14 / API 34, `emulator-5554`, `sdk_gphone64_x86_64`.
Flutter 3.44.7; uygulama 2.0.2+34. Mağazalara yükleme yapılmadı.

## Firebase

- `gunluk-dua-hadis-15178` projesi native Firebase SDK üzerinden doğrulandı.
- Remote Config sürüm 1 yayımlandı. `app_update_android` ve `app_update_ios`
  JSON parametreleri `{"enabled":false}`. Her ikisi emülatöre uzak sunucu kaynağıyla
  ulaştı; güncelleme engeli oluşmadı. Yeni mağaza sürümü çıkana kadar kapalı kalmalı.
- `qa_emulator_verified` test olayı Analytics sunucusundan HTTP 204 aldı ve
  Firebase konsolunun DebugView ekranında görüldü.
- Test cihazı için Analytics debug modu kullanıldı. Bu, raporların anında
  güncellenmesini veya mağazadaki iOS sürümünün veri göndermesini doğrulamaz.
- iOS `GoogleService-Info.plist` dosyasının Xcode Resources bağlantısı mevcut.
  iOS düzeltmesinin cihazlara ulaşması yeni iOS derlemesinin yayımlanmasını gerektirir.

## Testler

- 118 birim/widget testi geçti.
- `emulator_test.dart`: üç test geçti. Gerçek Remote Config istekleri, gerçek Quran.com
  ses akışı, duraklat/devam, 3/5/10 tekrar, 113→114 otomatik geçiş ve konum kaydı.
- Alarm testi: İstanbul/cuma/öğle ve Ankara/pazartesi/imsak kuralları için 14 günlük
  sentetik vakitlerle dört Android bildirimi planlandı. Şehir ve vakit içerikleri
  native bildirim kuyruğunda kontrol edildi. Test kuralları ve önbellek geri alındı.
- Widget testi: gerçek Android RemoteViews 150×64, 250×80, 180×180, 280×140,
  340×150, 400×250 dp boyutlarında; 1x ve 2x yazı ölçeğinde çizildi.
  Görünür metinlerin sınırları, saatlerin kesilmemesi ve imsak verisi kontrol edildi.
- Görsel kontrolde küçük widget'ın imsak etiketindeki gereksiz boşluklar kaldırıldı.
  Düzeltme sonrası 12 boyut/yazı ölçeği bileşimi yeniden geçti; İmsak etiketinin
  kesilmediği ayrıca doğrulandı.
- Uygulama geçiş testi, Kur’an dinleme menüsünde eksik Material katmanını buldu;
  menüdeki dokunma efektinin görünmesi için düzeltildi.
- `navigation_test.dart` düzeltmeden sonra geçti: ana uygulamanın açılışı, Kur’an
  sekmesi ve dinleme sayfası, İstanbul şehir seçimi, Namaz sekmesinden alarm
  sayfası, Mesajlar, Diğer ve Ana Sayfa geçişleri doğrulandı.
- Flutter hata işleyicisi önceki hata işleyicisini de çağırıyor; test ve debug
  hataları artık Crashlytics işleyicisi tarafından gizlenmiyor.
- Doğrulama sonunda emülatörün Analytics debug modu ve ayrıntılı Analytics
  günlükleri kapatıldı.

## Tekrar çalıştırma

Emülatör açık ve uygulamanın bildirim izni verilmiş olmalı. `--no-uninstall`
önemlidir: Flutter'ın varsayılan test temizliği uygulamayı kaldırabilir.
İlk çalıştırmada bu varsayılan temizleme gerçekleşti; emülatörün önceki yerel
ayarları silinmiş olabilir. Sonraki çalıştırmalarda temizleme kapatıldı.

```powershell
flutter test test --no-pub
flutter test integration_test/emulator_test.dart -d emulator-5554 --no-uninstall
flutter test integration_test/navigation_test.dart -d emulator-5554 --no-uninstall
```

Test APK'sı günlük kullanım için bırakılmamalı; testler bitince `lib/main.dart`
hedefiyle normal debug uygulaması yeniden derlenip kurulmalı.

Bu çalışmanın sonunda normal `lib/main.dart` debug APK'sı başarıyla derlendi,
emülatöre kuruldu ve açıldı. Yalnız instrumentation test paketinin kurulumu kaldırıldı.
Normal uygulama emülatörde çalışır durumda bırakıldı.

## Fiziksel cihaz kontrolü gerekenler

- Android launcher üzerinde widget'ı elle yeniden boyutlandırma ve üretici farkları.
- Ekran kapalıyken ses, kilit ekranı medya düğmeleri, telefon çağrısıyla ses kesilmesi.
- Alarmın gerçek vaktinde teslim edilmesi; Doze, pil tasarrufu, yeniden başlatma.
- iPhone/TestFlight üzerinde Analytics olayları, arka plan ses ve tüm WidgetKit boyutları.

Kaynaklar: [Firebase DebugView](https://firebase.google.com/docs/analytics/debugview),
[Flutter integration testing](https://docs.flutter.dev/testing/integration-tests).
