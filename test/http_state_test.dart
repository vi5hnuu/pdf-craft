import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_craft/models/http_state.dart';

/// Errors from tools must explain what went wrong — the server's own reason when there is one,
/// otherwise a clear transport message — and never Dio's internal text.
void main() {
  final req = RequestOptions(path: '/pdf-studio/compress-pdf');

  String? messageFor(DioException e) => HttpState.fromDio(e, 'Failed to compress PDF').error;

  test('prefers the server message from a JSON map body', () {
    final e = DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: req, statusCode: 402, data: {'message': 'Not enough credits'}),
    );
    expect(messageFor(e), 'Not enough credits');
    expect(HttpState.fromDio(e, 'x').isOutOfCredits, isTrue);
  });

  test('decodes the server message from a bytes body (file tools)', () {
    final body = utf8.encode(jsonEncode({'message': 'That file is larger than the upload limit.'}));
    final e = DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: req, statusCode: 413, data: body),
    );
    expect(messageFor(e), 'That file is larger than the upload limit.');
  });

  test('413 without a readable body still explains the limit', () {
    final e = DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: req, statusCode: 413, data: 'nope'),
    );
    expect(messageFor(e), HttpState.msgTooLarge);
  });

  test('connection errors say the server is unreachable, keeping the offline message', () {
    expect(messageFor(DioException(requestOptions: req, type: DioExceptionType.connectionError)),
        HttpState.msgUnreachable);
    expect(
        messageFor(DioException(
            requestOptions: req,
            type: DioExceptionType.connectionError,
            message: HttpState.msgNoInternet)),
        HttpState.msgNoInternet);
  });

  test('timeouts and dropped uploads get their own messages', () {
    expect(messageFor(DioException(requestOptions: req, type: DioExceptionType.sendTimeout)),
        HttpState.msgTimeout);
    expect(
        messageFor(DioException(
            requestOptions: req,
            type: DioExceptionType.unknown,
            error: const HttpException('Connection closed before full header was received'))),
        HttpState.msgInterrupted);
  });

  test('anything else falls back to the tool message, never Dio text', () {
    final e = DioException(
      requestOptions: req,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: req, statusCode: 500, data: null),
      message: 'Http status error [500]',
    );
    expect(messageFor(e), 'Failed to compress PDF');
  });
}
