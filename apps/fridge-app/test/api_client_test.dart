import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_app/core/network/api_client.dart';

void main() {
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
