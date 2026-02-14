import 'package:flutter/material.dart';

/// Default (mobile/desktop): use Image.network.
Widget buildNoteImagePreview({
  required String url,
  required double width,
  required double height,
  required BoxFit fit,
  required Widget Function(BuildContext, Widget?, ImageChunkEvent?) loadingBuilder,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    loadingBuilder: loadingBuilder,
    errorBuilder: errorBuilder,
  );
}
