import 'package:flutter/material.dart';

/// Colour filters offered in the editors. Each is a 4x5 colour matrix (null = no filter).
const kFilterNames = ['Original', 'Vivid', 'Warm', 'Cool', 'Mono', 'Fade', 'Vintage', 'Drama', 'Noir', 'Sunset'];

const List<List<double>?> kFilterMatrices = [
  null,
  [1.25, -0.1, -0.1, 0, -8, -0.1, 1.25, -0.1, 0, -8, -0.1, -0.1, 1.25, 0, -8, 0, 0, 0, 1, 0], // vivid
  [1.12, 0, 0, 0, 8, 0, 1.0, 0, 0, 0, 0, 0, 0.84, 0, 0, 0, 0, 0, 1, 0], // warm
  [0.86, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 1.15, 0, 8, 0, 0, 0, 1, 0], // cool
  [0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0], // mono
  [0.82, 0, 0, 0, 34, 0, 0.82, 0, 0, 34, 0, 0, 0.82, 0, 34, 0, 0, 0, 1, 0], // fade
  [0.39, 0.77, 0.19, 0, 0, 0.35, 0.69, 0.17, 0, 0, 0.27, 0.53, 0.13, 0, 0, 0, 0, 0, 1, 0], // vintage
  [1.35, 0, 0, 0, -45, 0, 1.35, 0, 0, -45, 0, 0, 1.35, 0, -45, 0, 0, 0, 1, 0], // drama (contrast)
  [0.5, 0.9, 0.2, 0, -50, 0.5, 0.9, 0.2, 0, -50, 0.5, 0.9, 0.2, 0, -50, 0, 0, 0, 1, 0], // noir (dark mono)
  [1.2, 0.1, 0, 0, 14, 0, 0.95, 0.05, 0, 0, 0, 0.1, 0.8, 0, 12, 0, 0, 0, 1, 0], // sunset
];

ColorFilter? filterFor(int i) {
  if (i <= 0 || i >= kFilterMatrices.length) return null;
  final m = kFilterMatrices[i];
  return m == null ? null : ColorFilter.matrix(m);
}

const List<double> _identity = [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];

/// Applies [b] first, then [a] (both 4x5 colour matrices).
List<double> mulMatrix(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 5; j++) {
      var s = 0.0;
      for (var k = 0; k < 4; k++) {
        s += a[i * 5 + k] * b[k * 5 + j];
      }
      if (j == 4) s += a[i * 5 + 4];
      out[i * 5 + j] = s;
    }
  }
  return out;
}

/// Brightness, contrast, saturation and warmth, each from -1 to 1 (0 = unchanged).
class Adjust {
  double brightness, contrast, saturation, warmth;
  Adjust({this.brightness = 0, this.contrast = 0, this.saturation = 0, this.warmth = 0});
  bool get isNeutral => brightness == 0 && contrast == 0 && saturation == 0 && warmth == 0;
  void reset() => brightness = contrast = saturation = warmth = 0;
}

List<double> adjustMatrix(Adjust a) {
  var m = _identity;
  if (a.contrast != 0) {
    final k = 1 + a.contrast * 0.8;
    m = mulMatrix([k, 0, 0, 0, 128 * (1 - k), 0, k, 0, 0, 128 * (1 - k), 0, 0, k, 0, 128 * (1 - k), 0, 0, 0, 1, 0], m);
  }
  if (a.brightness != 0) {
    final o = a.brightness * 70;
    m = mulMatrix([1, 0, 0, 0, o, 0, 1, 0, 0, o, 0, 0, 1, 0, o, 0, 0, 0, 1, 0], m);
  }
  if (a.saturation != 0) {
    final s = 1 + a.saturation;
    const r = 0.2126, g = 0.7152, b = 0.0722;
    m = mulMatrix([r + (1 - r) * s, g - g * s, b - b * s, 0, 0, r - r * s, g + (1 - g) * s, b - b * s, 0, 0, r - r * s, g - g * s, b + (1 - b) * s, 0, 0, 0, 0, 0, 1, 0], m);
  }
  if (a.warmth != 0) {
    final w = a.warmth * 0.16;
    m = mulMatrix([1 + w, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1 - w, 0, 0, 0, 0, 0, 1, 0], m);
  }
  return m;
}

/// The filter and adjustments as one matrix, or null when nothing changes the picture.
List<double>? combinedMatrix(int filter, Adjust a) {
  final f = (filter > 0 && filter < kFilterMatrices.length) ? kFilterMatrices[filter] : null;
  if (f == null && a.isNeutral) return null;
  var m = adjustMatrix(a);
  if (f != null) m = mulMatrix(f, m);
  return m;
}
