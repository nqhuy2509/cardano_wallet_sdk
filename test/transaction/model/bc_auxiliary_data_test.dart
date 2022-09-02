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
// import 'dart:typed_data';

void main() {
  // Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('BcAuxiliaryDataTest');
  group('AuxiliaryData -', () {
    test('hash from metadata', () {
      final metadata = BcMetadata.fromJson(_readJsonKey('json-4'));
      final auxiliaryData = BcAuxiliaryData(metadata: metadata);
      final hashHex = HEX.encode(auxiliaryData.hash);
      expect(
          hashHex,
          equals(
              '17df7ed927194d072174f36ac34e09f92e8a63f4131bef66d8cd186b95b6bfe8'));
    },
        skip:
            'bad metadata - see bc_scripts.dart indefinite length array notes');
    test('hash V1', () {
      final auxiliaryData = BcAuxiliaryData(plutusV1Scripts: [
        BcPlutusScriptV1.parse(
          description: 'V1 only',
          cborHex: '4e4d01000033222220051200120011',
        )
      ]);
      print("expected hex: d90103a102814e4d01000033222220051200120011");
      final hashHex0 = auxiliaryData.hex;
      print("  actual hex: $hashHex0");
      final hashHex = HEX.encode(auxiliaryData.hash);
      expect(
          hashHex,
          equals(
              '7f0a2910e344e22e60ee9fa985820e9b5136977c15ddd6a38d134b1dc4f3e150'));
    });

    test('hash V2', () {
      final auxiliaryData = BcAuxiliaryData(plutusV2Scripts: [
        BcPlutusScriptV2.parse(
          description: 'V2 only',
          cborHex: '4e4d01000033222220051200120011',
        )
      ]);
      expect(auxiliaryData.hex,
          equals('d90103a103814e4d01000033222220051200120011'));
      final hashHex = HEX.encode(auxiliaryData.hash);
      expect(
          hashHex,
          equals(
              'bbe94949bec1152ab70f5d4689b9c6242fd4591dbc32ca84ad7140246128263e'));
    });

    test('hash PlutusScript and metadata', () {
      final list = BcListPlutusData([
        BcBytesPlutusData.fromString(
            'First contract call from cardano-client-lib : A client library for Cardano')
      ]);
      final map = BcMapPlutusData({
        BcBytesPlutusData.fromString('msg'): list,
        BcBigIntPlutusData.fromInt(674): list,
      });
      final auxiliaryData = BcAuxiliaryData(
          metadata: BcMetadata(value: map.cborValue),
          plutusV1Scripts: [
            BcPlutusScriptV1.parse(
              description: 'V1 + Metadata',
              cborHex: '4e4d01000033222220051200120011',
            )
          ]);
      final hashHex = HEX.encode(auxiliaryData.hash);
      expect(
          hashHex,
          equals(
              '591ad666282de3400e798f7a78957410624b0bb7bcbc004325eafc869818f142'));
    },
        skip:
            'bad metadata - see bc_scripts.dart indefinite length array notes');

    test('marshalling round trip', () {
      final map = BcMapPlutusData({
        BcBytesPlutusData.fromString('key1'):
            BcBytesPlutusData.fromString('value1'),
        BcBigIntPlutusData.fromInt(1001):
            BcBytesPlutusData.fromString('bigValue'),
        BcBytesPlutusData(Uint8List.fromList([1, 2])):
            BcBytesPlutusData.fromString('byteValue'),
      });
      final list = BcListPlutusData([
        BcBytesPlutusData.fromString('listValue1'),
        BcBigIntPlutusData.fromInt(2)
      ]);
      final sp1 = BcScriptPubkey(
          keyHash: '2f3d4cf10d0471a1db9f2d2907de867968c27bca6272f062cd1c2413');
      final sp2 = BcScriptPubkey(
          keyHash: 'f856c0c5839bab22673747d53f1ae9eed84afafb085f086e8e988614');
      final s1 =
          BcPlutusScriptV1.parse(cborHex: '4d01000033222220051200120011');
      final s2 =
          BcPlutusScriptV1.parse(cborHex: '4e4d01000033222220051200120011');
      final map0 = BcMapPlutusData({
        BcBigIntPlutusData.fromInt(11): map,
        BcBigIntPlutusData.fromInt(22): list,
      });
      final cbor0 = map0.cborValue;
      final auxiliaryData1 = BcAuxiliaryData(
        metadata: BcMetadata(value: cbor0),
        nativeScripts: [sp1, sp2],
        plutusV1Scripts: [s1, s2],
      );
      final cbor1 = auxiliaryData1.toCborMap();
      final hex1 = auxiliaryData1.hex;
      final auxiliaryData2 = BcAuxiliaryData.fromCbor(cbor1);
      final hex2 = auxiliaryData2.hex;
      expect(hex2, equals(hex1));
      expect(auxiliaryData2, equals(auxiliaryData1));

      /*

                // Native script
                ScriptPubkey scriptPubkey1 = ScriptPubkey.createWithNewKey()._1;
                ScriptPubkey scriptPubkey2 = ScriptPubkey.createWithNewKey()._1;

                PlutusV1Script plutusScript1 = PlutusV1Script.builder()
                                .type("PlutusScriptV1")
                                .cborHex("4d01000033222220051200120011")
                                .build();

                PlutusV1Script plutusScript2 = PlutusV1Script.builder()
                                .type("PlutusScriptV1")
                                .cborHex("4e4d01000033222220051200120011")
                                .build();

                AuxiliaryData auxData = AuxiliaryData.builder()
                                .metadata(metadata)
                                .nativeScripts(Arrays.asList(scriptPubkey1, scriptPubkey2))
                                .plutusV1Scripts(Arrays.asList(plutusScript1, plutusScript2))
                                .build();

                DataItem dataItem = auxData.serialize();

                AuxiliaryData deAuxData = AuxiliaryData.deserialize((Map) dataItem);
                CBORMetadata deMetadata = (CBORMetadata) deAuxData.getMetadata();
                Map deMap = (Map) deMetadata.getData().get(new UnsignedInteger(11));
                Array deArray = (Array) deMetadata.getData().get(new UnsignedInteger(22));

                // asserts
                assertThat(deAuxData.getNativeScripts()).hasSize(2);
                assertThat(deAuxData.getPlutusV1Scripts()).hasSize(2);

                assertThat(deMap.get(new UnicodeString("key1"))).isEqualTo(new UnicodeString("value1"));

                assertThat(deAuxData.getNativeScripts())
                                .containsExactlyElementsOf(Arrays.asList(scriptPubkey1, scriptPubkey2));
                assertThat(deAuxData.getPlutusV1Scripts())
                                .containsExactlyElementsOf(Arrays.asList(plutusScript1, plutusScript2));
                                */
    });
  });
}

/*
        @Test
        public void getAuxiliaryDataHash_whenPlutusScriptAndMetadata()
                        throws CborSerializationException, CborException {
                PlutusV1Script plutusScript = PlutusV1Script.builder()
                                .type("PlutusScriptV1")
                                .cborHex("4e4d01000033222220051200120011")
                                .build();

                CBORMetadata cborMetadata = new CBORMetadata();
                CBORMetadataMap metadataMap = new CBORMetadataMap();
                CBORMetadataList metadataList = new CBORMetadataList();
                metadataList.add("First contract call from cardano-client-lib : A client library for Cardano");
                metadataMap.put("msg", metadataList);
                cborMetadata.put(new BigInteger("674"), metadataList);

                AuxiliaryData auxiliaryData = AuxiliaryData.builder()
                                .metadata(cborMetadata)
                                .plutusV1Scripts(Arrays.asList(plutusScript))
                                .build();

                System.out.println(HexUtil.encodeHexString(CborSerializationUtil.serialize(auxiliaryData.serialize())));
                byte[] auxHashBytes = auxiliaryData.getAuxiliaryDataHash();
                String auxHash = HexUtil.encodeHexString(auxHashBytes);

                assertThat(auxHash).isEqualTo("591ad666282de3400e798f7a78957410624b0bb7bcbc004325eafc869818f142");
        }
*/

const jsonFilePath = 'test/data/metadata.json';

final decoder = convert.JsonDecoder();

Map<dynamic, dynamic> _readJsonKey(String key) {
  final file = io.File(jsonFilePath).absolute;
  final txt = file.readAsStringSync();
  final map = decoder.convert(txt) as Map<String, dynamic>;
  return map[key];
}
