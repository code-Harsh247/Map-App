import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

/// Handles getting a presigned S3 URL from the backend and uploading route data.
class RouteUploadService {
  /// Request a presigned upload URL from the backend.
  Future<String?> getPresignedUrl({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConstants.routeUploadUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        // Backend returns { "url": "https://...presigned-s3-url..." }
        return data['url'] as String?;
      } else {
        debugPrint('[RouteUpload] Failed to get presigned URL: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[RouteUpload] Error getting presigned URL: $e');
      return null;
    }
  }

  /// Upload JSON data to the presigned S3 URL via PUT.
  Future<bool> uploadToS3({
    required String presignedUrl,
    required Map<String, dynamic> jsonData,
  }) async {
    try {
      final body = jsonEncode(jsonData);
      final response = await http.put(
        Uri.parse(presignedUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[RouteUpload] Upload successful (${response.statusCode})');
        return true;
      } else {
        debugPrint('[RouteUpload] Upload failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[RouteUpload] Upload error: $e');
      return false;
    }
  }

  /// Combined: get presigned URL then upload data.
  Future<bool> uploadRouteData({
    required String token,
    required Map<String, dynamic> routeJson,
  }) async {
    final url = await getPresignedUrl(token: token);
    if (url == null) {
      debugPrint('[RouteUpload] No presigned URL obtained, skipping upload');
      return false;
    }
    return uploadToS3(presignedUrl: url, jsonData: routeJson);
  }
}
