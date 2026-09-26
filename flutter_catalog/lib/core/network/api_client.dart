import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  /// True when the request never got an HTTP response (timeout, refused,
  /// unreachable host) — i.e. a URL / network problem, not a server bug.
  final bool isNetworkError;

  const ApiException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
  });

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

  /// Runs [request] with a timeout and turns low-level network failures into
  /// an [ApiException] that names the URL we tried, so "TimeoutException:
  /// Future not completed" never reaches the UI.
  Future<http.Response> _send(
    Future<http.Response> Function() request,
    String path,
    Duration timeout,
  ) async {
    try {
      return await request().timeout(timeout);
    } on TimeoutException {
      throw ApiException(
        'No response from $_baseUrl$path within ${timeout.inSeconds}s. '
        'Check the server URL (Profile → Backend server) and that the '
        'backend is running and reachable from this device.',
        isNetworkError: true,
      );
    } on http.ClientException catch (e) {
      throw ApiException(
        'Cannot connect to $_baseUrl (${e.message}).',
        isNetworkError: true,
      );
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final reqHeaders = await _headers(json: true);
    if (headers != null) {
      reqHeaders.addAll(headers);
    }
    final response = await _send(
      () => _httpClient.post(
        Uri.parse('$_baseUrl$path'),
        headers: reqHeaders,
        body: jsonEncode(body),
      ),
      path,
      timeout,
    );

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
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final reqHeaders = await _headers();
    if (headers != null) {
      reqHeaders.addAll(headers);
    }
    final response = await _send(
      () => _httpClient.get(Uri.parse('$_baseUrl$path'), headers: reqHeaders),
      path,
      timeout,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      '$path error ${response.statusCode}: ${response.body}',
      statusCode: response.statusCode,
    );
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final reqHeaders = await _headers();
    if (headers != null) {
      reqHeaders.addAll(headers);
    }
    final response = await _send(
      () => _httpClient.get(Uri.parse('$_baseUrl$path'), headers: reqHeaders),
      path,
      timeout,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException(
      '$path error ${response.statusCode}: ${response.body}',
      statusCode: response.statusCode,
    );
  }
}
