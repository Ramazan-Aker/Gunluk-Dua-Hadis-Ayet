# 📱 Daily Dua & Hadith

A beautiful Flutter mobile app to display daily Islamic content including Duas (supplications), Hadiths (sayings of Prophet Muhammad ﷺ), and Quran Ayahs (verses).

## ✨ Features

- 📖 **Daily Content**: Display a different Dua, Hadith, or Quran Ayah each day
- 🎲 **Random Item**: "Next" button to browse more content
- 📤 **Share**: Share content via WhatsApp, Instagram, and other apps
- 💾 **Smart Tracking**: Never see the same item twice in one day
- 📱 **Banner Ads**: Integrated Google AdMob for monetization
- 🎨 **Beautiful UI**: Elegant design with soft green/beige theme
- 📱 **Cross-Platform**: Works on both iOS and Android

## 📸 Screenshots

*(Add your app screenshots here)*

## 🚀 Getting Started

### Prerequisites

Before running the app, make sure you have:

1. **Flutter SDK** installed (v3.0.0 or higher)
   - Download from: https://flutter.dev/docs/get-started/install
2. **Android Studio** or **Xcode** for emulator/simulator
3. **VS Code** or **Android Studio** as IDE

### Installation

1. **Clone or download** this project to your computer

2. **Navigate to project directory**:
   ```bash
   cd daily_dua_hadith
   ```

3. **Install dependencies**:
   ```bash
   flutter pub get
   ```

4. **Check if Flutter is working**:
   ```bash
   flutter doctor
   ```

5. **Run the app**:
   
   For Android Emulator:
   ```bash
   flutter run
   ```
   
   For iOS Simulator (Mac only):
   ```bash
   flutter run -d ios
   ```

### 📱 Running on Emulator

#### Android Emulator (Windows/Mac/Linux)

1. Open Android Studio
2. Go to **Tools → Device Manager**
3. Click **Create Device**
4. Select a device (e.g., Pixel 5)
5. Download a system image (e.g., Android 11)
6. Click **Finish**
7. Start the emulator
8. Run `flutter run` in terminal

#### iOS Simulator (Mac only)

1. Open Xcode
2. Go to **Xcode → Preferences → Components**
3. Download a simulator
4. Run in terminal:
   ```bash
   open -a Simulator
   ```
5. Run `flutter run -d ios`

### 📱 Running on Physical Device

#### Android Device

1. Enable **Developer Options** on your phone:
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
2. Enable **USB Debugging** in Developer Options
3. Connect phone via USB
4. Run `flutter devices` to verify
5. Run `flutter run`

#### iOS Device (Mac only)

1. Connect iPhone via USB
2. Open project in Xcode
3. Select your device
4. Trust your computer on iPhone
5. Run from Xcode or `flutter run`

## 📝 Adding More Content

To add more Duas, Hadiths, or Ayahs:

1. Open `assets/data.json`
2. Add new items following this format:

```json
{
  "type": "dua",
  "text": "Your Arabic text here\n\nEnglish translation here",
  "source": "Source reference"
}
```

**Example**:

```json
{
  "type": "hadith",
  "text": "Whoever believes in Allah and the Last Day, let him speak good or remain silent.",
  "source": "Sahih al-Bukhari 6018"
},
{
  "type": "ayah",
  "text": "وَلَا تَيْأَسُوا مِن رَّوْحِ اللَّهِ\n\nDo not despair of the mercy of Allah.",
  "source": "Quran 12:87"
},
{
  "type": "dua",
  "text": "اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا\n\nO Allah, I ask You for beneficial knowledge.",
  "source": "Sunan Ibn Majah"
}
```

**Types**:
- `"dua"` - For supplications (prayers)
- `"hadith"` - For sayings of Prophet Muhammad ﷺ
- `"ayah"` - For Quran verses

## 🔧 Configuration

### Google AdMob Setup

1. **Create AdMob Account**:
   - Go to https://admob.google.com
   - Create an account and add your app

2. **Get Ad Unit IDs**:
   - Create Banner Ad units for Android and iOS
   - Copy your Ad Unit IDs

3. **Update Ad Unit IDs**:
   - Open `lib/services/ad_service.dart`
   - Replace test IDs with your actual Ad Unit IDs:

```dart
String get bannerAdUnitId {
  if (Platform.isAndroid) {
    return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Your Android ID
  } else if (Platform.isIOS) {
    return 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX'; // Your iOS ID
  }
}
```

4. **Update App IDs** in platform-specific files:

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX</string>
```

### Switching to API (Optional)

If you want to load content from an API instead of local JSON:

1. Open `lib/services/data_service.dart`
2. Uncomment the `loadFromAPI()` method template
3. Add `http` package to `pubspec.yaml`:
   ```yaml
   dependencies:
     http: ^1.1.0
   ```
4. Update the API URL and implement your logic

## 📁 Project Structure

```
daily_dua_hadith/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   └── daily_item.dart       # Data model for items
│   ├── services/
│   │   ├── data_service.dart     # Data loading & management
│   │   └── ad_service.dart       # AdMob integration
│   ├── screens/
│   │   └── home_screen.dart      # Main screen
│   └── widgets/
│       └── item_card.dart        # Card widget for displaying items
├── assets/
│   └── data.json                 # Local data file
├── pubspec.yaml                  # Dependencies
└── README.md                     # This file
```

## 🎨 Customization

### Colors

To change the app colors, edit `lib/main.dart`:

```dart
primaryColor: const Color(0xFF6B8E23),  // Main green color
scaffoldBackgroundColor: const Color(0xFFF5F5DC),  // Beige background
```

### Fonts

To change fonts:

1. Download font files (`.ttf`) and place in `fonts/` folder
2. Update `pubspec.yaml`:
   ```yaml
   fonts:
     - family: YourFont
       fonts:
         - asset: fonts/YourFont-Regular.ttf
   ```
3. Update theme in `main.dart`:
   ```dart
   fontFamily: 'YourFont',
   ```

## 📦 Dependencies

- `shared_preferences`: ^2.2.2 - Local data storage
- `share_plus`: ^7.2.1 - Sharing functionality
- `google_mobile_ads`: ^4.0.0 - Banner ads
- `intl`: ^0.18.1 - Date/time formatting

## 🐛 Troubleshooting

### Problem: Ad is not showing
- Make sure you've initialized AdMob in `main.dart`
- Check that Ad Unit IDs are correct
- Test ads may take time to load
- Check internet connection

### Problem: Data not loading
- Verify `assets/data.json` exists
- Check `pubspec.yaml` has assets section
- Run `flutter pub get`
- Restart the app

### Problem: Build errors
- Run `flutter clean`
- Run `flutter pub get`
- Restart IDE
- Check Flutter version: `flutter --version`

### Problem: iOS build fails
- Run `cd ios && pod install`
- Open `ios/Runner.xcworkspace` in Xcode
- Update signing certificates

## 📄 License

This project is open source. Feel free to use and modify for your own purposes.

## 🤝 Contributing

Contributions are welcome! Feel free to:
- Add more Islamic content
- Improve UI/UX
- Fix bugs
- Add new features

## 📧 Contact

For questions or support, please create an issue on the project repository.

## 🕌 Credits

- All Islamic content should be verified from authentic sources
- Hadiths from Sahih al-Bukhari, Sahih Muslim, and other authentic collections
- Quran translations from various approved sources

---

**May Allah accept this work and make it beneficial for the Muslim Ummah. Ameen.** 🤲

