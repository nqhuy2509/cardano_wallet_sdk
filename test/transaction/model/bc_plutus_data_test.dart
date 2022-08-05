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

    test('json-1', () {
      for (int i = 1; i < 5; i++) {
        final key = "json-$i";
        final json1 = _readJsonKey(key);
        logger.info("#1 $key: ${ppEncoder.convert(json1)}");
        final m1 = BcMetadata(value: BcPlutusData.fromJson(json1).cborValue);
        CborValue cbor2 = cbor.decode(m1.serialize);
        final m2 = BcMetadata.fromCbor(map: cbor2);
        expect(m2, equals(m1));
        final json2 = m2.toJson;
        logger.info("#2 $key: ${ppEncoder.convert(json2)}");
        final m3 = BcMetadata.fromJson(json2);
        expect(m3, equals(m1));
      }
    });
  });
}

/*
    String dataFile = "json-metadata.json";

    @Test
    void testParseJSONMetadata() throws IOException {
        String json = loadJsonMetadata("json-1").toString();
        Metadata metadata = JsonNoSchemaToMetadataConverter.jsonToCborMetadata(json);

        assertNotNull(metadata);

        byte[] serializedBytes = metadata.serialize();
        String hex = Hex.toHexString(serializedBytes);

        String expected = "a61bf710c72e671fae4ba01b0d205105e6e7bacf504ebc4ea3b43bb0cc76bb326f17a30d8f1b12c2c4e58b6778f6a26430783065463bdefda922656830783134666638643bb6597a178e6a18971b12127f810d7dcee28264554a42333be153691687de9f671b64f4d10bda83efe33bcd995b2806a1d9971b6827b4dcb50c5c0b71726365486c5578586c576d5a4a63785964";
        assertEquals(expected, hex);
    }

    @Test
    void testParseJSONMetadataWith2LevelNestedCollection() throws IOException {
        String json = loadJsonMetadata("json-2").toString();
        System.out.println(json);

        Metadata metadata = JsonNoSchemaToMetadataConverter.jsonToCborMetadata(json);

        System.out.println(HexUtil.encodeHexString(metadata.serialize()));
        assertNotNull(metadata);
    }

    private JsonNode loadJsonMetadata(String key) throws IOException {
        ObjectMapper objectMapper = new ObjectMapper();
        JsonNode rootNode = objectMapper.readTree(this.getClass().getClassLoader().getResourceAsStream(dataFile));
        ObjectNode root = (ObjectNode)rootNode;

        return root.get(key);
    }






    @Test
    void serializeDeserialize() throws CborSerializationException, CborException, CborDeserializationException {
        ListPlutusData listPlutusData = ListPlutusData.builder()
                .plutusDataList(Arrays.asList(
                        new BigIntPlutusData(BigInteger.valueOf(1001)),
                        new BigIntPlutusData(BigInteger.valueOf(200)),
                        new BytesPlutusData("hello".getBytes(StandardCharsets.UTF_8))
                )).build();


        byte[] serialize = CborSerializationUtil.serialize(listPlutusData.serialize());

        //deserialize
        List<DataItem> dis = CborDecoder.decode(serialize);
        ListPlutusData deListPlutusData = (ListPlutusData) PlutusData.deserialize(dis.get(0));
        byte[] serialize1 = CborSerializationUtil.serialize(deListPlutusData.serialize());

        assertThat(serialize1).isEqualTo(serialize);
    }

    @Test
    void serializeDeserialize_whenIsChunked_False() throws CborSerializationException, CborException, CborDeserializationException {
        ListPlutusData listPlutusData = ListPlutusData.builder()
                .plutusDataList(Arrays.asList(
                        new BigIntPlutusData(BigInteger.valueOf(1001)),
                        new BigIntPlutusData(BigInteger.valueOf(200)),
                        new BytesPlutusData("hello".getBytes(StandardCharsets.UTF_8))
                ))
                .isChunked(false)
                .build();


        byte[] serialize = CborSerializationUtil.serialize(listPlutusData.serialize());

        //deserialize
        List<DataItem> dis = CborDecoder.decode(serialize);
        ListPlutusData deListPlutusData = (ListPlutusData) PlutusData.deserialize(dis.get(0));
        byte[] serialize1 = CborSerializationUtil.serialize(deListPlutusData.serialize());

        assertThat(serialize1).isEqualTo(serialize);
    }
*/
