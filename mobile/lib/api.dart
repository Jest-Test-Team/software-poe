import 'dart:convert';

import 'package:http/http.dart' as http;

/// Configure at build time:
/// flutter run --dart-define=API_BASE_URL=... --dart-define=API_KEY=...
const apiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8081');
const apiKey = String.fromEnvironment('API_KEY', defaultValue: '');
const tenantId =
    String.fromEnvironment('TENANT_ID', defaultValue: 'synthetic-lab');

class Assessment {
  final String id;
  final String status;
  final String summary;
  final double uncertainty;
  final bool gapDetected;
  final bool missingData;
  final bool staleEvidence;
  final String? ruleVersion;
  final List<String> evidenceRefs;

  Assessment.fromJson(Map<String, dynamic> json)
      : id = json['assessment_id'] as String,
        status = json['status'] as String,
        summary = json['summary'] as String,
        uncertainty = (json['uncertainty'] as num).toDouble(),
        gapDetected = json['gap_detected'] as bool,
        missingData = json['missing_data'] as bool,
        staleEvidence = json['stale_evidence'] as bool,
        ruleVersion = json['rule_version'] as String?,
        evidenceRefs = List<String>.from(json['evidence_refs'] as List);
}

class PoeApi {
  final http.Client _client;

  PoeApi([http.Client? client]) : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'X-API-Key': apiKey,
      };

  Future<List<Assessment>> reviewQueue() async {
    final uri = Uri.parse('$apiBaseUrl/v1/software-poe/assessments').replace(
        queryParameters: {'tenant_id': tenantId, 'status': 'review-required'});
    final resp = await _client.get(uri, headers: _headers);
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list
        .map((e) => Assessment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> review(String assessmentId,
      {required String reviewer,
      required String decision,
      String? annotation}) async {
    final uri = Uri.parse(
            '$apiBaseUrl/v1/software-poe/assessments/$assessmentId/review')
        .replace(queryParameters: {'tenant_id': tenantId});
    final resp = await _client.post(uri,
        headers: _headers,
        body: jsonEncode({
          'reviewer': reviewer,
          'decision': decision,
          'annotation': annotation,
        }));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }
}
