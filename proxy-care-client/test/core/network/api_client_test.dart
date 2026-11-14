import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxy_care_client/core/error/app_exception.dart';
import 'package:proxy_care_client/core/network/api_client.dart';
import 'package:proxy_care_client/core/network/api_response.dart';
import 'package:proxy_care_client/core/network/idempotency_key.dart';
import 'package:proxy_care_client/core/network/pagination.dart';
import 'package:proxy_care_client/core/network/request_options.dart';
import 'package:proxy_care_client/core/network/response_parser.dart';
import 'package:proxy_care_client/core/network/transfer.dart';

import '../../helpers/fake_http_adapter.dart';
import '../../helpers/network_harness.dart';

/// A feature-agnostic DTO for decoding tests.
final class _Item {
  const _Item(this.id, this.label);

  factory _Item.fromJson(Object? json) {
    final map = json! as Map<String, Object?>;
    return _Item(map['id']! as String, map['label']! as String);
  }

  final String id;
  final String label;
}

void main() {
  group('ResponseParser', () {
    const parser = ResponseParser();

    test('decodes the envelope data with the typed decoder', () {
      final response = parser.parse(
        successEnvelope(
          {'id': 'a1', 'label': 'First'},
          meta: {'correlationId': 'abc-123', 'timestamp': 't'},
        ),
        _Item.fromJson,
        statusCode: 200,
      );

      expect(response, isA<ApiResponse<_Item>>());
      expect(response.data.label, 'First');
      expect(response.meta.correlationId, 'abc-123');
      expect(response.meta.timestamp, 't');
      expect(response.statusCode, 200);
    });

    test('passes null data to a nullable decoder', () {
      final response = parser.parse<_Item?>(
        successEnvelope(null),
        (json) => json == null ? null : _Item.fromJson(json),
        statusCode: 200,
      );

      expect(response.data, isNull);
    });

    test('an empty body (204) decodes as null', () {
      for (final body in <Object?>[null, '', '  ']) {
        final response = parser.parse(body, ignoreBody, statusCode: 204);
        expect(response.statusCode, 204);
      }
    });

    test('an empty body with a non-null decoder is an invalid response', () {
      expect(
        () => parser.parse(null, _Item.fromJson, statusCode: 204),
        throwsA(
          isA<ServerException>().having(
            (e) => e.invalidResponse,
            'invalidResponse',
            isTrue,
          ),
        ),
      );
    });

    test('a raw (non-enveloped) body goes to the decoder whole', () {
      final response = parser.parse(
        [
          {'id': 'a1', 'label': 'First'},
          {'id': 'a2', 'label': 'Second'},
        ],
        listDecoder(_Item.fromJson),
        statusCode: 200,
        format: ResponseFormat.raw,
      );

      expect(response.data.map((i) => i.id), ['a1', 'a2']);
      expect(response.meta, same(ResponseMeta.empty));
    });

    test('an envelope sent as text is still read', () {
      final response = parser.parse(
        jsonEncode(successEnvelope({'id': 'a1', 'label': 'First'})),
        _Item.fromJson,
        statusCode: 200,
      );

      expect(response.data.id, 'a1');
    });

    test('a body that is not the envelope is an invalid response', () {
      for (final body in <Object?>[
        {'id': 'a1'},
        [1, 2],
        'plain text',
      ]) {
        expect(
          () => parser.parse(body, _Item.fromJson, statusCode: 200),
          throwsA(isA<ServerException>()),
          reason: '$body',
        );
      }
    });

    test('a data shape mismatch is a serialization failure', () {
      expect(
        () => parser.parse(
          successEnvelope({'id': 1}),
          _Item.fromJson,
          statusCode: 200,
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.invalidResponse,
            'invalidResponse',
            isTrue,
          ),
        ),
      );
    });

    test('an error envelope in a 2xx is classified by its code', () {
      expect(
        () => parser.parse(
          errorEnvelope(
            'VALIDATION_ERROR',
            fieldErrors: {
              'email': ['Invalid email address'],
            },
          ),
          ignoreBody,
          statusCode: 200,
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors,
            'fieldErrors',
            {
              'email': ['Invalid email address'],
            },
          ),
        ),
      );
      expect(
        () => parser.parse(
          errorEnvelope('NOT_FOUND'),
          ignoreBody,
          statusCode: 200,
        ),
        throwsA(isA<NotFoundException>()),
      );
      expect(
        () => parser.parse(
          errorEnvelope('SOMETHING_NEW'),
          ignoreBody,
          statusCode: 200,
        ),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('DioApiClient', () {
    test('GET with query parameters decodes the typed payload', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(successEnvelope({'id': 'a1', 'label': 'First'})),
        ],
      );

      final response = await harness.client.get(
        '/v1/items/a1',
        query: {'expand': 'details'},
        decode: _Item.fromJson,
      );

      expect(response.data.label, 'First');
      final sent = harness.adapter.requests.single;
      expect(sent.method, 'GET');
      expect(
        sent.uri.toString(),
        'https://api.proxycare.test/v1/items/a1?expand=details',
      );
      expect(sent.headers['Accept'], 'application/json');
    });

    test('POST, PUT, PATCH and DELETE send JSON bodies', () async {
      final harness = NetworkHarness()
        ..adapter.fallback = respondJson(successEnvelope(null));
      const body = {'label': 'Updated'};

      await harness.client.post('/v1/items', body: body, decode: ignoreBody);
      await harness.client.put('/v1/items/a1', body: body, decode: ignoreBody);
      await harness.client.patch(
        '/v1/items/a1',
        body: body,
        decode: ignoreBody,
      );
      await harness.client.delete('/v1/items/a1', decode: ignoreBody);

      final requests = harness.adapter.requests;
      expect(requests.map((r) => r.method), [
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
      ]);
      for (final request in requests.take(3)) {
        expect(request.headers['content-type'], Headers.jsonContentType);
        expect(jsonDecode(utf8.decode(request.body!)), body);
      }
      expect(requests.last.body, isNull);
    });

    test('sends custom headers, idempotency keys and timeouts', () async {
      final harness = NetworkHarness(
        responses: [respondJson(successEnvelope(null))],
      );
      final key = IdempotencyKey.generate();

      await harness.client.post(
        '/v1/bookings',
        body: const {'patientId': 'p1'},
        decode: ignoreBody,
        options: ApiRequestOptions(
          headers: const {'X-App-Version': '0.1.0'},
          idempotencyKey: key,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 7),
        ),
      );

      final sent = harness.adapter.requests.single;
      expect(sent.headers['X-App-Version'], '0.1.0');
      expect(sent.headers['Idempotency-Key'], key);
      expect(sent.receiveTimeout, const Duration(seconds: 5));
      expect(sent.sendTimeout, const Duration(seconds: 7));
      expect(IdempotencyKey.generate(), isNot(key));
    });

    test(
      'error responses throw mapped AppExceptions, never Dio types',
      () async {
        final harness = NetworkHarness(
          responses: [
            respondJson(
              errorEnvelope(
                'VALIDATION_ERROR',
                fieldErrors: {
                  'mobile': ['Enter 10 digits'],
                },
                correlationId: 'abc-123',
              ),
              status: 422,
            ),
          ],
        );

        await expectLater(
          harness.client.post('/v1/users', body: const {}, decode: ignoreBody),
          throwsA(
            isA<ValidationException>()
                .having((e) => e.fieldErrors['mobile'], 'mobile', [
                  'Enter 10 digits',
                ])
                .having((e) => e.correlationId, 'correlationId', 'abc-123')
                .having((e) => e.cause, 'cause', isA<DioException>()),
          ),
        );
      },
    );

    test('a 503 after every retry becomes a ServerException', () async {
      final harness = NetworkHarness()
        ..adapter.fallback = respondJson(
          errorEnvelope('SERVICE_UNAVAILABLE'),
          status: 503,
        );

      await expectLater(
        harness.client.get('/v1/items', decode: ignoreBody),
        throwsA(
          isA<ServerException>().having((e) => e.statusCode, 'status', 503),
        ),
      );
      expect(harness.adapter.requests, hasLength(4));
    });

    test('cancellation stops the request with CancelledException', () async {
      final harness = NetworkHarness(
        responses: [respondJson(successEnvelope(null))],
      );
      final cancellation = RequestCancellation()..cancel();

      await expectLater(
        harness.client.get(
          '/v1/items',
          decode: ignoreBody,
          options: ApiRequestOptions(cancellation: cancellation),
        ),
        throwsA(isA<CancelledException>()),
      );
      expect(cancellation.isCancelled, isTrue);
      expect(harness.adapter.requests, isEmpty);
      expect(harness.delays, isEmpty);
    });

    test('uploads files and fields as multipart/form-data', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(successEnvelope({'id': 'f1', 'label': 'x'})),
        ],
      );
      final progress = <int>[];

      final response = await harness.client.upload(
        '/v1/files',
        files: [
          UploadFile(
            field: 'file',
            bytes: Uint8List.fromList(utf8.encode('%PDF-1.7')),
            filename: 'bill.pdf',
            contentType: 'application/pdf',
          ),
        ],
        fields: const {'kind': 'HOSPITAL_BILL'},
        decode: _Item.fromJson,
        onProgress: (done, _) => progress.add(done),
      );

      expect(response.data.id, 'f1');
      final sent = harness.adapter.requests.single;
      expect(sent.method, 'POST');
      expect(
        sent.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final form = sent.data! as FormData;
      expect(form.fields.single, isA<MapEntry<String, String>>());
      expect(form.fields.single.key, 'kind');
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'bill.pdf');
      expect(
        form.files.single.value.contentType.toString(),
        'application/pdf',
      );
      final text = utf8.decode(sent.body!, allowMalformed: true);
      expect(text, contains('name="kind"'));
      expect(text, contains('HOSPITAL_BILL'));
      expect(text, contains('filename="bill.pdf"'));
      expect(progress, isNotEmpty);
    });

    test('downloads bytes with content type and file name', () async {
      final harness = NetworkHarness(
        responses: [
          respondBytes(
            [37, 80, 68, 70],
            headers: {
              'content-type': ['application/pdf'],
              'content-disposition': ['attachment; filename="receipt.pdf"'],
            },
          ),
        ],
      );

      final file = await harness.client.download('/v1/receipts/r1');

      expect(file.bytes, [37, 80, 68, 70]);
      expect(file.contentType, 'application/pdf');
      expect(file.filename, 'receipt.pdf');
    });
  });

  group('pagination', () {
    test('a page request becomes cursor and limit query parameters', () {
      expect(const PageRequest().toQuery(), {'limit': 20});
      expect(const PageRequest(cursor: 'c2', limit: 50).toQuery(), {
        'limit': 50,
        'cursor': 'c2',
      });
      expect(
        const PageRequest(
          cursor: 'c2',
          cursorParameter: 'after',
          limitParameter: 'size',
        ).toQuery(),
        {'size': 20, 'after': 'c2'},
      );
    });

    test('reads a page from data and meta.nextCursor', () async {
      final harness = NetworkHarness(
        responses: [
          respondJson(
            successEnvelope(
              [
                {'id': 'a1', 'label': 'First'},
              ],
              meta: {'nextCursor': 'c2'},
            ),
          ),
          respondJson(
            successEnvelope(
              [
                {'id': 'a2', 'label': 'Second'},
              ],
              meta: {'nextCursor': null},
            ),
          ),
        ],
      );
      const first = PageRequest(limit: 1);

      final page1 = CursorPage.fromResponse(
        await harness.client.get(
          '/v1/items',
          query: first.toQuery(),
          decode: listDecoder(_Item.fromJson),
        ),
      );
      final second = first.next(page1)!;
      final page2 = CursorPage.fromResponse(
        await harness.client.get(
          '/v1/items',
          query: second.toQuery(),
          decode: listDecoder(_Item.fromJson),
        ),
      );

      expect(page1.items.single.id, 'a1');
      expect(page1.hasMore, isTrue);
      expect(harness.adapter.requests.last.uri.queryParameters, {
        'limit': '1',
        'cursor': 'c2',
      });
      expect(page2.items.single.id, 'a2');
      expect(page2.hasMore, isFalse);
      expect(first.next(page2), isNull);
      expect(() => page1.items.add(page2.items.single), throwsUnsupportedError);
    });
  });
}
