import 'package:shared_preferences/shared_preferences.dart';

/// Manages the backend base URL.
/// Falls back to localhost (emulator only) if never configured.
class ApiConfig {
  ApiConfig._();
  static final ApiConfig instance = ApiConfig._();

  static const _key         = 'backend_base_url';
  static const _defaultUrl = 'http://127.0.0.1:8000'; // emulator fallback

  String _baseUrl = _defaultUrl;
  String get baseUrl => _baseUrl;

  /// Call once at app startup (before any API calls)
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_key) ?? _defaultUrl;
  }

  /// Save a new URL (called from settings screen)
  Future<void> setBaseUrl(String url) async {
    // Strip trailing slash for consistency
    final clean = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, clean);
    _baseUrl = clean;
  }

  /// True if user has configured a real URL (not the default fallback)
  bool get isConfigured => _baseUrl != _defaultUrl;
}