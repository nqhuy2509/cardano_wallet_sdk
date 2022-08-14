// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:cardano_wallet_sdk/cardano_wallet_sdk.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'dart:math';

void main() {
  Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('BigIntParseTest');

// note: Native Dart int values can only handle numbers up to the 9 Quintillion
// range [-9,223,372,036,854,775,808..9,223,372,036,854,775,807].

  group('parseBigInt -', () {
    test('valid formats', () {
      final success = <String, BigInt>{
        '9.9e2': BigInt.from(990),
        '0.0e2': BigInt.zero,
        '7e5': BigInt.from(700000),
        '7E1': BigInt.from(70),
        '1.222e2': BigInt.from(122),
        '1.2': BigInt.one,
        '1.99999999999': BigInt.one,
        '1.': BigInt.one,
        '.2e1': BigInt.two,
        '333.2e1': BigInt.from(3332),
        '+1.2e+2': BigInt.from(120),
        '-1.2': BigInt.from(-1),
        '1.000e1': BigInt.from(10),
        '1.000e0': BigInt.one,
        '+00001.20000e+0002': BigInt.from(120),
        '+1.234500e5': BigInt.from(123450),
        '9.223372036854775807e18': BigInt.from(9223372036854775807),
        '-9.223372036854775808e18': BigInt.from(-9223372036854775808),
        '-1.3139667629422286119e19': BigInt.parse('-13139667629422286119'),
        //'-1.3139667629422286119e19': BigInt.parse('-13139667629422286118');
        '0x3bdefda92265': BigInt.parse('0x3bdefda92265'),
      };
      for (MapEntry entry in success.entries) {
        try {
          final i = parseBigInt(entry.key);
          logger.info("${entry.key} -> $i");
          expect(i, equals(entry.value));
        } on FormatException catch (e) {
          logger.info("ERROR: ${entry.key} -> ${e.message}");
        }
      }
    });

    test('invalid formats', () {
      final failure = <String>[
        '9.9e-2',
        'ffee',
        '.0',
        '0xfh',
        'one',
      ];
      for (String invalid in failure) {
        try {
          final i = parseBigInt(invalid);
          logger.info("${invalid} -> $i");
          fail(
              "Expected test failure: '${invalid}' is not a valid BigInt format");
        } on FormatException catch (e) {
          logger.info("ERROR: ${invalid} -> ${e.message}: ${e.source}");
        } on TestFailure {
          rethrow;
        } catch (e) {
          logger.info("${invalid} -> $e");
          fail("'${invalid}' unexpected exception: $e");
        }
      }
      expect(tryParseBigInt('0xff', allowHex: false), isNull);
    });
  });
}
