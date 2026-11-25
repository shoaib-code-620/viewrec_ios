import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Opens the full photo editor (crop, rotate, filters, tune, text, stickers, drawing, blur).
/// Returns the edited photo as a new file, or null if the user backed out.
Future<XFile?> editPhoto(BuildContext context, XFile src) async {
  if (kIsWeb) return src; // the editor runs on phones; the browser preview keeps the original
  var finished = false;
  return Navigator.of(context).push<XFile>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (ctx) => ProImageEditor.file(
      File(src.path),
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (bytes) async {
          final f = File('${Directory.systemTemp.path}/viewrec_photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await f.writeAsBytes(bytes);
          finished = true;
          if (ctx.mounted) Navigator.of(ctx).pop(XFile(f.path));
        },
        onCloseEditor: (_) {
          if (!finished && ctx.mounted && Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
        },
      ),
    ),
  ));
}
