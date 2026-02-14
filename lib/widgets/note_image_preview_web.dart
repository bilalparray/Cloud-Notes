// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

int _nextViewId = 0;
final Map<String, String> _viewTypeByUrl = {};

/// Web: use native <img> so Firebase Storage URLs load without CORS (browser loads img directly).
Widget buildNoteImagePreview({
  required String url,
  required double width,
  required double height,
  required BoxFit fit,
  required Widget Function(BuildContext, Widget?, ImageChunkEvent?) loadingBuilder,
  required Widget Function(BuildContext, Object, StackTrace?) errorBuilder,
}) {
  final viewType = _viewTypeByUrl.putIfAbsent(url, () {
    final type = 'note-img-${_nextViewId++}';
    final urlForFactory = url;
    ui_web.platformViewRegistry.registerViewFactory(
      type,
      (int viewId) {
        final img = html.ImageElement()
          ..src = urlForFactory
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.objectFit = _objectFit(fit);
        return img;
      },
    );
    return type;
  });
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewType),
  );
}

String _objectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.cover:
      return 'cover';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.fitWidth:
      return 'scale-down';
    case BoxFit.fitHeight:
      return 'scale-down';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
  }
}
