# Google Maps Setup Guide for Map Now

## Overview
This guide will help you set up Google Maps API for both Android and iOS platforms.

## Prerequisites
- Google Cloud Console account
- Billing enabled on your Google Cloud project
- Flutter development environment set up

## Step 1: Get Google Maps API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services** > **Credentials**
4. Click **Create Credentials** > **API Key**
5. Copy the generated API key
6. Click on **Restrict Key** to secure it:
   - For Android: Add package name and SHA-1 certificate fingerprint
   - For iOS: Add bundle identifier

## Step 2: Enable Required APIs

In Google Cloud Console, go to **APIs & Services** > **Library** and enable:

- ✅ Maps SDK for Android
- ✅ Maps SDK for iOS
- ✅ Geocoding API
- ✅ Directions API
- ✅ Places API (optional, for better search)

## Step 3: Android Configuration

### Get SHA-1 Certificate Fingerprint (for development)

```bash
cd android
./gradlew signingReport
```

Look for the **SHA-1** fingerprint under the **debug** variant.

### Configure AndroidManifest.xml

File: `android/app/src/main/AndroidManifest.xml`

Add the following inside the `<application>` tag (before any `<activity>` tags):

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```

**Full Example:**

```xml
<application
    android:label="map_now"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher">
    
    <!-- Add Google Maps API Key -->
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
    
    <activity
        android:name=".MainActivity"
        ...>
    </activity>
</application>
```

### Update build.gradle (if needed)

File: `android/app/build.gradle`

Ensure minimum SDK version is at least 21:

```gradle
android {
    defaultConfig {
        minSdkVersion 21  // Google Maps requires min SDK 21
        targetSdkVersion flutter.targetSdkVersion
    }
}
```

## Step 4: iOS Configuration

### Configure AppDelegate.swift

File: `ios/Runner/AppDelegate.swift`

Replace the entire file content with:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Add your Google Maps API key here
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Update Info.plist

File: `ios/Runner/Info.plist`

Add location permissions:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to your location to provide navigation services.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to your location to provide navigation services.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to your location to provide navigation services.</string>
```

### Update Podfile (if needed)

File: `ios/Podfile`

Ensure platform version is at least iOS 13:

```ruby
platform :ios, '13.0'
```

Then run:

```bash
cd ios
pod install
cd ..
```

## Step 5: Verify Setup

Run the following commands to verify everything is set up correctly:

```bash
# Clean the project
flutter clean

# Get dependencies
flutter pub get

# For iOS, install pods
cd ios && pod install && cd ..

# Run on Android
flutter run

# Or run on iOS
flutter run -d ios
```

## Common Issues and Solutions

### Issue 1: "Maps API key not found"
**Solution**: Double-check that you've added the API key in the correct location for your platform.

### Issue 2: "This API project is not authorized to use this API"
**Solution**: Make sure you've enabled the required APIs in Google Cloud Console.

### Issue 3: "Map is gray/blank on Android"
**Solution**: 
- Verify SHA-1 certificate is added to API key restrictions
- Check that the package name matches your app's package name
- Ensure billing is enabled on Google Cloud project

### Issue 4: "Map not showing on iOS simulator"
**Solution**: 
- iOS simulator doesn't always render maps properly
- Test on a real iOS device
- Check that GMSServices.provideAPIKey is called

### Issue 5: Build errors after adding GoogleMaps
**Solution**:
```bash
flutter clean
flutter pub get
cd ios && pod deintegrate && pod install && cd ..
flutter run
```

## Testing Checklist

- [ ] Map displays correctly
- [ ] Current location is shown
- [ ] Search functionality works
- [ ] Markers can be placed
- [ ] Polylines are drawn correctly
- [ ] Location permissions are requested
- [ ] App works on both debug and release builds

## Security Best Practices

1. **Restrict Your API Key**: Always restrict your API keys
   - For Android: Use SHA-1 and package name restrictions
   - For iOS: Use bundle ID restrictions
   
2. **Use Environment Variables**: Don't commit API keys to version control
   - Consider using flutter_dotenv package
   - Add `.env` to `.gitignore`

3. **Monitor Usage**: Regularly check your API usage in Google Cloud Console

4. **Set Quotas**: Set daily quotas to prevent unexpected charges

## API Key Restrictions Example

### Android API Key Restrictions:
- Application restrictions: Android apps
- Package name: `com.mapnow.map_now`
- SHA-1 certificate fingerprint: `[Your SHA-1]`

### iOS API Key Restrictions:
- Application restrictions: iOS apps
- Bundle ID: `com.mapnow.mapNow`

## Additional Resources

- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [Flutter Google Maps Plugin](https://pub.dev/packages/google_maps_flutter)
- [Google Cloud Console](https://console.cloud.google.com/)

---

**Note**: Remember to replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your actual API key in all configuration files.
