// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:cardano_wallet_sdk/cardano_wallet_sdk.dart';
import 'package:bip32_ed25519/bip32_ed25519.dart';
import 'package:logging/logging.dart';
import 'dart:convert';
import 'package:cbor/cbor.dart';
import 'package:test/test.dart';
import 'package:hex/hex.dart';

///
/// CBOR output can be validated here: http://cbor.me
/// CBOR encoding reference: https://www.rfc-editor.org/rfc/rfc7049.html#appendix-B
///
/// Current CBOR spec is rfc8949: https://www.rfc-editor.org/rfc/rfc8949.html
///
/// tests and results taken from: https://github.com/bloxbean/cardano-client-lib. Thank you!
///
class DummyTransactionBody extends BcAbstractCbor {
  final List<BcCertificate> certs;
  DummyTransactionBody(this.certs);
  factory DummyTransactionBody.fromCbor({required CborMap map}) {
    final certs = map[const CborSmallInt(4)] == null
        ? <BcCertificate>[]
        : (map[const CborSmallInt(4)] as CborList)
            .map((list) => BcCertificate.fromCbor(list: list as CborList))
            .toList();
    return DummyTransactionBody(certs);
  }

  @override
  CborValue get cborValue => toCborMap();

  CborMap toCborMap() {
    return CborMap({
      if (certs.isNotEmpty)
        const CborSmallInt(4): CborList(certs.map((m) => m.cborValue).toList()),
    });
  }
}

void main() {
  // Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('BcCertificateTest');
  group('certificate -', () {
    final dummyChainCode = csvToUint8List(
        '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0');
    final verifyKey1 = Bip32VerifyKey.fromKeyBytes(
        addrVkCoder.decode(
            'addr_vk1w0l2sr2zgfm26ztc6nl9xy8ghsk5sh6ldwemlpmp9xylzy4dtf7st80zhd'),
        dummyChainCode);
    final verifyKey2 = Bip32VerifyKey.fromKeyBytes(
        stakeVkCoder.decode(
            'stake_vk1px4j0r2fk7ux5p23shz8f3y5y2qam7s954rgf3lg5merqcj6aetsft99wu'),
        dummyChainCode);

    test('BcCertificate serialize', () {
      BcCertificate c1 = BcStakeRegistration(
          credential: BcStakeCredential.fromKey(verifyKey: verifyKey1));
      BcCertificate c2 = BcStakeDeregistration(
          credential: BcStakeCredential.fromKey(verifyKey: verifyKey2));
      BcCertificate c3 = BcStakeDelegation(
        credential: BcStakeCredential.fromKey(verifyKey: verifyKey2),
        poolId: 'pool14pdhhugxlqp9vta49pyfu5e2d5s82zmtukcy9x5ylukpkekqk8l',
      );
      final body1 = DummyTransactionBody([c1, c2, c3]);
      final cbor1 = body1.toCborMap();
      final body2 = DummyTransactionBody.fromCbor(map: cbor1);
      expect(body2, equals(body1));
    });
    test('poolId bech32', () {
      final pool1 = 'pool14pdhhugxlqp9vta49pyfu5e2d5s82zmtukcy9x5ylukpkekqk8l';
      final bytes1 = stakePoolBytesFromBech32(pool1);
      final pool2 = bech32FromStakePoolBytes(bytes1);
      expect(pool1, equals(pool2));
    });
  });
}
