// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:cardano_wallet_sdk/cardano_wallet_sdk.dart';
import 'package:collection/collection.dart';
import 'package:hex/hex.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  //Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('FeeCalculationServiceTest');
  final protocolParameters = protocolParametersEpoch243;
  final service = FeeCalculationService(protocolParameters);

  group('fee calculation -', () {
    test('tx fee', () async {
      final txHex =
          '84a5008182582064fd185ae2760fe89651d06ea9a1dbacd0529f18532daa70ae1deed13b36f0f801018282583900fe02378e3e22e64ff864a68e7ec2d7300ac20a768eadc0c67ce249a63e61daf0df57f1cc6fdb15cea66150d63fa3db71c90f8f337960243b1a001e848082583900b0270066e3821d63ba1ed5cbebe2fec46c341f0f67786c332dee637554beac4fe00ebcdc9d39b80b4b5bb554493afbdbccf8e2b017b5dc351a05b3a956021a00029755031a0474f38e075820bdaa99eb158414dea0a91d6c727e2268574b23efe6e08ab3b841abe8059a030ca100818258205b8392e8bced75e8c217dc57c907a79304685d3508ba0aacff8bc388351ad2e95840313a221cac2e1f3ae5ccfdf4054b6728d0c175895698f96d041db0a740d45e8f8a8a10939c2ec2922aff273cc58990ee4e7a3c90a0124af87098283faef8ca0ff5d90103a0';
      final buff = HEX.decode(txHex);
      expect(buff.length, equals(328));
      final BigInt fee0 = service.calculateMinFeeFromBytes(buff);
      expect(fee0, equals(BigInt.from(169813)));
      final tx = BcTransaction.fromHex(txHex);
      final BigInt fee = service.calculateMinFee(transaction: tx);
      expect(fee, equals(BigInt.from(169813)),
          skip: "length is too short 290 vs 328");
    });

    test('script fee', () async {
      final redeemer = BcRedeemer(
          tag: BcRedeemerTag.spend,
          index: BigInt.zero,
          data: BcBigIntPlutusData(BigInt.from(42)),
          exUnits: BcExUnits(
            BigInt.from(458438),
            BigInt.from(234081144),
          ));
      BigInt fee = service.calculateScriptFee([redeemer.exUnits]);
      expect(fee.toInt(), equals(43330));
    });
  });
}
