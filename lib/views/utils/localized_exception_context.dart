import 'dart:io';
import 'dart:math';

import 'package:ai_chat_chat_client/services/matrix/other_party_can_receive_extension.dart';
import 'package:ai_chat_chat_client/services/matrix/uia_request_manager.dart';
import 'package:flutter/material.dart';

import 'package:http/http.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

extension LocalizedExceptionExtension on Object {
  static String _formatFileSize(int size) {
    if (size < 1000) return '$size B';
    final i = (log(size) / log(1000)).floor();
    final num = (size / pow(1000, i));
    final round = num.round();
    final numString =
        round < 10
            ? num.toStringAsFixed(2)
            : round < 100
            ? num.toStringAsFixed(1)
            : round.toString();
    return '$numString ${'kMGTPEZY'[i - 1]}B';
  }

  String toLocalizedString(
    BuildContext context, [
    ExceptionContext? exceptionContext,
  ]) {
    if (this is FileTooBigMatrixException) {
      final exception = this as FileTooBigMatrixException;
      return 'Unable to back up the file on server. The server only supports files up to ${_formatFileSize(exception.maxFileSize)}.';
    }
    if (this is OtherPartyCanNotReceiveMessages) {
      return 'The other party is currently not logged in and therefore cannot receive messages!';
    }
    if (this is MatrixException) {
      switch ((this as MatrixException).error) {
        case MatrixError.M_FORBIDDEN:
          if (exceptionContext == ExceptionContext.changePassword) {
            return 'Entered password is wrong';
          }
          return 'No permission';
        case MatrixError.M_LIMIT_EXCEEDED:
          return 'Too many requests. Please try again later!';
        default:
          if (exceptionContext == ExceptionContext.joinRoom) {
            return 'Unable to join chat. Maybe the other party has already closed the conversation.';
          }
          return (this as MatrixException).errorMessage;
      }
    }
    if (this is InvalidPassphraseException) {
      return 'Sorry... this does not seem to be the correct recovery key.';
    }
    if (this is BadServerLoginTypesException) {
      final serverVersions = (this as BadServerLoginTypesException)
          .serverLoginTypes
          .toString()
          .replaceAll('{', '"')
          .replaceAll('}', '"');
      final supportedVersions = (this as BadServerLoginTypesException)
          .supportedLoginTypes
          .toString()
          .replaceAll('{', '"')
          .replaceAll('}', '"');
      return 'The server does not support the login type you are trying to use.';
    }
    if (this is IOException ||
        this is SocketException ||
        this is SyncConnectionException ||
        this is ClientException) {
      return 'No connection to the server';
    }
    if (this is FormatException &&
        exceptionContext == ExceptionContext.checkHomeserver) {
      return 'Doesn\'t seem to be a compatible homeserver. Wrong URL?';
    }
    if (this is FormatException &&
        exceptionContext == ExceptionContext.checkServerSupportInfo) {
      return 'Server does not provide any valid contact information';
    }
    if (this is String) return toString();
    if (this is UiaException) return toString();

    if (exceptionContext == ExceptionContext.joinRoom) {
      return 'Unable to join chat. Maybe the other party has already closed the conversation.';
    }

    Logs().w('Something went wrong: ', this);
    return 'Oops, something went wrong…';
  }
}

enum ExceptionContext {
  changePassword,
  checkHomeserver,
  checkServerSupportInfo,
  joinRoom,
}
