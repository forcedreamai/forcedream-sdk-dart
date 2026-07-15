import 'dart:convert';
import 'package:crypto/crypto.dart' as hashing;

/// Exact replica of the server's wfCanonical: JSON.stringify(obj, Object.keys(obj).sort()).
/// Sorted keys, no whitespace. Ported from the same logic already proven in nine other
/// language SDKs tonight (JS, Python, Go, Rust, Java, C#, PHP, Kotlin, Ruby) -- not invented
/// fresh for Dart.
///
/// Confirmed building and running correctly on a real Mac (Dart 3.12.2) -- see README for
/// the real, live-tested results and the one bug that build surfaced (a field-promotion
/// issue in force_dream.dart, unrelated to this file).
class Canonical {
  Canonical._();

  /// Uses a custom, minimal serializer rather than dart:convert's jsonEncode, since exact
  /// byte-for-byte output matters here (a single differing byte changes the signed bytes
  /// and breaks every signature check) and jsonEncode doesn't sort keys or control number
  /// formatting the way this needs.
  static String wfCanonical(Map<String, dynamic> obj) {
    final sortedKeys = obj.keys.toList()..sort();
    final parts = sortedKeys.map((k) => '"${_escape(k)}":${_serialize(obj[k])}');
    return '{${parts.join(',')}}';
  }

  static String _serialize(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return '"${_escape(value)}"';
    if (value is num) return jsNumber(value.toDouble());
    if (value is bool) return value.toString();
    throw ArgumentError('Unsupported type for canonicalization: ${value.runtimeType}');
  }

  static String _escape(String s) {
    final buffer = StringBuffer();
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      switch (ch) {
        case '"':
          buffer.write('\\"');
          break;
        case '\\':
          buffer.write('\\\\');
          break;
        case '\n':
          buffer.write('\\n');
          break;
        case '\r':
          buffer.write('\\r');
          break;
        case '\t':
          buffer.write('\\t');
          break;
        default:
          buffer.write(ch);
      }
    }
    return buffer.toString();
  }

  /// Mirrors JS's Number(x) -> JSON.stringify() behavior: whole values with no decimal
  /// point, fractional values preserved, never scientific notation.
  ///
  /// Applied defensively regardless of Dart's own double.toString() behavior for whole
  /// numbers (documented to always include a decimal point, e.g. "10.0" not "10", similar
  /// to Swift's Double.description -- based on Dart's own stable, documented behavior, not
  /// independently compiled and confirmed the way Ruby's equivalent bug was tonight) --
  /// the same defensive posture used even for languages where the default turned out safe.
  static String jsNumber(double d) {
    if (d.isFinite && d == d.truncateToDouble() && d.abs() < 1e15) {
      return d.truncate().toString();
    }
    return d.toString();
  }

  static String sha256Hex(String s) {
    final bytes = utf8.encode(s);
    return hashing.sha256.convert(bytes).toString();
  }
}
