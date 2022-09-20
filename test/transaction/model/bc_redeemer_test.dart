// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:cardano_wallet_sdk/cardano_wallet_sdk.dart';
import 'package:logging/logging.dart';
import 'dart:convert' as convert;
import 'package:cbor/cbor.dart';
import 'package:test/test.dart';
import 'package:hex/hex.dart';
import 'dart:typed_data';

void main() {
  Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('BcScriptsTest');
  group('Redeemer -', () {
    final fortyTwo = CborBigInt(BigInt.from(42));
    final hello = CborBytes('hello'.codeUnits);
    final list1 = CborList([fortyTwo, hello]);
    final map1 = CborMap({fortyTwo: hello});

    test('cbor', () {
      final redeemer1 = BcRedeemer(
        tag: BcRedeemerTag.spend,
        index: BigInt.from(99),
        data: BcPlutusData.fromCbor(map1),
        exUnits: BcExUnits(BigInt.from(1024), BigInt.from(6)),
      );
      final cbor = redeemer1.cborValue;
      logger.info(cbor);
      final hex1 = redeemer1.hex;
      logger.info(hex1);
      final redeemer2 = BcRedeemer.fromHex(hex1);
      expect(redeemer2, equals(redeemer1));
    });
    test('cbor2', () {
      final redeemer1 = BcRedeemer(
        tag: BcRedeemerTag.spend,
        index: BigInt.from(0),
        data: BcBigIntPlutusData(BigInt.from(2021)),
        exUnits: BcExUnits(BigInt.from(1700), BigInt.from(476468)),
      );
      final cbor = redeemer1.cborValue;
      logger.info(cbor);
      final hex1 = redeemer1.hex;
      logger.info(hex1);
      expect(hex1, equals('8400001907e5821906a41a00074534'));
    });
  });
}
