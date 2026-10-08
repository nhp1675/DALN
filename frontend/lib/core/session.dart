import 'package:flutter/foundation.dart';
import 'api.dart';

class Session extends ChangeNotifier {
  final Api api;
  Json? user;
  Json config = {};
  bool loading = true;
  String? startupError;
  Session(this.api);
  bool get isAdmin => user?['role'] == 'admin';
  bool get isDemo => config['paymentMode'] == 'demo';
  Json get policy => config['policy'] is Map ? asMap(config['policy']) : {};
  Future<void> initialize() async {
    try {
      config = asMap(await api.request('/config'));
    } catch (e) {
      startupError = '$e';
    }
    await refresh();
    loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final data = asMap(await api.request('/auth/me'));
      user = asMap(data['user']);
      api.csrf = sid(data['csrf']);
    } on ApiException catch (e) {
      if (e.status == 401) {
        user = null;
        api.csrf = '';
      } else {
        startupError = e.message;
      }
    }
    notifyListeners();
  }

  Future<void> authenticate(Json body, {bool register = false}) async {
    final data = asMap(
      await api.request(
        '/auth/${register ? 'register' : 'login'}',
        method: 'POST',
        body: body,
      ),
    );
    user = asMap(data['user']);
    api.csrf = sid(data['csrf']);
    startupError = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await api.request('/auth/logout', method: 'POST');
    user = null;
    api.csrf = '';
    notifyListeners();
  }
}
