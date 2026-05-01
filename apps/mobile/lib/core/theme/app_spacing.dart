import 'package:flutter/material.dart';

/// 4 pt grid — tutarlı boşluk ve dokunma hedefleri (min ~48dp).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double section = 28;

  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: 20);

  static EdgeInsets sliverT({double top = 0, double bottom = 0}) =>
      EdgeInsets.fromLTRB(20, top, 20, bottom);
}
