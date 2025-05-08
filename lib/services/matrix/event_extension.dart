import 'dart:developer';

import 'package:ai_chat_chat_client/services/extensions/size_string_extension.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/future_loading_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:async/async.dart' as async;
import 'package:matrix/matrix.dart';

import 'matrix_file_extension.dart';

extension LocalizedBody on Event {
  Future<async.Result<MatrixFile?>> _getFile(BuildContext context) =>
      showFutureLoadingDialog(
        context: context,
        future: downloadAndDecryptAttachment,
      );

  void saveFile(BuildContext context) async {
    final matrixFile = await _getFile(context);
    if (context.mounted) {
      matrixFile.result?.save(context);
    }
  }

  void shareFile(BuildContext context) async {
    final matrixFile = await _getFile(context);
    inspect(matrixFile);

    if (context.mounted) {
      matrixFile.result?.share(context);
    }
  }

  bool get isAttachmentSmallEnough =>
      infoMap['size'] is int &&
      infoMap['size'] < room.client.database!.maxFileSize;

  bool get isThumbnailSmallEnough =>
      thumbnailInfoMap['size'] is int &&
      thumbnailInfoMap['size'] < room.client.database!.maxFileSize;

  bool get showThumbnail =>
      [
        MessageTypes.Image,
        MessageTypes.Sticker,
        MessageTypes.Video,
      ].contains(messageType) &&
      (kIsWeb ||
          isAttachmentSmallEnough ||
          isThumbnailSmallEnough ||
          (content['url'] is String));

  String? get sizeString =>
      content
          .tryGetMap<String, dynamic>('info')
          ?.tryGet<int>('size')
          ?.sizeString;
}
