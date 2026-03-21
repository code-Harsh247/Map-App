import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

class FeedbackService {
  Future<bool> submitFeedback({
    required String token,
    required String textFeedback,
    String? geoCodingText,
    Map<String, dynamic>? geoCodingResponse,
    Map<String, dynamic>? routeShown,
  }) async {
    final body = <String, dynamic>{
      'textFeedback': textFeedback,
    };
    if (geoCodingText != null) body['geoCodingText'] = geoCodingText;
    if (geoCodingResponse != null) body['geoCodingResponse'] = geoCodingResponse;
    if (routeShown != null) body['routeShown'] = routeShown;

    print('[FeedbackService] POST ${ApiConstants.feedbackUrl} textFeedback="$textFeedback"');
    final response = await http.post(
      Uri.parse(ApiConstants.feedbackUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    print('[FeedbackService] Response ${response.statusCode}: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return true;
    } else {
      throw Exception('Feedback API failed with status: ${response.statusCode}');
    }
  }
}
