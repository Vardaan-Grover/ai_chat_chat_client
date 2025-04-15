import 'dart:io';

import 'package:ai_chat_chat_client/services/extensions/size_string_extension.dart';
import 'package:ai_chat_chat_client/services/platform/platform_infos.dart';
import 'package:ai_chat_chat_client/views/widgets/dialogs/future_loading_dialog.dart';
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:matrix/matrix.dart';
import 'package:share_plus/share_plus.dart';

extension MatrixFileExtension on MatrixFile {
  void save(BuildContext context) async {

    final downloadPath =
        !PlatformInfos.isMobile
            ? (await getSaveLocation(
              suggestedName: name,
              confirmButtonText: 'Save File',
            ))?.path
            : await FilePicker.platform.saveFile(
              dialogTitle: 'Save File',
              fileName: name,
              type: filePickerFileType,
              bytes: bytes,
            );
    if (downloadPath == null) return;

    if (PlatformInfos.isDesktop) {
      final result = await showFutureLoadingDialog(
        context: context,
        future: () => File(downloadPath).writeAsBytes(bytes),
      );
      if (result.error != null) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('File has been saved at $downloadPath'),
      ),
    );
  }

  FileType get filePickerFileType {
    if (this is MatrixImageFile) return FileType.image;
    if (this is MatrixAudioFile) return FileType.audio;
    if (this is MatrixVideoFile) return FileType.video;
    return FileType.any;
  }

  void share(BuildContext context) async {
    // Workaround for iPad from
    // https://github.com/fluttercommunity/plus_plugins/tree/main/packages/share_plus/share_plus#ipad
    final box = context.findRenderObject() as RenderBox?;

    await Share.shareXFiles(
      [XFile.fromData(bytes, name: name, mimeType: mimeType)],
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
    return;
  }

  MatrixFile get detectFileType {
    if (msgType == MessageTypes.Image) {
      return MatrixImageFile(bytes: bytes, name: name);
    }
    if (msgType == MessageTypes.Video) {
      return MatrixVideoFile(bytes: bytes, name: name);
    }
    if (msgType == MessageTypes.Audio) {
      return MatrixAudioFile(bytes: bytes, name: name);
    }
    return this;
  }

  String get sizeString => size.sizeString;
}
