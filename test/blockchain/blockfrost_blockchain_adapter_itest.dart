// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:cardano_wallet_sdk/cardano_wallet_sdk.dart';
import 'package:logging/logging.dart';
import 'package:cbor/cbor.dart';
import 'package:blockfrost/blockfrost.dart';
import 'dart:convert' as convert;
import 'dart:io' as io;
import 'package:test/test.dart';
import 'package:hex/hex.dart';

const apiKeyFilePath = '../blockfrost_project_id.txt';

String _readApiKey() {
  final file = io.File(apiKeyFilePath).absolute;
  return file.readAsStringSync();
}

void main() {
  // Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('BlockfrostBlockchainAdapterTest');
  final network = Networks.testnet;
  final interceptor = BlockfrostApiKeyAuthInterceptor(projectId: _readApiKey());
  final blockfrost = Blockfrost(
    basePathOverride: BlockfrostBlockchainAdapter.urlFromNetwork(network),
    interceptors: [interceptor],
  );
  final blockfrostAdapter = BlockfrostBlockchainAdapter(
      network: network, blockfrost: blockfrost, projectId: _readApiKey());
  final mnemonic =
      'company coast prison denial unknown design paper engage sadness employ phone cherry thunder chimney vapor cake lock afraid frequent myself engage lumber between tip'
          .split(' ');
  final HdAccount sender =
      HdMaster.mnemonic(mnemonic, network: network).account();

  group('BlockfrostBlockchainAdapter -', () {
    test('latestEpochParameters', () async {
      final result = await blockfrostAdapter.latestEpochParameters();
      expect(result.isOk(), isTrue);
      final ProtocolParameters params = result.unwrap();
      expect(params.epoch, greaterThan(243));
      expect(params.minFeeA, greaterThanOrEqualTo(40));
      expect(
          params.coinsPerUtxoSize, greaterThanOrEqualTo(BigInt.parse('4310')));
      expect(params.costModels.length, equals(2));
      final Map<String, int>? plutusV1 =
          params.costModels[BcScriptType.plutusV1];
      expect(plutusV1, isNotNull);
      expect(plutusV1!.isNotEmpty, isTrue);
      // logger.info(
      //     "plutusV1!['addInteger-cpu-arguments-intercept']:${plutusV1!['addInteger-cpu-arguments-intercept']}");
    });

    test('latestBlock', () async {
      final result = await blockfrostAdapter.latestBlock();
      expect(result.isOk(), isTrue);
      final Block block = result.unwrap();
      expect(block.epoch, greaterThan(243));
      //print("block.time: ${block.time}");
      expect(
          block.time.millisecondsSinceEpoch,
          greaterThanOrEqualTo(DateTime.now()
              .subtract(Duration(days: 1))
              .millisecondsSinceEpoch));
    });
  }, skip: "upgrade to Prepod");
}
