// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

///
/// Parse arbitrary long integers returning a BigInt. Supported input formats are: decimal
/// integer, scientific E notation (1.3e2) or hexidecimal notation (0xff). Any
/// remaining decimal value is truncated (3.789e2 -> 378). Returns null on hex input
/// if allowHex is false.
/// Returns null given invalid input.
///
BigInt? tryParseBigInt(String number, {bool allowHex = true}) {
  try {
    return parseBigInt(number, allowHex: allowHex);
  } on FormatException {
    return null;
  }
}

///
/// Parse arbitrary long integers returning a BigInt. Supported input formats are: decimal
/// integer, scientific E notation (1.3e2) or hexidecimal notation (0xff). Any
/// remaining decimal value is truncated (3.789e2 -> 378). Parsing will fail on hex values
/// if allowHex is false.
/// Throws FormatException on invalid input.
///
BigInt parseBigInt(String number, {bool allowHex = true}) {
  final source = number.trim().toLowerCase();
  if (source.startsWith('0x')) {
    if (!allowHex) {
      throw FormatException('allowHex flag is set to false', source);
    }
    return BigInt.parse(source);
  }
  final match = bigIntSciERegExp.firstMatch(number);
  if (match != null) {
    final String sign = match.group(1) ?? '+'; // [+-]?
    String base = match.group(2) ?? ''; // [0-9]+
    String decimal = match.group(3) ?? ''; // (\.[0-9]*)?
    String exponent = match.group(4)?.trim() ?? ''; // ([eE][+-]?[0-9]+)?

    bool isNegative = sign == '-'; //[+-]

    if (decimal.isNotEmpty) {
      // .nnnn
      while (decimal.endsWith('0')) {
        decimal = decimal.substring(0, decimal.length - 1);
      }
    }
    final decLen = decimal.isEmpty ? 0 : decimal.length - 1;

    //do we have a e-notation scientific number?
    if (exponent.isNotEmpty) {
      //then mechanically shift the digits to a BigInt
      exponent = exponent.substring(1); //remove 'e' prefix
      if (exponent.startsWith('-')) {
        throw FormatException('Negative exponents not supported', source);
      }
      while ((exponent.length > 1 && exponent.startsWith('0')) ||
          exponent.startsWith('-') ||
          exponent.startsWith('+')) {
        exponent = exponent.substring(1);
      }
      var expInt = int.parse(exponent);
      if (decLen > 0) {
        // 1.22e2 -> 122, 1.2e0 -> 1, 1.222e2 -> 122, 1.22e3 -> 1220
        final decShift = min(decLen, expInt);
        base += decimal.substring(1, decShift + 1);
        expInt -= decShift;
      }
      if (expInt > 0) {
        base = base.padRight(expInt + base.length, '0');
      }
    }
    if (isNegative) {
      base = "-$base";
    }
    if (base.isNotEmpty) {
      return BigInt.parse(base);
    } else {
      throw FormatException(
          'Invalid BigInt format. Expected decimal integer, scientific E notation (1.3e2) or hexidecimal notation (0xff).',
          source);
    }
  } else {
    throw FormatException(
        'Invalid BigInt format. Expected decimal integer, scientific E notation (1.3e2) or hexidecimal notation (0xff).',
        source);
  }
}

// Dart's BigInt parser does not support scientific E notation:
//   RegExp(r'^\s*([+-]?)((0x[a-f0-9]+)|(\d+)|([a-z0-9]+))\s*$',caseSensitive: false);

final bigIntSciERegExp = RegExp(
    r'([+-]?)([0-9]+)?(\.[0-9]*)?([eE][+-]?[0-9]+)?',
    caseSensitive: false);
