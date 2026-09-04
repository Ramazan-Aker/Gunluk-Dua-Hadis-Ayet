# Uygulama güncelleme yönetimi

Android ve iOS için güncelleme hatırlatması ve zorunlu güncelleme ekranı eklendi.
Varsayılan olarak kapalıdır. Önce bu kodu içeren sürüm mağazalarda yayımlanmalıdır.
Bu mekanizmayı içermeyen eski kurulumlara uzaktan güncelleme ekranı gönderilemez.

## Firebase'den etkinleştirme

4 Eylül 2026: `gunluk-dua-hadis-15178` projesinde Remote Config sürüm 1
yayımlandı. `app_update_android` ve `app_update_ios` JSON parametreleri
`{"enabled":false}` değeriyle oluşturuldu. Android emülatör testi iki değeri de
`ValueSource.valueRemote` kaynağından aldı ve güncelleme ekranının açılmadığını
doğruladı. Bu nedenle aşağıdaki oluşturma adımı mevcut proje için tamamlandı.

Firebase konsolunda `gunluk-dua-hadis-15178` projesinin Remote Config bölümünde
iki JSON parametresini düzenleyin: `app_update_android` ve `app_update_ios`.
Her platformun mağazada erişilebilir sürümünü ayrı yönetin.

Örneğin 2.0.3 yayımlandığında, 2.0.2 kullanıcılarına ertelenebilir hatırlatma:

```json
{
  "enabled": true,
  "published": true,
  "latest_version": "2.0.3",
  "minimum_version": "2.0.2"
}
```

2.0.2 dahil daha eski sürümleri güncellemeye yönlendirmek için aynı JSON içinde
`minimum_version` değerini `2.0.3` yapın. Değişiklikleri Remote Config'te yayımlayın.
Sürümler `major.minor.patch` biçimindedir. Build numarası karşılaştırılmaz;
kullanıcıya sunulan her yeni sürümde pubspec.yaml sürümünü de artırın.

`published` otomatik mağaza doğrulaması değildir; yayıncının onayıdır.
Zorunlu güncellemeyi açmadan önce yeni sürümün ilgili mağazada tüm hedef kullanıcılar
için indirilebilir olduğunu doğrulayın. Kademeli dağıtım tamamlanmalı; eski işletim
sistemlerinde kalan kullanıcıların da yeni sürümü kurabilmesi gerekir.
Android sürümü yayımlandı diye iOS ayarını aynı anda yükseltmeyin.

## Kullanıcı deneyimi

- Uygulama açılışında ve ön plana geldiğinde sürüm kontrol edilir.
- Güncel veya daha yeni sürümde ekran gösterilmez.
- Desteklenen eski sürümde “Güncelle” ve “Daha sonra” bulunur. Erteleme aynı sürüm
  için en az 24 saat sürer; mevcut oturum boyunca tekrar gösterilmez.
- Minimum sürümün altındaki kurulumda uygulama içeriğine erişim kapanır.
  “Güncelle” ilgili App Store / Google Play sayfasını açar; sadece mağazayı açmak
  engeli kaldırmaz. “Tekrar kontrol et” yapılandırmayı yeniden değerlendirir.
- Ekran Navigator'ın üzerindedir; widget bağlantıları ve yeni sayfalar ekranı aşamaz.

## Bağlantı ve geri alma

Firebase ağ istekleri en sık saatte bir yapılır; “Tekrar kontrol et” de bu önbellek
süresine uyar. Yönetim değişikliklerinin cihazlara ulaşması bu yüzden anlık değildir.
Ağ yanıtı için 8 saniye, ekranın toplam kontrolü için 12 saniye sınırı vardır.
Geçerli önbellek çevrimdışı durumda en fazla 24 saat uygulanır; daha eski önbellek,
bozuk/eksik ayar veya Firebase başlatma hatası kullanıcıyı süresiz kilitlemez.
Bu mekanizma bir sunucu erişim güvenliği önlemi değildir.

Geri almak için ilgili platformun JSON değerini aşağıdakiyle değiştirip yayımlayın:

```json
{"enabled": false}
```

## Yayın öncesi doğrulama

1. Mekanizmayı içeren test sürümünü fiziksel Android ve iPhone cihazlarına kurun.
2. Ayrı test Firebase projesi veya yalnız test kurulumlarına uygulanan Remote Config
   koşulu kullanın; deneme eşiklerini üretimde tüm kullanıcılara yayımlamayın.
3. İsteğe bağlı ekranı, ertelemeyi, zorunlu ekranı ve mağazaya yönlendirmeyi deneyin.
4. Güncel sürümde ekranın görünmediğini ve `enabled: false` ile engelin kalktığını doğrulayın.
5. Firebase ayarını kapalı tutarak mekanizmayı içeren ilk sürümü yayımlayın.
   Sonraki mağaza sürümlerinde yukarıdaki eşikleri yönetin.

Windows üzerinde Dart/widget testleri çalıştırılabilir; iOS derlemesi ve gerçek
App Store yönlendirmesi Codemagic/TestFlight ve iPhone üzerinde ayrıca doğrulanmalıdır.
