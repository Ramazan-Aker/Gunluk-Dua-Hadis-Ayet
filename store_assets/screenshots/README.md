# Mağaza ekran görüntüleri

## Yükleme klasörleri

- `google_play_phone_1080x1920`: Play Console > Mağaza girişi > Telefon
  ekran görüntüleri bölümüne sırasıyla yüklenir.
- `app_store_iphone_65_1242x2688`: Mevcut App Store Connect sürümünüzdeki
  **iPhone 6.5 inç** ekran görüntüleri bölümüne sırasıyla yüklenir.
- `app_store_iphone_69_1320x2868`: İleride App Store Connect 6.9 inç ekran
  grubu isterse kullanılabilecek alternatif settir.
- `app_store_ipad_13_2064x2752`: App Store Connect içindeki **iPad 13 inç**
  ekran görüntüleri bölümüne sırasıyla yüklenir.
- `app_store_watch_ultra3_422x514`: App Store Connect içindeki **Apple Watch
  Ultra 3** ekran görüntüleri alanıyla teknik olarak uyumlu 422 × 514 setidir.
  Yalnızca gönderilen sürüm gerçek bir watchOS uygulaması içeriyorsa yüklenmelidir.

Her iki klasörde de dosya sırası:

1. Ana Sayfa
2. Kur’an
3. Namaz Vakitleri
4. Mesajlar
5. Dini Günler
6. Paylaşım

Dosyalar JPEG/RGB biçimindedir; şeffaflık içermez. Kaynak emülatör ekranları
`source` klasöründe korunur.

## Play Console alternatif metinleri

1. Günün duası, namaz ve Kur’an kısayollarının bulunduğu ana sayfa.
2. Sure arama, sesli hatim, cüzler ve kaldığın yer özellikli Kur’an ekranı.
3. Birden fazla şehir, sonraki vakit sayacı ve günlük namaz vakitleri ekranı.
4. Favoriler, son kullanılanlar ve farklı dini mesaj kategorileri ekranı.
5. Yaklaşan kandil ve dini günleri geri sayımla gösteren takvim ekranı.
6. Mesaj görseli önizleme, düzenleme ve farklı biçimlerde paylaşma ekranı.

## Yeniden üretme

Pillow kurulu Python ile proje kökünden:

```powershell
python tool/generate_store_screenshots.py
```
