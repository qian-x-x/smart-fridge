import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smart_fridge_app/core/config/app_config.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: const {'Accept': 'application/json'},
    ),
  );
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(dioProvider));
});

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? accessToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(
          headers: {
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
        ),
      );
      return _unwrap(response);
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map<String, dynamic>) {
        throw ApiFailure(
          body['message'] as String? ?? '请求未完成，请稍后重试',
          statusCode: error.response?.statusCode,
          code: body['code'] as String?,
        );
      }
      throw ApiFailure(
        error.type == DioExceptionType.connectionError
            ? '无法连接服务，请确认 Gateway 已启动'
            : '网络请求失败，请稍后重试',
        statusCode: error.response?.statusCode,
      );
    }
  }

  Map<String, dynamic> _unwrap(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) {
      throw const ApiFailure('服务返回了空响应');
    }
    if (body['code'] != 'OK') {
      throw ApiFailure(
        body['message'] as String? ?? '请求失败',
        statusCode: response.statusCode,
        code: body['code'] as String?,
      );
    }
    return body;
  }
}

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;
}
