class ApiConstants {
  // Base URLs
  static const String routingBaseUrl = 'https://routing.amphereai.com/api';
  static const String mapsBaseUrl = 'https://maps.amphereai.com/api/v1';
  static const String mapsApiBaseUrl = 'https://maps.amphereai.com/api'; // For login endpoint

  // Endpoints
  static const String loginEndpoint = '/login/route';
  static const String geocodingEndpoint = '/addresses/search';
  static const String multiStopEndpoint = '/c-square/multistop';
  static const String feedbackEndpoint = '/feedback';
  static const String routeUploadEndpoint = '/v1/routes/upload-url';

  // Full URLs
  static String get loginUrl => '$mapsApiBaseUrl$loginEndpoint';
  static String get geocodingUrl => '$mapsBaseUrl$geocodingEndpoint';
  static String get multiStopUrl => '$routingBaseUrl$multiStopEndpoint';
  static String get feedbackUrl => '$mapsApiBaseUrl$feedbackEndpoint';
  static String get routeUploadUrl => '$mapsApiBaseUrl$routeUploadEndpoint';
}
