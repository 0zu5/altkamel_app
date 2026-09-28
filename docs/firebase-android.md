# Android Firebase configuration

This app uses Firebase Cloud Messaging only for Android device-token registration.

1. In Firebase Console, register Android package `ly.altkamel.altkamel_app`.
2. Download its `google-services.json`.
3. Copy it to `android/app/google-services.json`.
4. Run `flutter pub get`, then build or run the Android app on a physical device with Google Play services.
5. After a successful sign-in, accept the Android notification prompt. The app registers its FCM token with the staging API using the authenticated device endpoint.

`google-services.json` is intentionally ignored by Git. Do not copy configuration files from another Firebase project. iOS configuration remains deferred until Apple Developer Program access and APNs credentials are available.
