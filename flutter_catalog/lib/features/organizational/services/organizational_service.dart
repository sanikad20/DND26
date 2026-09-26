import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/network/api_client.dart';
import '../models/organizational_models.dart';

class OrganizationalService {
  OrganizationalService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, String>> _authHeaders({bool required = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (required) {
        throw const ApiException('Please sign in to access organizational features.');
      }
      return const {};
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      if (required) {
        throw const ApiException(
          'Unable to obtain authorization token. Please sign in again.',
        );
      }
      return const {};
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<UserProfileRole> getMyRole() async {
    final headers = await _authHeaders(required: true);
    final data = await _apiClient.getJson(
      '/organizational/me/role',
      headers: headers,
    );
    return UserProfileRole.fromJson(data);
  }

  Future<UserProfileRole> switchRole(String newRole) async {
    final headers = await _authHeaders(required: true);
    final data = await _apiClient.postJson(
      '/organizational/me/role',
      {'role': newRole},
      headers: headers,
    );
    return UserProfileRole.fromJson(data);
  }

  Future<UserProfileRole> updateOptIn(bool optIn) async {
    final headers = await _authHeaders(required: true);
    final data = await _apiClient.postJson(
      '/organizational/me/opt-in',
      {'opt_in': optIn},
      headers: headers,
    );
    return UserProfileRole.fromJson(data);
  }

  Future<WelfareOverview> getWelfareOverview() async {
    final headers = await _authHeaders(required: true);
    final data = await _apiClient.getJson(
      '/organizational/overview',
      headers: headers,
    );
    return WelfareOverview.fromJson(data);
  }

  Future<List<PersonnelWelfareSummary>> getPersonnelSummaries({String? unitId}) async {
    final headers = await _authHeaders(required: true);
    final query = unitId != null && unitId.isNotEmpty ? '?unit_id=$unitId' : '';
    final list = await _apiClient.getJsonList(
      '/organizational/personnel$query',
      headers: headers,
    );
    return list
        .map((e) => PersonnelWelfareSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WelfareAlertItem>> getActiveAlerts({String? unitId}) async {
    final headers = await _authHeaders(required: true);
    final query = unitId != null && unitId.isNotEmpty ? '?unit_id=$unitId' : '';
    final list = await _apiClient.getJsonList(
      '/organizational/alerts$query',
      headers: headers,
    );
    return list
        .map((e) => WelfareAlertItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WelfareAlertItem> acknowledgeAlert(String alertId, {String? notes}) async {
    final headers = await _authHeaders(required: true);
    final data = await _apiClient.postJson(
      '/organizational/alerts/$alertId/acknowledge',
      notes != null ? {'notes': notes} : {},
      headers: headers,
    );
    return WelfareAlertItem.fromJson(data);
  }

  Future<CommanderUnitSummary> getCommanderUnitSummary(String unitId) async {
    final headers = await _authHeaders(required: true);
    final data = await _apiClient.getJson(
      '/organizational/unit/$unitId',
      headers: headers,
    );
    return CommanderUnitSummary.fromJson(data);
  }

  Future<List<OrgRecommendation>> getRecommendations({String? unitId}) async {
    final headers = await _authHeaders(required: true);
    final query = unitId != null && unitId.isNotEmpty ? '?unit_id=$unitId' : '';
    final list = await _apiClient.getJsonList(
      '/organizational/recommendations$query',
      headers: headers,
    );
    return list
        .map((e) => OrgRecommendation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AuditLogItem>> getAuditLogs({int limit = 50}) async {
    final headers = await _authHeaders(required: true);
    final list = await _apiClient.getJsonList(
      '/organizational/audit-logs?limit=$limit',
      headers: headers,
    );
    return list
        .map((e) => AuditLogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
