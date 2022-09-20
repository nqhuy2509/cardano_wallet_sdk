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
void main() {
  Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('BcTxTest');
  group('witness set -', () {
    test('serialize', () {
      BcTransactionWitnessSet ws1 = BcTransactionWitnessSet(
        nativeScripts: [
          BcScriptPubkey(
              keyHash:
                  '2f3d4cf10d0471a1db9f2d2907de867968c27bca6272f062cd1c2413'),
          BcScriptPubkey(
              keyHash:
                  'f856c0c5839bab22673747d53f1ae9eed84afafb085f086e8e988614'),
        ],
        bootstrapWitnesses: [
          BcBootstrapWitness(
            publicKey: Uint8List.fromList([1, 2, 3]),
            signature: Uint8List.fromList([4, 5, 6]),
            chainCode: Uint8List.fromList([7, 8, 9]),
            attributes: Uint8List.fromList([10, 11, 12]),
          )
        ],
        plutusScriptsV1: [
          BcPlutusScriptV1.parse(cborHex: '4e3d01000033222220051200120011')
        ],
        plutusDataList: [
          BcConstrPlutusData(
              alternative: 0,
              list: BcListPlutusData([
                BcBytesPlutusData(
                    Uint8List.fromList(utf8.encode('Hello World!')))
              ]))
        ],
        redeemers: [
          BcRedeemer(
            tag: BcRedeemerTag.spend,
            index: BigInt.from(99),
            data: BcPlutusData.fromCbor(CborMap(
                {CborBigInt(BigInt.from(42)): CborBytes('hello'.codeUnits)})),
            exUnits: BcExUnits(BigInt.from(1024), BigInt.from(6)),
          )
        ],
        plutusScriptsV2: [
          BcPlutusScriptV2.parse(cborHex: '4e4d01000033222220051200120011'),
          BcPlutusScriptV2.parse(cborHex: '4e5def000033222220051200120011'),
        ],
        vkeyWitnesses: [],
      );
      final ws2 = BcTransactionWitnessSet.fromHex(ws1.hex);
      expect(ws2, equals(ws1));
    });
    test('deserialize', () {
      final hex =
          'a203814e3d0100003322222005120012001106824e4d010000332222200512001200114e5def000033222220051200120011';
      final ws = BcTransactionWitnessSet.fromHex(hex);
      expect(ws.plutusScriptsV1.length, equals(1));
      expect(ws.plutusScriptsV2.length, equals(2));
    });
  });
  group('serialize -', () {
    test('plutus and native scripts', () {
      final fee = 367965;
      final ttl = 26194586;
      final metadata = json.decode('''{
            "197819781978": "John",
            "197819781979": "CA",
            "1978197819710": "0x000B",
            "1978197819711": {
              "1978": "201value",
              "197819": "200001",
              "203": "0x0B0B0A"
            },
            "1978197819712": [
              "301value",
              "300001",
              "0x0B0B0A",
              {"401": "401str", "hello": "hellovalue"}
            ]}''');
      final signingKey = KeyUtil.generateSigningKey();
      final tx1 = (TxBuilder()
            ..input(
                transactionId:
                    '73198b7ad003862b9798106b88fbccfca464b1a38afb34958275c4a7d7d8d002',
                index: 1)
            ..output(
                address:
                    'addr_test1qqy3df0763vfmygxjxu94h0kprwwaexe6cx5exjd92f9qfkry2djz2a8a7ry8nv00cudvfunxmtp5sxj9zcrdaq0amtqmflh6v',
                lovelace: 40000)
            ..output(
                address:
                    'addr_test1qzx9hu8j4ah3auytk0mwcupd69hpc52t0cw39a65ndrah86djs784u92a3m5w475w3w35tyd6v3qumkze80j8a6h5tuqq5xe8y',
                value: BcValue(coin: 340000, multiAssets: [
                  BcMultiAsset(
                      policyId:
                          '329728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96',
                      assets: [
                        BcAsset(name: '0x736174636f696e', value: 4000),
                        BcAsset(name: '0x446174636f696e', value: 1100),
                      ]),
                  BcMultiAsset(
                      policyId:
                          '6b8d07d69639e9413dd637a1a815a7323c69c86abbafb66dbfdb1aa7',
                      assets: [BcAsset(name: '', value: 9000)]),
                  BcMultiAsset(
                      policyId:
                          '449728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96',
                      assets: [BcAsset(name: '0x666174636f696e', value: 5000)]),
                ]),
                autoAddMinting: true)
            ..ttl(ttl)
            ..minFee(fee)
            ..metadata(BcMetadata.fromJson(metadata))
            ..plutusV1Script(
                BcPlutusScriptV1.parse(cborHex: '4d01000033222220051200120011'))
            ..plutusV1Script(
                BcPlutusScriptV1.parse(cborHex: '4d01000033222220051200120011'))
            ..nativeScript(
                BcScriptPubkey.fromKey(verifyKey: signingKey.verifyKey)))
          .build();
      expect(tx1.body.mint.length, equals(3), reason: 'autoAddMinting: true)');
      final tx2 = BcTransaction.fromHex(tx1.hex);
      expect(tx2, equals(tx1));
      //sign
      final account1 = HdMaster.mnemonic(HdMaster.generateMnemonic()).account();
      final account2 = HdMaster.mnemonic(HdMaster.generateMnemonic()).account();
      final signTx1 =
          tx1.sign([account1.basePrivateKey(), account2.basePrivateKey()]);
      expect(signTx1.verify, isTrue);
      final signTx2 = BcTransaction.fromHex(signTx1.hex);
      expect(signTx2, equals(signTx1));
      expect(signTx2.verify, isTrue);
    });

    test('mint', () {
      final txId =
          "73198b7ad003862b9798106b88fbccfca464b1a38afb34958275c4a7d7d8d002";
      final recAddress = ShelleyAddress.fromBech32(
          "addr_test1qqy3df0763vfmygxjxu94h0kprwwaexe6cx5exjd92f9qfkry2djz2a8a7ry8nv00cudvfunxmtp5sxj9zcrdaq0amtqmflh6v");
      final outputAddress = ShelleyAddress.fromBech32(
          "addr_test1qzx9hu8j4ah3auytk0mwcupd69hpc52t0cw39a65ndrah86djs784u92a3m5w475w3w35tyd6v3qumkze80j8a6h5tuqq5xe8y");
      final fee = 367965;
      final ttl = 26194586;
      final asset1 = "0x736174636f696e";
      final tx1 = (TxBuilder()
            ..input(transactionId: txId, index: 1)
            ..output(shelleyAddress: recAddress, lovelace: 40000)
            ..output(
                shelleyAddress: outputAddress,
                value: BcValue(coin: 340000, multiAssets: [
                  BcMultiAsset(
                      policyId:
                          '329728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96',
                      assets: [BcAsset(name: asset1, value: 4000)]),
                  BcMultiAsset(
                      policyId:
                          '6b8d07d69639e9413dd637a1a815a7323c69c86abbafb66dbfdb1aa7',
                      assets: [
                        BcAsset(name: str2hex.encode('Test'), value: 4000)
                      ]),
                ]),
                autoAddMinting: true)
            ..mint(BcMultiAsset(
                policyId:
                    '229728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a26',
                assets: [BcAsset(name: asset1, value: -5000)]))
            ..ttl(ttl)
            ..minFee(fee))
          .build();
      expect(tx1.body.mint.length, equals(3), reason: 'autoAddMinting: true)');
      final tx2 = BcTransaction.fromHex(tx1.hex);
      expect(tx1, equals(tx2));
    });
  });
  group('TxBuilder -', () {
    final fee = 200000;
    final inputAmount = 99200000;
    final txId =
        'ac90bcc3d88536dea081603e7e7b65bba8eb68b78bc49ebf9a0ff3dbad9e55ac';
    final to =
        'addr_test1vrw6vsvwwe9vwupyfkkeweh23ztd6n0vfydwk823esdz6pc4xqcd5';
    final expectedHex =
        '84a50081825820ac90bcc3d88536dea081603e7e7b65bba8eb68b78bc49ebf9a0ff3dbad9e55ac00018182581d60dda6418e764ac770244dad9766ea8896dd4dec491aeb1d51cc1a2d071a05e69ec0021a00030d40031a03ef1480075820b211d9ec913486e50b032b140a58c927f3abe4f9bcf3f64f8f4c4aa2197d5a85a0f5a11907846b68656c6c6f20776f726c64';
    final expectedHash =
        '7b844a952d9d9bdcceabdf206ad24df1310460b7b4b421d6b05148b5a64283f2';
    test('alonzo - JsonText', () {
      final tx = (TxBuilder()
            ..input(transactionId: txId, index: 0)
            ..output(address: to, lovelace: inputAmount - fee)
            ..ttl(66000000)
            ..minFee(fee)
            ..metadataFromJsonText('{"1924":"hello world"}'))
          .build();
      expect(tx.hex, equals(expectedHex));
      expect(tx.body.hashHex, equals(expectedHash));
    });
    test('alonzo - fromCbor', () {
      final builder = TxBuilder()
        ..input(transactionId: txId, index: 0)
        ..output(address: to, lovelace: inputAmount - fee)
        ..ttl(66000000)
        ..minFee(fee)
        ..metadata(BcMetadata.fromCbor(
            map: CborMap(
                {CborInt(BigInt.from(1924)): CborString('hello world')})));
      final BcTransaction tx = builder.build();
      expect(tx.hex, equals(expectedHex));
      expect(tx.body.hashHex, equals(expectedHash));
    });
  });

  group('Blockchain CBOR model -', () {
    test('serialize deserialize BcTransactionInput', () {
      final input1 = BcTransactionInput(
          transactionId:
              '73198b7ad003862b9798106b88fbccfca464b1a38afb34958275c4a7d7d8d002',
          index: 1);
      final bytes1 = input1.serialize;
      CborValue val1 = cbor.decode(bytes1);
      //print(const CborJsonEncoder().convert(val1));
      final input2 = BcTransactionInput.fromCbor(list: val1 as CborList);
      expect(input2, equals(input1));
    });

    test('sign - SigningKey -', () {
      final txnHex =
          '83a4008282582073198b7ad003862b9798106b88fbccfca464b1a38afb34958275c4a7d7d8d002018258208e03a93578dc0acd523a4dd861793068a06a68b8a6c7358d0c965d2864067b68000184825839000916a5fed4589d910691b85addf608dceee4d9d60d4c9a4d2a925026c3229b212ba7ef8643cd8f7e38d6279336d61a40d228b036f40feed61a004c4b40825839008c5bf0f2af6f1ef08bb3f6ec702dd16e1c514b7e1d12f7549b47db9f4d943c7af0aaec774757d4745d1a2c8dd3220e6ec2c9df23f757a2f8821a3aa51029a2581c329728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96a147736174636f696e190fa0581c6b8d07d69639e9413dd637a1a815a7323c69c86abbafb66dbfdb1aa7a14019232882583900c93b6cac143fe60f8914f44a899f5329433ccec3d53721ef350a0fd8cb873402c73ad8f239f76fb559bb4e3bcff22b310b01eadd3ce205e71a007a1200825839001c1ffaf141ebbb8e3a7072bb15f50f938b994c82de2d175f358fc942441f00edfe1b8d6a84f0d19c25a9c8829442160c0b5c758094c423441a3b1b1aa3021a000b3aba031a018fb29aa0f6';
      final sk =
          'ede3104b2f4ff32daa3b620a9a272cd962cf504da44cf1cf0280aff43b65f807';
      final secretKey = SigningKey.fromSeed(Uint8List.fromList(HEX.decode(sk)));
      final tx = BcTransaction.fromHex(txnHex);
      final signedTx = tx.sign([secretKey]);
      final witness = signedTx.witnessSet!.vkeyWitnesses[0];
      expect(
          witness.vkey,
          equals(HEX.decode(
              '60209269377f220cdecdc6d5ad42d9b04e58ce74b349efb396ee46adaeb956f3')));
      expect(
          witness.signature,
          equals(HEX.decode(
              'cd9f8e70a09f24328ee6c14053a38a6a654d31e9e58a9c6c44848e4592265237ce3604eda0cb1812028c3e6b04c66ccc64a1d2685d98e0567477cbc33a4c2f0f')));
    });

    test('serializeTx', () {
      final List<BcTransactionInput> inputs = [
        BcTransactionInput(
            transactionId:
                '73198b7ad003862b9798106b88fbccfca464b1a38afb34958275c4a7d7d8d002',
            index: 1),
      ];
      final List<BcTransactionOutput> outputs = [
        BcTransactionOutput(
            address:
                'addr_test1qqy3df0763vfmygxjxu94h0kprwwaexe6cx5exjd92f9qfkry2djz2a8a7ry8nv00cudvfunxmtp5sxj9zcrdaq0amtqmflh6v',
            value: BcValue(coin: 40000, multiAssets: [])),
        BcTransactionOutput(
            address:
                'addr_test1qzx9hu8j4ah3auytk0mwcupd69hpc52t0cw39a65ndrah86djs784u92a3m5w475w3w35tyd6v3qumkze80j8a6h5tuqq5xe8y',
            value: BcValue(coin: 340000, multiAssets: [
              BcMultiAsset(
                  policyId:
                      '329728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96',
                  assets: [
                    BcAsset(name: '736174636f696e', value: 4000),
                    BcAsset(name: '446174636f696e', value: 1100),
                  ]),
              BcMultiAsset(
                  policyId:
                      '6b8d07d69639e9413dd637a1a815a7323c69c86abbafb66dbfdb1aa7',
                  assets: [
                    BcAsset(name: '', value: 9000),
                  ]),
              BcMultiAsset(
                  policyId:
                      '449728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96',
                  assets: [
                    BcAsset(name: '666174636f696e', value: 5000),
                  ]),
            ])),
      ];
      final body = BcTransactionBody(
        inputs: inputs,
        outputs: outputs,
        fee: 367965,
        ttl: 26194586,
        metadataHash: null,
        validityStartInterval: 0,
        mint: outputs[1].value.multiAssets,
      );
      final bodyMap = cbor.decode(body.serialize) as CborMap;
      final body2 = BcTransactionBody.fromCbor(map: bodyMap);
      expect(body2, body, reason: 'BcTransactionBody serialization good');
      final BcTransaction tx =
          BcTransaction(body: body, witnessSet: null, metadata: null);
      //print("actual: ${tx.json}");
      //print(txHex);
      const expectedHex =
          '84a5008182582073198b7ad003862b9798106b88fbccfca464b1a38afb34958275c4a7d7d8d002010182825839000916a5fed4589d910691b85addf608dceee4d9d60d4c9a4d2a925026c3229b212ba7ef8643cd8f7e38d6279336d61a40d228b036f40feed6199c40825839008c5bf0f2af6f1ef08bb3f6ec702dd16e1c514b7e1d12f7549b47db9f4d943c7af0aaec774757d4745d1a2c8dd3220e6ec2c9df23f757a2f8821a00053020a3581c329728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96a247736174636f696e190fa047446174636f696e19044c581c6b8d07d69639e9413dd637a1a815a7323c69c86abbafb66dbfdb1aa7a140192328581c449728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96a147666174636f696e191388021a00059d5d031a018fb29a09a3581c329728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96a247736174636f696e190fa047446174636f696e19044c581c6b8d07d69639e9413dd637a1a815a7323c69c86abbafb66dbfdb1aa7a140192328581c449728f73683fe04364631c27a7912538c116d802416ca1eaf2d7a96a147666174636f696e191388a0f5f6';
      final expectedTx = cbor.decode(HEX.decode(expectedHex));
      //print("expected: ${const CborJsonEncoder().convert(expectedTx)}");
      expect(tx.hex, expectedHex, reason: '1st serialization good');

      final BcTransaction tx2 = BcTransaction.fromHex(tx.hex);
      expect(tx, tx2, reason: '1st serialization good');
      //print(tx2.hex);
      expect(tx.hex, tx2.hex);
      //print(tx2.toJson(prettyPrint: true));
      //print(codec.decodedToJSON()); // [1,2,3],67.89,10,{"a":"a/ur1","b":1234567899,"c":"19/04/2020"},"^[12]g"
    });

    test('parse hex', () {
      const txHex =
          '84a40082825820bd7b306c0d67e6fa339e71115d7e951fac8d614e4d8b98e3447804c817c8c5690182582033cbaa6ee8e00a8e0cfdc34bde635e90107d167cbf73e7bb8162887eb249d5b201018282583900d3a1d1a98b2a1ac5349e09242ddbeca7d831da17577d3bbe52b52361269a1cdb0100c324b16c5a555baca45af12098d0beb2abc20808a6171a002191c0825839005a86fcbd65e9deb94da1dd885acb6b8fe149ac9e693ab22e9fc4ccc73e61daf0df57f1cc6fdb15cea66150d63fa3db71c90f8f337960243b1a00417389021a0002a885031a03c9f913a100828258204564d60dd3422b0c35744013666a6ec636ee6343b1e769cef8b614861681d33258400db98ae843765bf535ec3f98daa40dd5da7926d7414d85850662d93bc613f8dbe726b89c2c31c44b10c3a77883d7a72b53500cfc358f7fbfdb6ffec87c318106825820424fb5734588732548fa0f9c8753b1cb527ad09e24d79a305ed5518ccd6299e658407e1134f278f973a771c10c7bd0f925f7811e9fadb9600835925d43791d582d9be6997b939509366e33af3eb760af249487d4858ed59da4a466176c786c57fe07f5f6';
      final tx = BcTransaction.fromHex(txHex);
      logger.info(tx.cborJson);
    });
    test('signPaymentTransactionMultiAccount', () {
      final List<BcTransactionInput> inputs = [
        BcTransactionInput(
            transactionId:
                '73198b7ad003862b9798106b88fbccfca464b1a38afb34958275c4a7d7d8d002',
            index: 1), //long balance1 = 989264070;
        BcTransactionInput(
            transactionId:
                '8e03a93578dc0acd523a4dd861793068a06a68b8a6c7358d0c965d2864067b68',
            index: 0), //long balance2 = 1000000000;
      ];
      final fee = 367965;
      final ttl = 26194586;
      final balance1 = 989264070;
      final amount1 = 5000000;
      final changeAmount1 = balance1 - amount1 - fee;
      final balance2 = 1000000000;
      final amount2 = 8000000;
      final changeAmount2 = balance2 - amount2 - fee;
      final List<BcTransactionOutput> outputs = [
        //output 1
        BcTransactionOutput(
            address:
                'addr_test1qqy3df0763vfmygxjxu94h0kprwwaexe6cx5exjd92f9qfkry2djz2a8a7ry8nv00cudvfunxmtp5sxj9zcrdaq0amtqmflh6v',
            value: BcValue(coin: amount1, multiAssets: [])),
        BcTransactionOutput(
            address:
                'addr_test1qzx9hu8j4ah3auytk0mwcupd69hpc52t0cw39a65ndrah86djs784u92a3m5w475w3w35tyd6v3qumkze80j8a6h5tuqq5xe8y',
            value: BcValue(coin: changeAmount1, multiAssets: [])),
        //output 2
        BcTransactionOutput(
            address:
                'addr_test1qrynkm9vzsl7vrufzn6y4zvl2v55x0xwc02nwg00x59qlkxtsu6q93e6mrernam0k4vmkn3melezkvgtq84d608zqhnsn48axp',
            value: BcValue(coin: amount2, multiAssets: [])),
        BcTransactionOutput(
            address:
                'addr_test1qqwpl7h3g84mhr36wpetk904p7fchx2vst0z696lxk8ujsjyruqwmlsm344gfux3nsj6njyzj3ppvrqtt36cp9xyydzqzumz82',
            value: BcValue(coin: changeAmount2, multiAssets: [])),
      ];

      final body = BcTransactionBody(
        inputs: inputs,
        outputs: outputs,
        fee: fee * 2,
        ttl: ttl,
        metadataHash: null,
        validityStartInterval: 0,
      );
      final tx = BcTransaction(body: body, witnessSet: null, metadata: null);
      final txHex = tx.hex;
      //print(txHex);
      const expectedHex =
          '84a4008282582073198b7ad003862b9798106b88fbccfca464b1a38afb34958275c4a7d7d8d002018258208e03a93578dc0acd523a4dd861793068a06a68b8a6c7358d0c965d2864067b68000184825839000916a5fed4589d910691b85addf608dceee4d9d60d4c9a4d2a925026c3229b212ba7ef8643cd8f7e38d6279336d61a40d228b036f40feed61a004c4b40825839008c5bf0f2af6f1ef08bb3f6ec702dd16e1c514b7e1d12f7549b47db9f4d943c7af0aaec774757d4745d1a2c8dd3220e6ec2c9df23f757a2f81a3aa5102982583900c93b6cac143fe60f8914f44a899f5329433ccec3d53721ef350a0fd8cb873402c73ad8f239f76fb559bb4e3bcff22b310b01eadd3ce205e71a007a1200825839001c1ffaf141ebbb8e3a7072bb15f50f938b994c82de2d175f358fc942441f00edfe1b8d6a84f0d19c25a9c8829442160c0b5c758094c423441a3b1b1aa3021a000b3aba031a018fb29aa0f5f6';
      expect(txHex, expectedHex);
      final acct1 = HdMaster.mnemonic(
        'damp wish scrub sentence vibrant gauge tumble raven game extend winner acid side amused vote edge affair buzz hospital slogan patient drum day vital'
            .split(' '),
        network: Networks.testnet,
      ).account();
      logger.info(
          "acct_xsk: ${Bech32Encoder(hrp: 'xprv').encode(acct1.basePrivateKey())}");
      final acct2 = HdMaster.mnemonic(
        'mixture peasant wood unhappy usage hero great elder emotion picnic talent fantasy program clean patch wheel drip disorder bullet cushion bulk infant balance address'
            .split(' '),
        network: Networks.testnet,
      ).account();
      //two witnesses, two signatures
      final txSigned =
          tx.sign([acct1.basePrivateKey(), acct2.basePrivateKey()]);
      final witness1 = txSigned.witnessSet!.vkeyWitnesses[0];
      expect(witness1.vkey, acct1.basePrivateKey().verifyKey.rawKey);
      final expectedSig1 =
          'bdaff70c01b89da00748579d50267a35d0d349fda3779f28e5aa99c947d41e3c9ec5b8b8dd8349278d83f099a1bcfde250c070fc9640063fba40e783e739c704';
      expect(HEX.encode(witness1.signature), expectedSig1);

      final witness2 = txSigned.witnessSet!.vkeyWitnesses[1];
      expect(witness2.vkey, acct2.basePrivateKey().verifyKey.rawKey);
      final expectedSig2 =
          'd384420623677ba4e92d3b0ffe7ed7bb3037f513f75fc68d8b6462acff11314bb755a603a84f3a1a2b3b61f2661fc747b9462ffd5bc8b4641c4ec10b1e42c60a';
      expect(HEX.encode(witness2.signature), expectedSig2);
      expect(txSigned.verify, isTrue);
    });
  });
}
