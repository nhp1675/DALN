import 'dart:convert';
import 'package:http/http.dart' as http;
import '../platform/http_client.dart';

typedef Json = Map<String, dynamic>;
Json asMap(dynamic value) => Map<String, dynamic>.from(value as Map);
List<Json> asList(dynamic value) => (value as List).map(asMap).toList();
String sid(dynamic value) => value?.toString() ?? '';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class Api {
  final http.Client client;
  final String baseUrl;
  String csrf = '';
  Api({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment('API_BASE_URL'),
  }) : client = client ?? createClient();
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Json? body,
  }) async {
    final uri = Uri.parse('$baseUrl/api$path');
    final request = http.Request(method, uri);
    request.headers['Content-Type'] = 'application/json';
    if (csrf.isNotEmpty) request.headers['x-csrf-token'] = csrf;
    if (body != null) request.body = jsonEncode(body);
    http.Response response;
    try {
      response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 20)),
      );
    } catch (_) {
      throw ApiException(
        0,
        'Không kết nối được máy chủ. Kiểm tra backend và thử lại.',
      );
    }
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        response.statusCode,
        'Phản hồi không hợp lệ. Kiểm tra địa chỉ API.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        response.statusCode,
        data is Map ? sid(data['message']) : 'Yêu cầu thất bại.',
      );
    }
    return data;
  }

  void close() => client.close();
}
