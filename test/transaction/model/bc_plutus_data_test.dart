// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:cardano_wallet_sdk/cardano_wallet_sdk.dart';
import 'package:logging/logging.dart';
import 'package:cbor/cbor.dart';
import 'dart:convert' as convert;
import 'dart:typed_data';
import 'dart:io' as io;
import 'package:test/test.dart';
import 'package:hex/hex.dart';
import 'package:oxidized/oxidized.dart';
import 'dart:math';
// import 'dart:typed_data';

void main() {
  Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('BcPlutusDataTest');
  group('PlutusData -', () {
    final fortyTwo = CborInt(BigInt.from(42));
    final hello = CborBytes('hello'.codeUnits);
    final list1 = CborList([fortyTwo, hello]);
    final map1 = CborMap({fortyTwo: hello});

    test('fromCbor', () {
      final cbor1 = BcPlutusData.fromCbor(fortyTwo);
      expect(cbor1 is BcBigIntPlutusData, isTrue);
      expect(cbor1.cborValue, fortyTwo);
      final cbor2 = BcPlutusData.fromCbor(hello);
      expect(cbor2 is BcBytesPlutusData, isTrue);
      expect(cbor2.cborValue, hello);
      final cbor3 = BcPlutusData.fromCbor(list1);
      expect(cbor3 is BcListPlutusData, isTrue);
      expect(cbor3.cborValue, list1);
      final cbor4 = BcPlutusData.fromCbor(map1);
      expect(cbor4 is BcMapPlutusData, isTrue);
      expect(cbor4.cborValue, map1);
    });

    test('cbor', () {
      final list1 = BcListPlutusData([
        BcBigIntPlutusData(BigInt.from(42)),
        BcBigIntPlutusData(BigInt.from(42 * 2)),
        // BcBytesPlutusData.fromString('hello'),
      ]);
      logger.info("type: ${list1.cborValue}");

      expect(list1.cborValue is CborList, isTrue);
      final bytes1 = list1.serialize;
      final list2 = BcPlutusData.deserialize(bytes1);
      expect(list2, equals(list1));
    });
  });
  group('Metadata -', () {
    final ppEncoder = convert.JsonEncoder.withIndent(' ');
    final decoder = convert.JsonDecoder();
    const jsonFilePath = 'test/data/metadata.json';
    Map<dynamic, dynamic> _readJsonKey(String key) {
      final file = io.File(jsonFilePath).absolute;
      final txt = file.readAsStringSync();
      final map = decoder.convert(txt) as Map<String, dynamic>;
      return map[key];
    }

    test('json-n serialization', () {
      for (int i = 1; i < 5; i++) {
        final key = "json-$i";
        final json1 = _readJsonKey(key);
        logger.info("#1 $key: ${ppEncoder.convert(json1)}");
        final m1 = BcMetadata(value: BcPlutusData.fromJson(json1).cborValue);
        CborValue cbor2 = cbor.decode(m1.serialize);
        final m2 = BcMetadata.fromCbor(map: cbor2);
        expect(m2, equals(m1), reason: 'round-trip via CBOR encoding');
        final json2 = m2.toJson();
        logger.info("#2 $key: ${ppEncoder.convert(json2)}");
        final m3 = BcMetadata.fromJson(json2);
        expect(m3, equals(m1), reason: 'round-trip via JSON encoding');
      }
    });

    // this test was a bastard
    // 1) BigInts in JSON must be in quotes because only fixed size integers and decimals are supprted
    // 2) the cardano-client-lib hex test data was out-of-order and BigInts were incorrect
    // 3) https://cbor.me prints BigInt values incorrectly (it's always n-1)
    test('json-1 hex', () {
      final json1 = _readJsonKey('json-1');
      final m1 = BcMetadata(value: BcPlutusData.fromJson(json1).cborValue);
      logger.info("json-1: ${ppEncoder.convert(m1.toJson())}");
      final cm1 = m1.value as CborMap;
      final val4 = cm1[CborInt(BigInt.parse('7274669146951118819'))];
      expect(val4, equals(CborInt(BigInt.parse('-14814972676680046432'))));
      final hex =
          'a61bf710c72e671fae4ba01b0d205105e6e7bacf504ebc4ea3b43bb0cc76bb326f17a30d8f1b12c2c4e58b6778f6a26430783065463bdefda922656830783134666638643bb6597a178e6a15261b6827b4dcb50c5c0b71726365486c5578586c576d5a4a637859641b64f4d10bda83efe33bcd995b2806a1d75f1b12127f810d7dcee28264554a42333be153691687de9cad';
//          'a61bf710c72e671fae4ba01b0d205105e6e7bacf504ebc4ea3b43bb0cc76bb326f17a30d8f1b12c2c4e58b6778f6a26430783065463bdefda922656830783134666638643bb6597a178e6a18971b12127f810d7dcee28264554a42333be153691687de9f671b64f4d10bda83efe33bcd995b2806a1d9971b6827b4dcb50c5c0b71726365486c5578586c576d5a4a63785964';
      logger.info("json-1 hex: ${m1.hex}");
      expect(m1.hex, equals(hex));
    }); //, skip: "TODO - BigInt values are not correct");
  });

  group('BcConstrPlutusData -', () {
    test('concise lt 6', () {
      final p1 = BcConstrPlutusData(
          alternative: 2,
          list: BcListPlutusData([BcBigIntPlutusData(BigInt.from(1280))]));
      final cbor1 = p1.cborValue;
      expect(cbor1.tags.first, equals(123));
      final p2 = BcPlutusData.fromCbor(cbor1) as BcConstrPlutusData;
      expect(p2.alternative, equals(2));
      final big2 = p2.list.list[0] as BcBigIntPlutusData;
      expect(big2.bigInt.toInt(), equals(1280));
      expect(p1, equals(p2));
    });
    test('concise eq 6', () {
      final p1 = BcConstrPlutusData(
          alternative: 6,
          list: BcListPlutusData([BcBigIntPlutusData(BigInt.from(1280))]));
      final cbor1 = p1.cborValue;
      expect(cbor1.tags.first, equals(127));
      final p2 = BcPlutusData.fromCbor(cbor1) as BcConstrPlutusData;
      expect(p2.alternative, equals(6));
      final big2 = p2.list.list[0] as BcBigIntPlutusData;
      expect(big2.bigInt.toInt(), equals(1280));
      expect(p1, equals(p2));
    });
    test('concise eq 7', () {
      final p1 = BcConstrPlutusData(
          alternative: 7,
          list: BcListPlutusData([BcBigIntPlutusData(BigInt.from(5555))]));
      final cbor1 = p1.cborValue;
      expect(cbor1.tags.first, equals(1280));
      final p2 = BcPlutusData.fromCbor(cbor1) as BcConstrPlutusData;
      expect(p2.alternative, equals(7));
      final big2 = p2.list.list[0] as BcBigIntPlutusData;
      expect(big2.bigInt.toInt(), equals(5555));
      expect(p1, equals(p2));
    });
    test('concise eq 10', () {
      final p1 = BcConstrPlutusData(
          alternative: 10,
          list: BcListPlutusData([BcBigIntPlutusData(BigInt.from(5555))]));
      final cbor1 = p1.cborValue;
      expect(cbor1.tags.first, equals(1283));
      final p2 = BcPlutusData.fromCbor(cbor1) as BcConstrPlutusData;
      expect(p2.alternative, equals(10));
      final big2 = p2.list.list[0] as BcBigIntPlutusData;
      expect(big2.bigInt.toInt(), equals(5555));
      expect(p1, equals(p2));
    });
    test('concise eq 127', () {
      final p1 = BcConstrPlutusData(
          alternative: 127,
          list: BcListPlutusData([BcBigIntPlutusData(BigInt.from(5555))]));
      final cbor1 = p1.cborValue;
      expect(cbor1.tags.first, equals(1400));
      final p2 = BcPlutusData.fromCbor(cbor1) as BcConstrPlutusData;
      expect(p2.alternative, equals(127));
      final big2 = p2.list.list[0] as BcBigIntPlutusData;
      expect(big2.bigInt.toInt(), equals(5555));
      expect(p1, equals(p2));
    });
    test('general', () {
      final p1 = BcConstrPlutusData(
          alternative: 8900,
          list: BcListPlutusData([BcBigIntPlutusData(BigInt.from(1280))]));
      final cbor1 = p1.cborValue;
      expect(cbor1.tags.first, equals(BcConstrPlutusData.generalFormTag));
      final p2 = BcPlutusData.fromCbor(cbor1) as BcConstrPlutusData;
      expect(p2.alternative, equals(8900));
      final big2 = p2.list.list[0] as BcBigIntPlutusData;
      expect(big2.bigInt.toInt(), equals(1280));
      expect(p1, equals(p2));
    });
    test('datum hash', () {
      final p1 = BcConstrPlutusData(alternative: 0, list: BcListPlutusData([]));
      final datumHash = p1.hashHex;
      //print("hex: ${p1.hex}");
      expect(p1.hex, equals('d87980'));
      expect(
          datumHash,
          equals(
              '923918e403bf43c34b4ef6b48eb2ee04babed17320d8d1b9ff9ad086e86f44ec'));
    });

    /*
    cardano-client-lib is generating an indefinite length array, even when length it's less than 256.
    The Dart CBOR list handles this internaly:

  void encode(EncodeSink sink) {
    if (length < 256) {
      CborEncodeDefiniteLengthList(this).encode(sink);
    } else {
      // Indefinite length
      CborEncodeIndefiniteLengthList(this).encode(sink);
    }

    TODO Not sure if this is part of the Cardano spec?
    */
    test('serialize', () {
      final p1 = BcConstrPlutusData(
          alternative: 0,
          list: BcListPlutusData([
            BcBytesPlutusData(
                Uint8List.fromList(convert.utf8.encode('Hello World!')))
          ]));
      final hex1 = p1.hex;
      expect(hex1, equals('d8799f4c48656c6c6f20576f726c6421ff'));
    }, skip: 'TODO see note above');
  });
  /*
    @Test
    void serializedContr() throws CborSerializationException, CborException, CborDeserializationException {
        ConstrPlutusData constrPlutusData = ConstrPlutusData.builder()
                .alternative(0)
                .data(ListPlutusData.builder()
                        .plutusDataList(Arrays.asList(BytesPlutusData.builder()
                                .value("Hello World!".getBytes())
                                .build()))
                        .build())
                .build();

        DataItem di = constrPlutusData.serialize();
        byte[] serBytes = CborSerializationUtil.serialize(di);

        String expected = "d8799f4c48656c6c6f20576f726c6421ff";

        assertThat(HexUtil.encodeHexString(serBytes)).isEqualTo(expected);

        DataItem deDI = CborDecoder.decode(serBytes).get(0);
        ConstrPlutusData deConstData = ConstrPlutusData.deserialize(deDI);

        assertThat(deConstData.getAlternative()).isEqualTo(0);
        assertThat(deConstData.getData().getPlutusDataList().size()).isEqualTo(1);
    }
    }*/
}
