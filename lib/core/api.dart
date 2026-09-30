import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

enum Company { sbig, meltis }

const _baseUrls = {
  Company.sbig: 'https://hrms.melticetech.com/api/v1', 
  Company.meltis: 'https://mithrms.melticetech.com/api/v1',
};

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class Api {
  static final Api i = Api._();
  Api._();
  final _store = const FlutterSecureStorage();
  Company _company = Company.meltis;
  String? token;
  void Function()? onUnauthorized;

  Future<void> loadCompany() async {
    final saved = await _store.read(key: 'company');
    _company = Company.values.firstWhere(
      (company) => company.name == saved,
      orElse: () => Company.meltis,
    );
  }

  Future<void> setCompany(Company company) async {
    _company = company;
    await _store.write(key: 'company', value: company.name);
  }

  Company get company => _company;

  String get _baseUrl => _baseUrls[_company]!;

  Future<void> loadToken() async => token = await _store.read(key: 'token');
  Future<void> saveToken(String? t) async {
    token = t;
    if (t == null) {
      await _store.delete(key: 'token');
    } else {
      await _store.write(key: 'token', value: t);
    }
  }

  Map<String, String> get _auth => {if (token != null) 'Authorization': 'Bearer $token'};
  Map<String, String> get _json => {'Content-Type': 'application/json', ..._auth};
  Uri _u(String p) => Uri.parse(p.startsWith('http') ? p : '$_baseUrl$p');

  dynamic _handle(http.Response r) {
    if (r.statusCode == 401 && token != null) onUnauthorized?.call();
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return null;
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    throw ApiException(r.statusCode, _msg(r));
  }

  String _flat(dynamic b) {
    if (b is String) return b;
    if (b is List) return b.map(_flat).join('\n');
    if (b is Map) return b.entries.map((e) => e.key == 'detail' ? _flat(e.value) : '${e.key}: ${_flat(e.value)}').join('\n');
    return '$b';
  }

  String _msg(http.Response r) {
    String? m;
    try {
      m = _flat(jsonDecode(utf8.decode(r.bodyBytes)));
    } catch (_) {}
    switch (r.statusCode) {
      case 401:
        return m ?? 'Invalid username or password.';
      case 403:
        return m ?? 'You do not have permission.';
      case 404:
        return 'Not found.';
      case 429:
        return 'Too many requests. Please wait a few seconds and retry.';
    }
    return (m == null || m.isEmpty) ? 'Request failed (${r.statusCode}).' : m;
  }

  Future<dynamic> get(String p) async => _handle(await http.get(_u(p), headers: _json));
  Future<dynamic> post(String p, [Map<String, dynamic>? body]) async =>
      _handle(await http.post(_u(p), headers: _json, body: body == null ? null : jsonEncode(body)));
  Future<dynamic> patch(String p, Map<String, dynamic> body) async =>
      _handle(await http.patch(_u(p), headers: _json, body: jsonEncode(body)));

  /// Follows "next" until null and returns every row.
  Future<List<Map<String, dynamic>>> getAll(String p) async {
    final out = <Map<String, dynamic>>[];
    String? next = p;
    for (var i = 0; next != null && i < 40; i++) {
      final r = await get(next);
      out.addAll(List<Map<String, dynamic>>.from(r['results']));
      next = r['next'];
    }
    return out;
  }

  /// Add / edit employee with files (multipart/form-data).
  Future<dynamic> multipart(String method, String p, Map<String, String> fields, Map<String, String> filePaths) async {
    final req = http.MultipartRequest(method, _u(p))..headers.addAll(_auth)..fields.addAll(fields);
    for (final e in filePaths.entries) {
      req.files.add(await http.MultipartFile.fromPath(e.key, e.value));
    }
    return _handle(await http.Response.fromStream(await req.send()));
  }

  /// Add / edit with several files under the SAME field name (e.g. doc_files:
  /// first = main file, rest = extra pages).
  Future<dynamic> multipartMulti(String p, Map<String, String> fields, String fileField, List<String> filePaths) async {
    final req = http.MultipartRequest('POST', _u(p))..headers.addAll(_auth)..fields.addAll(fields);
    for (final path in filePaths) {
      req.files.add(await http.MultipartFile.fromPath(fileField, path));
    }
    return _handle(await http.Response.fromStream(await req.send()));
  }

  /// PDF download: returns bytes + filename.
  Future<(List<int>, String)> download(String p, String fallback) async {
    final r = await http.get(_u(p), headers: _auth);
    if (r.statusCode != 200) _handle(r);
    final cd = r.headers['content-disposition'] ?? '';
    final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
    return (r.bodyBytes, m?.group(1) ?? fallback);
  }
}
