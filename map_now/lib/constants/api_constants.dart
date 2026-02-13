class ApiConstants {
  // Base URLs
  static const String routingBaseUrl = 'https://routing.amphereai.com/api';
  static const String mapsBaseUrl = 'https://maps.amphereai.com/api/v1';

  // Endpoints
  static const String loginEndpoint = '/login';
  static const String geocodingEndpoint = '/addresses/search';
  static const String multiStopEndpoint = '/c-square/multistop';

  // Full URLs
  static String get loginUrl => '$routingBaseUrl$loginEndpoint';
  static String get geocodingUrl => '$mapsBaseUrl$geocodingEndpoint';
  static String get multiStopUrl => '$routingBaseUrl$multiStopEndpoint';
}
