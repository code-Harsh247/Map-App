# Map SDK Migration Plan: Moving to "Valhalla-like" Quality

## Research Findings
You expressed interest in a map SDK with "better quality like Valhalla" and a "light theme UI".
*   **Clarification:** "Valhalla" is primarily a **Routing Engine** (backend), not a frontend Map SDK. However, it is often paired with **Vector Maps** (like Mapbox or MapLibre) which provide the crisp, smooth, rotatable maps you likely associate with it.
*   **Current State:** You are using `flutter_map` with **Raster Tiles** (images). This creates a "pixelated" look when zooming and text labels rotate with the map (upside down).
*   **Goal:** Switch to **Vector Maps** for crisp text, smooth zooming, 3D buildings, and native "Light Theme" support.

## Migration Options

### Option A: Mapbox GL (Recommended for Quality)
The industry standard for premium vector maps.
*   **Pros:** Best visual quality, built-in "Light" template, very smooth.
*   **Cons:** Requires a **Mapbox Public Access Token** (Free tier is generous up to 50k loads/month).
*   **UI:** Matches the "Valhalla" demo aesthetic perfectly.

### Option B: MapLibre GL (Open Source)
A free fork of Mapbox.
*   **Pros:** Free, open-source.
*   **Cons:** Requires a Tile Provider (e.g., MapTiler, Stadia Maps) which implies getting an API Key. Slightly more setup for styles.

### Option C: Google Maps
*   **Pros:** Familiarity, high quality.
*   **Cons:** Requires Google Cloud billing setup (you may already have this). UI is very "Google", harder to customize to a generic "Valhalla" look.

## Proposed Plan (Option A - Mapbox)

1.  **Dependencies**:
    *   Remove `flutter_map`, `latlong2`.
    *   Add `mapbox_maps_flutter`.

2.  **Configuration**:
    *   **Android**: Add `mapbox_access_token` to `strings.xml`. Update `build.gradle` (Mapbox requires stricter minSDK versions).
    *   **iOS**: Add `MBXAccessToken` to `Info.plist`.

3.  **Code Changes**:
    *   Replace `FlutterMap` widget with `MapboxMap`.
    *   Set style to `MapboxStyles.LIGHT`.
    *   Update interaction logic (Markers -> Annotations).
    *   Update Camera logic (MapController -> MapboxMap Controller).

## Immediate Action (Current Branch)
I have created this plan on branch `feature/valhalla-light-theme`.
To proceed, please:
1.  **Confirm** you want to proceed with **Mapbox GL**.
2.  **Provide** a Mapbox Public Access Token (or I can insert a placeholder `YOUR_TOKEN_HERE` for you to fill later).

**Note:** Changing the SDK will break the current `map_home_screen.dart` logic until fully refactored.
