// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:cardano_wallet_sdk/cardano_wallet_sdk.dart';
import 'package:logging/logging.dart';
import 'package:cbor/cbor.dart';
import 'dart:convert' as convert;
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
        BcPlutusScriptV1(
          description: 'V1 only',
          cborHex: '4e4d01000033222220051200120011',
        )
      ]);
      final hashHex = HEX.encode(auxiliaryData.hash);
      expect(
          hashHex,
          equals(
              '7f0a2910e344e22e60ee9fa985820e9b5136977c15ddd6a38d134b1dc4f3e150'));
    });

    test('hash V2', () {
      final auxiliaryData = BcAuxiliaryData(plutusV2Scripts: [
        BcPlutusScriptV2(
          description: 'V2 only',
          cborHex: '4e4d01000033222220051200120011',
        )
      ]);
      expect(auxiliaryData.toHex,
          equals('d90103a103814e4d01000033222220051200120011'));
      final hashHex = HEX.encode(auxiliaryData.hash);
      expect(
          hashHex,
          equals(
              'bbe94949bec1152ab70f5d4689b9c6242fd4591dbc32ca84ad7140246128263e'));
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

        @Test
        public void serializeDeserialize() throws CborSerializationException, CborDeserializationException {
                CBORMetadata metadata = new CBORMetadata();
                CBORMetadataMap map = new CBORMetadataMap();
                map.put("key1", "value1");
                map.put(BigInteger.valueOf(1001), "bigValue");
                map.put(new byte[] { 1, 2 }, "byteValue");

                CBORMetadataList list = new CBORMetadataList();
                list.add("listValue1");
                list.add(BigInteger.valueOf(2));

                metadata.put(BigInteger.valueOf(11), map);
                metadata.put(BigInteger.valueOf(22), list);

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
        }

        @Test
        public void serializeDeserialize_noAuxData() throws CborSerializationException, CborDeserializationException {
                CBORMetadata metadata = new CBORMetadata();
                CBORMetadataMap map = new CBORMetadataMap();
                map.put("key1", "value1");
                map.put(BigInteger.valueOf(1001), "bigValue");
                map.put(new byte[] { 1, 2 }, "byteValue");

                CBORMetadataList list = new CBORMetadataList();
                list.add("listValue1");
                list.add(BigInteger.valueOf(2));

                metadata.put(BigInteger.valueOf(11), map);
                metadata.put(BigInteger.valueOf(22), list);

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
        } */

const jsonFilePath = 'test/data/metadata.json';

final decoder = convert.JsonDecoder();

Map<dynamic, dynamic> _readJsonKey(String key) {
  final file = io.File(jsonFilePath).absolute;
  final txt = file.readAsStringSync();
  final map = decoder.convert(txt) as Map<String, dynamic>;
  return map[key];
}
