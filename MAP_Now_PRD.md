
Product Requirements Document (PRD): Map Now

Project Name: Map Now

Platform: Flutter (iOS/Android)

Version: 1.1

Status: Design Confirmed / Development Ready
1. Product Vision

Map Now is a utility-first navigation tool built for users who need more than just "Point A to Point B." It specializes in multi-stop route optimization, taking up to three intermediate waypoints and re-ordering them to ensure the most efficient travel path based on distance and time.
2. Core User Flow

Based on the finalized designs and technical specifications:

    Authentication: User enters Name and Mobile to establish a session via the Login API.

    Discovery: User interacts with a map-centric home screen. They search for a destination using the Geocoding API.

    Route Planning: User selects a destination and chooses 1–3 intermediate stops using a counter-based UI.

    Optimization: The app sends all waypoints to the Routing Engine, which returns the most efficient traversal order.

    Execution: User reviews the optimized polyline path and total distance before starting navigation.

3. Functional Requirements
3.1 User Identity (Login API)

    Requirement: Capture and store user profile data.

    Endpoint: POST https://routing.amphereai.com/api/login.

    Data Fields: name (String) and mobile (String).

3.2 Global Search (Geo Coding API)

    Requirement: Transform text-based queries into coordinate-based landmarks.

    Endpoint: POST https://maps.amphereai.com/api/v1/addresses/search.

    Input: addressString (e.g., "Samsung Bangalore").

    Output: Return fullAddress, latitude, longitude, and placeId.

3.3 Multi-Stop Optimization (Routing Engine API)

    Requirement: Solve the "Traveling Salesman" problem for up to 3 stops.

    Endpoint: POST https://routing.amphereai.com/api/c-square/multistop.

    Logic:

        Accept an array of coordinates (Start, Stops, Destination).

        Set Cache: true to optimize performance for frequent routes.

    Output: * ordered_coordinates: The sequence in which the user should visit the stops.

        path: A detailed list of coordinates to draw the map polyline.

        distance: Total route length in meters.

4. Technical Constraints & UI Rules

    Stop Limit: The UI must strictly enforce a maximum of 3 intermediate stops (Total coordinates: 5).

    The "Optimize" Trigger: The call to the Routing Engine should only occur once the "Find Route" button is pressed to minimize API costs.

    Map Polyline: The path coordinates must be parsed into Flutter LatLng objects to render the green route line seen in the design.

    Unit Conversion: The API returns distance in meters. The UI must convert this to kilometers (e.g., 6983m → 6.98 km) for better readability.