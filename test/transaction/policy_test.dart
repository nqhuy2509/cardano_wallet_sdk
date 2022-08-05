// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:cardano_wallet_sdk/cardano_wallet_sdk.dart';
import 'package:logging/logging.dart';
import 'dart:convert' as convert;
import 'package:test/test.dart';

void main() {
  Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('PolicyTest');
  convert.JsonEncoder ppEncoder = convert.JsonEncoder.withIndent(' ');

  group('serialize -', () {
    final currentSlot = Policy.slotsPerEpoch * 42;

    test('createEpochBasedTimeLocked', () async {
      final p = Policy.createEpochBasedTimeLocked('locked', currentSlot, 3);
      logger.info(ppEncoder.convert(p.toJson));
      final p2 = Policy.fromJson(p.toJson);
      logger.info(ppEncoder.convert(p2.toJson));
      expect(p2, equals(p));
    });

    test('createMultiSigScriptAll', () async {
      final p = Policy.createMultiSigScriptAll('locked', 3);
      logger.info(ppEncoder.convert(p.toJson));
      final p2 = Policy.fromJson(p.toJson);
      logger.info(ppEncoder.convert(p2.toJson));
      expect(p2, equals(p));
    });

    test('createMultiSigScriptAtLeast', () async {
      final p = Policy.createMultiSigScriptAtLeast('locked', 3, 2);
      logger.info(ppEncoder.convert(p.toJson));
      final p2 = Policy.fromJson(p.toJson);
      logger.info(ppEncoder.convert(p2.toJson));
      expect(p2, equals(p));
    });
  });
}
