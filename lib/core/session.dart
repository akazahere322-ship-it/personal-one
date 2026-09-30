import 'package:flutter/foundation.dart';
import 'api.dart';

class Session extends ChangeNotifier {
  static final Session i = Session._();
  Session._() {
    Api.i.onUnauthorized = () {
      if (loggedIn) clear();
    };
  }

  Map<String, dynamic> data = {};
  Map<String, dynamic> options = {};
  bool loggedIn = false;

  String get name => data['full_name'] ?? '';
  String get employeeNo => data['employee_no'] ?? '';
  int? get employeeId => data['employee_id'] is int ? data['employee_id'] : int.tryParse('${data['employee_id']}');
  String get company => (data['company'] ?? {})['name'] ?? '';
  String get role => data['role'] ?? '';
  String get scope => data['data_scope'] ?? 'own';
  List get pages => data['pages'] ?? [];

  bool has(String key) => pages.any((p) => p['page_key'] == key);
  bool can(String key, String action) => (data['permissions']?[key]?[action]) == true;

  Future<void> _apply(Map<String, dynamic> j) async {
    data = j;
    loggedIn = true;
    try {
      options = await Api.i.get('/meta/options/'); // dropdowns: load once, keep
    } catch (_) {}
    notifyListeners();
  }

  Future<void> restore() async {
    await Api.i.loadToken();
    if (Api.i.token == null) return;
    try {
      await _apply(await Api.i.get('/auth/session/'));
    } on ApiException catch (e) {
      if (e.status == 401) await Api.i.saveToken(null);
    } catch (_) {}
  }

  Future<void> login(String user, String pass) async {
    final r = await Api.i.post('/auth/login/', {'username': user, 'password': pass, 'device_label': 'Flutter app'});
    await Api.i.saveToken(r['token']);
    await _apply(r);
  }

  Future<void> refresh() async => _apply(await Api.i.get('/auth/session/'));

  Future<void> logout() async {
    try {
      await Api.i.post('/auth/logout/');
    } catch (_) {}
    await clear();
  }

  Future<void> clear() async {
    await Api.i.saveToken(null);
    loggedIn = false;
    data = {};
    notifyListeners();
  }

  List<String> lookup(String k) => List<String>.from(((options['lookups'] ?? {})[k] ?? []).map((e) => '$e'));
  List<String> choice(String k) => List<String>.from(((options['choices'] ?? {})[k] ?? []).map((e) => '$e'));
  List<Map<String, dynamic>> get departments => List<Map<String, dynamic>>.from(options['departments'] ?? []);
  List<String> get designations => List<String>.from((options['designations'] ?? []).map((e) => '$e'));
  List<String> get documentTypes => List<String>.from((options['document_types'] ?? []).map((e) => '$e'));
}
