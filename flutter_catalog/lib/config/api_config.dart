import 'package:shared_preferences/shared_preferences.dart';

/// Manages the backend base URL.
///
/// Resolution order (first match wins):
///   1. `--dart-define=API_BASE_URL=http://<host>:8000` given at build/run time
///   2. URL saved from the in-app "Backend server" dialog (Profile screen)
///   3. `http://127.0.0.1:8000` — only useful with `adb reverse tcp:8000 tcp:8000`
///      or a desktop/web run; a real phone needs 1 or 2.
class ApiConfig {
  ApiConfig._();
  static final ApiConfig instance = ApiConfig._();

  static const _key = 'backend_base_url';
  static const _defaultUrl = 'http://10.48.117.154:8000';

  /// Empty unless the app was built/run with --dart-define=API_BASE_URL=...
  static const _buildTimeUrl = String.fromEnvironment('API_BASE_URL');

  /// True when a build-time URL is active (it overrides the saved one).
  static bool get hasBuildTimeOverride => _buildTimeUrl.isNotEmpty;

  String _baseUrl = _defaultUrl;
  String get baseUrl => _baseUrl;

  /// Trims whitespace and trailing slashes, and adds `http://` if the user
  /// typed a bare host like `192.168.1.20:8000`.
  static String normalize(String url) {
    var clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (clean.isNotEmpty && !RegExp(r'^https?://').hasMatch(clean)) {
      clean = 'http://$clean';
    }
    return clean;
  }

  /// Call once at app startup (before any API calls)
  Future<void> init() async {
    if (hasBuildTimeOverride) {
      _baseUrl = normalize(_buildTimeUrl);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_key) ?? _defaultUrl;
  }

  /// Save a new URL (called from the Profile screen's server dialog)
  Future<void> setBaseUrl(String url) async {
    final clean = normalize(url);
    if (clean.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, clean);
    _baseUrl = clean;
  }

  /// True if a real URL is configured (not the default fallback)
  bool get isConfigured => _baseUrl != _defaultUrl;
}
