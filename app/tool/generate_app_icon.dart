// Generates launcher icon assets with Android adaptive-icon safe zone padding.
// Run from app/: dart run tool/generate_app_icon.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart';

final _green = ColorRgb8(45, 106, 79);
final _white = ColorRgb8(255, 255, 255);
const _size = 1024;

/// Symbol occupies the center ~62% — balanced for visibility and adaptive-icon masking.
const _symbolScale = 0.62;

void main() {
  final outDir = Directory('assets/icon');
  outDir.createSync(recursive: true);

  final full = _renderFull();
  File('assets/icon/app_icon.png')
      .writeAsBytesSync(encodePng(full, level: 6));

  final foreground = _renderForeground();
  File('assets/icon/app_icon_foreground.png')
      .writeAsBytesSync(encodePng(foreground, level: 6));

  stdout.writeln('Wrote assets/icon/app_icon.png');
  stdout.writeln('Wrote assets/icon/app_icon_foreground.png');
}

Image _renderFull() {
  final img = Image(width: _size, height: _size);
  fill(img, color: _green);
  _drawSymbol(img, _white);
  return img;
}

Image _renderForeground() {
  final img = Image(width: _size, height: _size);
  _drawSymbol(img, _white);
  return img;
}

void _drawSymbol(Image img, Color color) {
  final box = (_size * _symbolScale).round();
  final offset = ((_size - box) / 2).round();

  final cardW = (box * 0.56).round();
  final cardH = (box * 0.30).round();
  final cardX = offset + ((box - cardW) / 2).round();
  final cardY = offset + box - cardH;
  _fillRoundedRect(img, cardX, cardY, cardW, cardH, (cardH * 0.22).round(), color);

  final lineH = math.max(4, (cardH * 0.11).round());
  final linePadX = (cardW * 0.18).round();
  final line1W = (cardW * 0.52).round();
  final line2W = (cardW * 0.36).round();
  final line1Y = cardY + (cardH * 0.30).round();
  final line2Y = cardY + (cardH * 0.58).round();
  _fillRoundedRect(img, cardX + linePadX, line1Y, line1W, lineH, lineH ~/ 2, color);
  _fillRoundedRect(img, cardX + linePadX, line2Y, line2W, lineH, lineH ~/ 2, color);

  final arrowStemW = math.max(6, (box * 0.055).round());
  final arrowHeadW = (box * 0.22).round();
  final arrowHeadH = (box * 0.14).round();
  final stemTopY = offset + (box * 0.08).round();
  final stemBottomY = cardY - (box * 0.04).round();
  final centerX = offset + box ~/ 2;

  _fillRoundedRect(
    img,
    centerX - arrowStemW ~/ 2,
    stemTopY + arrowHeadH,
    arrowStemW,
    stemBottomY - stemTopY - arrowHeadH,
    arrowStemW ~/ 2,
    color,
  );

  fillPolygon(
    img,
    vertices: [
      Point(centerX, stemTopY),
      Point(centerX - arrowHeadW ~/ 2, stemTopY + arrowHeadH),
      Point(centerX + arrowHeadW ~/ 2, stemTopY + arrowHeadH),
    ],
    color: color,
  );

  final curveW = math.max(5, (box * 0.045).round());
  _fillRoundedRect(
    img,
    centerX - (box * 0.12).round(),
    cardY - (box * 0.18).round(),
    curveW,
    (box * 0.12).round(),
    curveW ~/ 2,
    color,
  );
}

void _fillRoundedRect(
  Image img,
  int x,
  int y,
  int w,
  int h,
  int r,
  Color color,
) {
  r = math.min(r, math.min(w, h) ~/ 2);
  fillRect(img, x1: x + r, y1: y, x2: x + w - r, y2: y + h, color: color);
  fillRect(img, x1: x, y1: y + r, x2: x + w, y2: y + h - r, color: color);
  fillCircle(img, x: x + r, y: y + r, radius: r, color: color);
  fillCircle(img, x: x + w - r, y: y + r, radius: r, color: color);
  fillCircle(img, x: x + r, y: y + h - r, radius: r, color: color);
  fillCircle(img, x: x + w - r, y: y + h - r, radius: r, color: color);
}
