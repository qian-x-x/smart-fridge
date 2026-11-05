import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';

void main() {
  test(
    'validation failures expose field details without type cast crashes',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
      dio.httpClientAdapter = _ErrorAdapter(
        '{"code":"VALIDATION_ERROR","message":"请求参数校验失败","data":[{"field":"quantity","message":"最多 3 位小数"}]}',
        400,
      );
      await expectLater(
        ApiClient(dio).post('/api/v1/foods', {}),
        throwsA(
          isA<ApiFailure>()
              .having((error) => error.statusCode, 'status', 400)
              .having((error) => error.message, 'detail', contains('最多 3 位小数')),
        ),
      );
    },
  );

  test(
    'malformed error metadata is still reported as an API failure',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
      dio.httpClientAdapter = _ErrorAdapter(
        '{"code":42,"message":{},"data":null}',
        503,
      );
      await expectLater(
        ApiClient(dio).get('/api/v1/recipes'),
        throwsA(
          isA<ApiFailure>().having((error) => error.statusCode, 'status', 503),
        ),
      );
    },
  );
  test('sends PATCH JSON and unwraps the API response', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8080'));
    final adapter = _RecordingAdapter();
    dio.httpClientAdapter = adapter;
    final client = ApiClient(dio);

    final response = await client.patch('/api/v1/families/4/members/7', {
      'role': 'EDITOR',
    }, accessToken: 'access');

    expect(adapter.method, 'PATCH');
    expect(adapter.path, '/api/v1/families/4/members/7');
    expect(adapter.authorization, 'Bearer access');
    expect(adapter.body, {'role': 'EDITOR'});
    expect(response['code'], 'OK');
  });
}

class _ErrorAdapter implements HttpClientAdapter {
  _ErrorAdapter(this.body, this.status);
  final String body;
  final int status;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
  @override
  void close({bool force = false}) {}
}

class _RecordingAdapter implements HttpClientAdapter {
  String? method;
  String? path;
  String? authorization;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    path = options.uri.path;
    authorization = options.headers['Authorization'] as String?;
    body = options.data;
    return ResponseBody.fromString(
      '{"code":"OK","message":"success","data":{},"traceId":"test"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
