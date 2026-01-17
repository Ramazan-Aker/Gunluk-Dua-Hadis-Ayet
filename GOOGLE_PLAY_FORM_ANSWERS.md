# Google Play Store Form Cevapları

Bu dosya, Google Play Store'un istediği bilgi formunu doldurmanız için hazırlanmıştır.

---

## 1. Developer email address *
**Cevap:** `tahram2351@gmail.com`

---

## 2. Developer/Business Name *
**Cevap:** `Tahram`

---

## 3. Did somebody register this developer account on your behalf? If so, please explain why. *
**Cevap:** `No`

---

## 4. Your app's core functionality

### Does your app function differently based on a user's geolocation or language? If yes, why? *
**Cevap:**
```
No. The app does not function differently based on geolocation. However, the app displays content in Turkish language and uses Turkish translations for Quran verses. The app's functionality remains the same regardless of the user's location. The Turkish language content is provided to serve Turkish-speaking Muslim users, but the app does not restrict or change features based on geographic location.
```

**Alternatif (Eğer dil bazlı farklılık varsa diye):**
```
The app displays Islamic content (Duas, Hadiths, and Quran verses) primarily in Turkish language. While the app does not restrict access based on geolocation, it is designed for Turkish-speaking users. The Quran verses are fetched from Al-Quran Cloud API with Turkish translations (tr.diyanet, tr.yazir, tr.bayraktar editions). The app's core functionality remains consistent regardless of user location - all users can access the same daily content, share features, and reminders.
```

---

## 5. Have you uploaded all Proof of Permission for any intellectual property that appears in your app? *

**Cevap:** `No third party intellectual property appears in my app`

**Açıklama:**
- Quran verses are fetched from Al-Quran Cloud API (https://api.alquran.cloud), which is a free, open API for Quranic content
- Hadiths and Duas are from authentic Islamic sources and are in the public domain
- All content is properly attributed with source references (e.g., "Sahih al-Bukhari", "Surah name and verse number")
- The app does not claim ownership of the Islamic content, only provides a platform to display it

**Eğer Google daha fazla açıklama isterse:**
```
The app displays Islamic religious content (Quran verses, Hadiths, and Duas) which are:
1. Quran verses: Fetched from Al-Quran Cloud API (api.alquran.cloud), a free public API that provides Quranic text and translations. The API is publicly available and does not require special permissions.
2. Hadiths: From authentic Islamic collections (Sahih al-Bukhari, Sahih Muslim, etc.) which are in the public domain and properly attributed.
3. Duas: Traditional Islamic supplications that are in the public domain.

All content includes proper source attribution. The app does not claim ownership of any Islamic content - it only provides a user interface to display and share this publicly available religious content.
```

---

## 6. Please select the statement that applies to you: *

**Cevap:** `I do not have any content locked behind a login wall.`

**Açıklama:** 
Uygulamanızda login/registration sistemi yok. Tüm içerik herkese açık.

---

## 7. Please upload a video demo of your app, including all functionality that may be locked behind a login wall. *

**Yapılacaklar:**
1. Uygulamanın ekran kaydı (screen recording) alın
2. Video şunları göstermeli:
   - Ana ekran (günlük dua/hadis/ayet gösterimi)
   - "Sonraki" butonuna tıklama
   - Paylaşım özelliği
   - Bildirim/hatırlatıcı ayarları (varsa)
   - Reklamların gösterimi
   - Tüm özelliklerin çalıştığını gösterin

**Video önerileri:**
- 2-3 dakika uzunluğunda olmalı
- Tüm ana özellikleri göstermeli
- Login olmadığını göstermeli (direkt içeriğe erişim)
- MP4 formatında olmalı

---

## 8. What SDKs does your app use and why? *

**Cevap:**
```
The app uses the following SDKs:

1. **Google Mobile Ads SDK (google_mobile_ads)**
   - Purpose: To display banner and interstitial advertisements for app monetization
   - Version: 4.0.0
   - Usage: Banner ads are shown at the bottom of the main screen. Interstitial ads are shown when users share content or after clicking "Next" button multiple times.

2. **Firebase Analytics SDK (firebase_analytics)**
   - Purpose: To collect anonymous usage analytics to understand user behavior and improve the app experience
   - Version: 11.3.3
   - Usage: Tracks screen views, user interactions (sharing, reading), and content type preferences

3. **Firebase Crashlytics SDK (firebase_crashlytics)**
   - Purpose: To automatically collect crash reports and errors to help identify and fix bugs
   - Version: 4.1.3
   - Usage: Captures uncaught exceptions and crashes to improve app stability

4. **Flutter Local Notifications SDK (flutter_local_notifications)**
   - Purpose: To send daily reminder notifications to users for reading Islamic content
   - Version: 17.2.3
   - Usage: Schedules daily notifications to remind users to read the daily Dua, Hadith, or Ayah

5. **HTTP SDK (http)**
   - Purpose: To fetch Quran verses from Al-Quran Cloud API (api.alquran.cloud)
   - Version: 1.2.2
   - Usage: Makes API calls to retrieve random Quran verses with Turkish translations

All SDKs are used solely for the stated purposes and comply with Google Play policies.
```

---

## 9. Explain how you ensure that any 3rd party code and SDKs used in your app comply with our policies. *

**Cevap:**
```
I ensure compliance with Google Play policies through the following measures:

1. **Official SDKs Only**: I only use official, Google-approved SDKs:
   - Google Mobile Ads SDK (official Google SDK)
   - Firebase SDKs (official Google SDKs)
   - Flutter plugins from pub.dev (official Flutter package repository)

2. **Regular Updates**: All SDKs are kept up-to-date with the latest stable versions that comply with current Google Play policies.

3. **Privacy Compliance**:
   - Firebase Analytics: Only collects anonymous usage data, no personal information
   - Firebase Crashlytics: Only collects crash reports and error logs, no user data
   - Google Mobile Ads: Complies with AdMob policies, uses official AdMob SDK
   - No user data is collected beyond what is necessary for app functionality

4. **Data Collection Transparency**: 
   - The app does not collect personal information
   - Analytics data is anonymous
   - No user accounts or login required
   - No location tracking beyond what AdMob SDK requires for ad serving

5. **AdMob Policy Compliance**:
   - Ads are clearly labeled and separated from content
   - No misleading ad placement
   - No incentivized clicks
   - Banner ads are properly sized and positioned
   - Interstitial ads are shown at appropriate times (after user actions, not interrupting core functionality)

6. **Third-Party API Usage**:
   - Al-Quran Cloud API (api.alquran.cloud) is a free, public API
   - API calls are made only to fetch Quran content, no user data is sent
   - Proper error handling to prevent data leaks

7. **Code Review**: All third-party code is reviewed to ensure it only performs its stated function and does not include any malicious or policy-violating code.

8. **User Data Policy**: The app follows Google Play's User Data policy - it only collects data necessary for app functionality (analytics, crash reporting) and does not share user data with unauthorized third parties.
```

---

## Ek Notlar ve İpuçları

### Video Hazırlama:
1. Android cihazda ekran kaydı alın (Settings > Advanced features > Screenshots and screen recorder)
2. Şunları gösterin:
   - Uygulama açılışı
   - Günlük içerik gösterimi
   - "Sonraki" butonuna tıklama
   - Paylaşım özelliği
   - Reklamların görünümü
   - Bildirim ayarları (varsa)
3. Video süresi: 2-3 dakika yeterli
4. Format: MP4, maksimum 100MB

### Önemli Hatırlatmalar:
- ✅ Tüm cevapları İngilizce yazın
- ✅ Samimi ve profesyonel bir dil kullanın
- ✅ Gerçek bilgileri verin (yalan söylemeyin)
- ✅ Video yüklerken tüm özellikleri gösterin
- ✅ Login olmadığını açıkça belirtin

### Olası Takip Soruları:
Eğer Google ek sorular sorarsa:
- **Quran API izni:** "Al-Quran Cloud API is a free, public API that does not require special permissions. It is publicly available at api.alquran.cloud."
- **İçerik kaynağı:** "All Islamic content (Quran, Hadith, Dua) is from authentic sources and properly attributed. The app does not claim ownership of any religious content."

---

## Formu Doldururken Dikkat Edilecekler

1. **Developer email:** tahram2351@gmail.com (zaten doldurulmuş)
2. **Developer Name:** Tahram (zaten doldurulmuş)
3. **Account registration:** No (zaten doldurulmuş)
4. **Geolocation:** Yukarıdaki cevabı kopyalayın
5. **Intellectual Property:** "No third party intellectual property appears in my app" seçeneğini işaretleyin
6. **Login wall:** "I do not have any content locked behind a login wall" seçeneğini işaretleyin
7. **Video:** Ekran kaydınızı yükleyin
8. **SDKs:** Yukarıdaki SDK listesini kopyalayın
9. **Compliance:** Yukarıdaki compliance açıklamasını kopyalayın

---

**Başarılar! 🚀**

