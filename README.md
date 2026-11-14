# Mera Khata - Safe Udhar Book

## Setup (Android Studio)
1. `flutter create .` inside this folder (generates the android/ folder), keep these lib/ and pubspec.yaml files.
2. Firebase Console: create project -> add Android app (package name = applicationId in android/app/build.gradle).
   Add your SHA-1 (`cd android && ./gradlew signingReport`). Enable Authentication -> Google, and Firestore Database.
3. Download `google-services.json` -> `android/app/`.
4. Gradle: in `android/settings.gradle(.kts)` plugins block add
   `id("com.google.gms.google-services") version "4.4.2" apply false`
   and in `android/app/build.gradle(.kts)` plugins block add `id("com.google.gms.google-services")`.
   Set `minSdk = 23` in android/app/build.gradle.
5. AndroidManifest.xml: add `<uses-permission android:name="android.permission.INTERNET"/>` and inside `<manifest>`:
   ```xml
   <queries>
     <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
     <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
     <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>
   </queries>
   ```
6. Firestore rules (each user sees only own data):
   ```
   rules_version = '2';
   service cloud.firestore { match /databases/{db}/documents {
     match /users/{uid}/{document=**} { allow read, write: if request.auth != null && request.auth.uid == uid; }
   }}
   ```
7. `flutter pub get` then `flutter run`.

## Notes
- Urdu voice needs an Urdu voice installed in the phone's Text-to-Speech settings (Google TTS).
- Auto backup runs when the app opens / goes to background (at most once per 20 hours). For a strict
  "every night at 2 AM" backup even if the app is never opened, add the `workmanager` package.
- PDF uses Roman Urdu labels; to print Urdu-script names bundle an Urdu font (Noto Nastaliq Urdu).
