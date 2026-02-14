1. Routing Engine API

This multipurpose API is designed for multi-stop route optimization. It calculates the most efficient order to visit a set of waypoints and provides the actual path data for rendering on a map.

    Endpoint: POST https://routing.amphereai.com/api/c-square/multistop

    Request Parameters:

        coordinates: An array of latitude/longitude pairs representing the start, end, and up to 3 intermediate stops.

        Cache: A boolean (true/false) used to enable caching of the response for better performance.

    Key Response Data:

        ordered_coordinates: The waypoints rearranged into the most optimal travel order.

        path: A detailed set of coordinates representing the actual turn-by-turn route to be drawn on the map.

        distance: The total length of the optimized path in meters.

        