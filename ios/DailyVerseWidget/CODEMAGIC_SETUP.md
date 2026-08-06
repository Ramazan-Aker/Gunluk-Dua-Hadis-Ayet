# iOS widget için Codemagic kurulumu

Widget Extension hedefi `tool/add_ios_widget_target.rb` tarafından Codemagic
build'i sırasında otomatik oluşturulur. Mac veya Xcode arayüzü gerekmez.

## Apple Developer web paneli

1. **Certificates, Identifiers & Profiles > Identifiers** bölümünde
   `group.com.tahram.gunlukduahadis` adlı bir App Group oluşturun.
2. Mevcut `com.tahram.gunlukduahadis` App ID'sinde **App Groups** yeteneğini
   açıp bu grubu seçin.
3. `com.tahram.gunlukduahadis.DailyVerseWidget` adlı yeni bir **App ID**
   oluşturun; bunda da aynı App Group'u etkinleştirin.
4. Her iki App ID için de App Store Distribution provisioning profile
   oluşturun. Ana uygulamanın eski profili App Group eklendiği için yeniden
   oluşturulmalıdır.

## Codemagic gizli değişkenleri

Mevcut `ios_signing` grubunda şunlar bulunmalıdır:

- `CM_CERTIFICATE`: Mevcut dağıtım sertifikasının base64 içeriği
- `CM_CERTIFICATE_PASSWORD`: Sertifika parolası
- `CM_PROVISIONING_PROFILE`: Yenilenmiş ana uygulama profilinin base64 içeriği
- `CM_WIDGET_PROVISIONING_PROFILE`: Widget profilinin base64 içeriği

`codemagic.yaml` iki profili kurar, bundle kimliklerine göre gerçek profil
adlarını bulur ve ExportOptions dosyasına otomatik yazar.
