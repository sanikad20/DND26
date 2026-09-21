import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  String get _baseUrl => ApiConfig.instance.baseUrl;

  Future<Map<String, String>> _headers({bool json = false}) async {
    final headers = <String, String>{};
    if (json) {
      headers['Content-Type'] = 'application/json';
    }

    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final response = await _httpClient
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: await _headers(json: true),
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      '$path error ${response.statusCode}: ${response.body}',
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final response = await _httpClient
        .get(Uri.parse('$_baseUrl$path'), headers: await _headers())
        .timeout(timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      '$path error ${response.statusCode}: ${response.body}',
      statusCode: response.statusCode,
    );
  }
}
