# Map Now - Flutter Project Setup

A multi-stop route optimization app built with Flutter and OpenStreetMap.

## Project Overview

Map Now is a utility-first navigation tool that specializes in multi-stop route optimization. The app can take up to 3 intermediate waypoints and re-order them to ensure the most efficient travel path based on distance and time.

## Features

- ✅ User authentication (Name & Mobile)
- ✅ Global address search using Geocoding API
- ✅ Multi-stop route optimization (up to 3 stops)
- ✅ Interactive OpenStreetMap integration (100% FREE)
- ✅ Optimized polyline path visualization
- ✅ Distance calculation and display
- ✅ No API keys required for maps

## Project Structure

```
lib/
├── constants/
│   └── api_constants.dart       # API endpoints configuration
├── models/
│   ├── user_model.dart          # User data model
│   ├── place_model.dart         # Location/place data model
│   └── route_model.dart         # Route optimization data model
├── providers/
│   ├── auth_provider.dart       # Authentication state management
│   └── map_provider.dart        # Map and routing state management
├── screens/
│   ├── login_screen.dart        # User login screen
│   └── map_home_screen.dart     # Main map interface
├── services/
│   ├── auth_service.dart        # Login API integration
│   ├── geocoding_service.dart   # Address search API
│   └── routing_service.dart     # Route optimization API
└── main.dart                    # App entry point
```

## Dependencies

- `flutter_map` - OpenStreetMap integration (FREE)
- `latlong2` - Latitude/longitude utilities
- `http` - API calls
- `provider` - State management
- `shared_preferences` - Local data storage
- `location` - Location services
- `geocoding` - Geocoding utilities

## Setup Instructions

### 1. Install Dependencies

```bash
cd map_now
flutter pub get
```

### 2. Run the App

That's it! No API keys or additional configuration needed for maps.

```bash
flutter run
```

The app uses OpenStreetMap which is completely free and requires no API keys.

### 3. Configure Permissions (Optional)

#### Android Permissions (Already configured in AndroidManifest.xml):
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `INTERNET`

#### iOS Permissions:
Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location for navigation.</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>This app needs access to location for navigation.</string>
```

## API Endpoints

The app uses three main API endpoints:

1. **Login API**
   - URL: `https://routing.amphereai.com/api/login`
   - Method: POST
   - Body: `{ "name": "string", "mobile": "string" }`

2. **Geocoding API**
   - URL: `https://maps.amphereai.com/api/v1/addresses/search`
   - Method: POST
   - Body: `{ "addressString": "string" }`

3. **Multi-Stop Routing API**
   - URL: `https://routing.amphereai.com/api/c-square/multistop`
   - Method: POST
   - Body: `{ "coordinates": [...], "cache": true }`

## Running the App

```bash
# Check for connected devices
flutter devices

# Run on connected device
flutter run

# Run in debug mode
flutter run --debug

# Run in release mode
flutter run --release
```

## Building the App

### Android APK:
```bash
flutter build apk --release
```

### iOS:
```bash
flutter build ios --release
```

## Technical Constraints

- **Maximum Stops**: 3 intermediate stops allowed
- **Total Coordinates**: Start + 3 Stops + Destination = 5 points maximum
- **Distance Unit**: API returns meters, displayed as kilometers
- **Caching**: Route optimization uses caching for performance

## State Management

The app uses Provider for state management with two main providers:

1. **AuthProvider**: Manages user authentication and session
2. **MapProvider**: Handles map interactions, search, and route optimization

## Next Steps

1. Test the login functionality
2. Test address search
3. Test route optimization with multiple stops
4. Customize UI theme and styling as needed
5. (Optional) Switch to alternative tile providers if needed

## Troubleshooting

### Map not showing:
- Check internet connectivity
- Verify OpenStreetMap tile servers are accessible
- Try alternative tile providers

### Build errors:
```bash
flutter clean
flutter pub get
flutter run
```

### Location permissions:
- Make sure location permissions are granted in device settings
- Check that permissions are properly configured in manifest files

## Future Enhancements

- [ ] Real-time traffic data integration
- [ ] Save favorite routes
- [ ] Route history
- [ ] Turn-by-turn navigation
- [ ] Voice guidance
- [ ] Multiple route alternatives

---

**Version**: 1.0  
**Platform**: Flutter (iOS/Android)  
**Status**: Development Ready
