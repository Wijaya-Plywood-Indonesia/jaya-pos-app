import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.status});

  final String message;
  final int? status;

  @override
  String toString() => message;
}

/// Kena pembatas laju (server atau penguncian PIN offline). [until] = kapan boleh mencoba lagi.
class RateLimitedException extends ApiException {
  RateLimitedException(this.until)
      : super('Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.', status: 429);

  final DateTime until;
}

class Api {
  Api(String baseUrl, {this.token})
      : _dio = Dio(
          BaseOptions(
            baseUrl: '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/api/v1',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'},
          ),
        );

  final Dio _dio;
  final String? token;

  Options get _options => Options(
        headers: token == null ? null : {'Authorization': 'Bearer $token'},
      );

  Future<Map<String, dynamic>> get(String path) {
    return _send(() => _dio.get<Map<String, dynamic>>(path, options: _options));
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) {
    return _send(
      () => _dio.post<Map<String, dynamic>>(path, data: data, options: _options),
    );
  }

  Future<Map<String, dynamic>> _send(
    Future<Response<Map<String, dynamic>>> Function() call,
  ) async {
    try {
      final res = await call();
      return res.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      if (status == 401) {
        throw ApiException('Sesi berakhir. Silakan masuk lagi.', status: 401);
      }
            if (status == 429) {
        // Laravel menyertakan sisa detik di header Retry-After
        final secs = int.tryParse(e.response?.headers.value('retry-after') ?? '') ?? 60;
        throw RateLimitedException(DateTime.now().add(Duration(seconds: secs)));
      }

      final body = e.response?.data;
      if (body is Map && body['message'] is String) {
        throw ApiException(body['message'] as String, status: status);
      }
      if (e.response != null) {
        throw ApiException('Server mengirim kesalahan ($status).', status: status);
      }
      throw ApiException(
        'Tidak bisa terhubung ke server. Periksa alamat server dan koneksi internet.',
      );
    } on TypeError {
      throw ApiException('Respons server tidak dikenali.');
    }
  }
}