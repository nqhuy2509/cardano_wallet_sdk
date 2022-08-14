// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';
import 'package:cbor/cbor.dart';
import 'package:hex/hex.dart';
import '../../util/bigint_parse.dart';
import '../../util/blake2bhash.dart';
import './bc_abstract.dart';

//    plutus_data = ;
//    constr<plutus_data>
//  / { * plutus_data => plutus_data }
//  / [ * plutus_data ]
//  / big_int
//  / bounded_bytes
//
//    big_int = int / big_uint / big_nint ;
//    big_uint = #6.2(bounded_bytes) ;
//    big_nint = #6.3(bounded_bytes) ;

abstract class BcPlutusData extends BcAbstractCbor {
  CborValue get cborValue;

  @override
  String get json => toCborJson(cborValue);

  @override
  Uint8List get serialize => toUint8List(cborValue);

  String get hashHex => HEX.encode(blake2bHash256(serialize));

  dynamic get toJson => cborToJson(cborValue);

  static BcPlutusData fromCborList(CborList cbotList) {
    final item = cbotList[0];
    return fromCbor(item);
  }

  static BcPlutusData deserialize(Uint8List bytes) =>
      fromCbor(cbor.decode(bytes));

  static BcPlutusData fromCbor(CborValue item) {
    if (item is CborInt) {
      return BcBigIntPlutusData(item.toBigInt());
    } else if (item is CborBytes) {
      return BcBytesPlutusData(Uint8List.fromList(item.bytes));
    } else if (item is CborString) {
      return BcBytesPlutusData(Uint8List.fromList(item.utf8Bytes));
    } else if (item is CborList) {
      if (item.tags.isEmpty) {
        return BcListPlutusData(item.map((c) => fromCbor(c)).toList());
      } else {
        return BcConstrPlutusData.fromCbor(item);
      }
    } else if (item is CborMap) {
      return BcMapPlutusData({
        for (MapEntry<CborValue, CborValue> entry in item.entries)
          fromCbor(entry.key): fromCbor(entry.value),
      });
    } else {
      throw CborError(
          "Only support BigInt, ByteString, List and Map CBOR types, not: $item");
    }
  }

  static dynamic cborToJson(CborValue item) {
    if (item is CborInt) {
      return "${item.toBigInt()}";
    } else if (item is CborBytes) {
      return "0x${HEX.encode(item.bytes)}";
    } else if (item is CborString) {
      return item.toString();
    } else if (item is CborList) {
      return item.map((c) => cborToJson(c)).toList();
    } else if (item is CborMap) {
      return {
        for (MapEntry<CborValue, CborValue> entry in item.entries)
          cborToJson(entry.key): cborToJson(entry.value),
      };
    } else {
      throw CborError(
          "Only support BigInt, ByteString, Utf8String, List and Map CBOR types, not: $item");
    }
  }

  static BcPlutusData fromJson(dynamic item, {bool isKey = false}) {
    if (item is List) {
      return BcListPlutusData(item.map((c) => fromJson(c)).toList());
    } else if (item is Map) {
      return BcMapPlutusData({
        for (MapEntry<dynamic, dynamic> entry in item.entries)
          fromJson(entry.key, isKey: true): fromJson(entry.value),
      });
    } else if (item is int) {
      return BcBigIntPlutusData.fromInt(item);
    } else if (item is double) {
      return BcBigIntPlutusData(BigInt.from(item));
    } else if (item is String) {
      final num = tryParseBigInt(item, allowHex: false);
      if (num != null) {
        return BcBigIntPlutusData(num);
      } else {
        if (item.isEmpty) return BcBytesPlutusData(Uint8List.fromList([]));
        final isHex = item.startsWith('0x') && !isKey;
        final list = isHex ? HEX.decode(item.substring(2)) : utf8.encode(item);
        return BcBytesPlutusData(Uint8List.fromList(list), isText: !isHex);
        // return BcBytesPlutusData(uint8ListFromHexOrUtf8String(item));
      }
    } else {
      throw CborError(
          "Only support BigInt, ByteString, List and Map CBOR types, not: $item");
    }
  }
}

class BcBytesPlutusData extends BcPlutusData {
  final Uint8List bytes;
  final bool isText;

  BcBytesPlutusData(this.bytes, {this.isText = false});

  BcBytesPlutusData.fromHex(String hex)
      : this(Uint8List.fromList(HEX.decode(hex)));
  BcBytesPlutusData.fromString(String string)
      : this(Uint8List.fromList(utf8.encode(string)), isText: true);

  @override
  CborValue get cborValue =>
      isText ? CborString.fromUtf8(bytes) : CborBytes(bytes);

  @override
  Uint8List get serialize => bytes;

  // @override
  //Map<String, dynamic> get toJson => {'bytes': HEX.encode(bytes)};
}

class BcBigIntPlutusData extends BcPlutusData {
  final BigInt bigInt;
  BcBigIntPlutusData(this.bigInt);
  BcBigIntPlutusData.fromInt(int i) : this(BigInt.from(i));

  @override
  CborValue get cborValue => CborInt(bigInt);

  // @override
  // Map<String, dynam ic> get toJson => {'bigInt': bigInt.toString()};
}

class BcListPlutusData extends BcPlutusData {
  final List<BcPlutusData> list;

  BcListPlutusData(this.list);

  @override
  CborValue get cborValue => CborList(list.map((c) => c.cborValue).toList());

  // @override
  // Map<String, dynamic> get toJson => {
  //       'list': [
  //         for (BcPlutusData data in list) data.toJson,
  //       ]
  //     };
}

class BcMapPlutusData extends BcPlutusData {
  final Map<BcPlutusData, BcPlutusData> map;

  BcMapPlutusData(this.map);
  @override
  CborValue get cborValue => CborMap.fromEntries(map.entries
      .map((entry) => MapEntry(entry.key.cborValue, entry.value.cborValue)));

  // @override
  // Map<String, dynamic> get toJson => {
  //       for (MapEntry<BcPlutusData, BcPlutusData> e in map.entries)
  //         e.key: e.value
  //     };
}

///
/// Handle data greater than 64 bytes by deviding it into a list of chunks.
///
class BcConstrPlutusData extends BcPlutusData {
  static const generalFormTag = 102;
  final int alternative;
  final BcListPlutusData list;

  BcConstrPlutusData({required this.alternative, required this.list});

  factory BcConstrPlutusData.fromCbor(CborValue list) {
    final tag = list.tags.isNotEmpty ? list.tags.first : generalFormTag;
    if (list is CborList) {
      if (tag == generalFormTag) {
        //general form
        if (list.length != 2) {
          throw CborError(
              "Cbor deserialization failed. Expected 2 DataItem, found : ${list.length}");
        }
        return BcConstrPlutusData(
          alternative: (list[0] as CborInt).toInt(),
          list: BcListPlutusData((list[1] as CborList)
              .map((c) => BcPlutusData.fromCbor(c))
              .toList()),
          // list: BcPlutusData.fromCbor(list[1]) as BcListPlutusData,
        );
      } else {
        //concise form
        final alt = _compactCborTagToAlternative(tag);
        if (alt != null) {
          return BcConstrPlutusData(
            alternative: alt,
            list: BcListPlutusData(
                list.map((c) => BcPlutusData.fromCbor(c)).toList()),
          );
        } else {
          throw CborError("Cbor deserialization failed. Invalid tag: $tag");
        }
      }
    } else {
      throw CborError(
          "Cbor deserialization failed. Invalid argument, expecting CborList, not $list");
    }
  }

  @override
  CborValue get cborValue {
    int tag = _alternativeToCompactCborTag(alternative) ?? generalFormTag;
    final cborList = list.list.map((c) => c.cborValue).toList();
    if (tag == generalFormTag) {
      //general form
      return CborList([CborSmallInt(alternative), CborList(cborList)],
          tags: [tag]);
    } else {
      // compact form
      return CborList(cborList, tags: [tag]);
    }
  }

  static int? _alternativeToCompactCborTag(int alt) => (alt <= 6)
      ? 121 + alt
      : (alt >= 7 && alt <= 127)
          ? 1280 - 7 + alt
          : null;

  static int? _compactCborTagToAlternative(int tag) =>
      (tag >= 121 && tag <= 127)
          ? tag - 121
          : (tag >= 1280 && tag <= 1400)
              ? tag - 1280 + 7
              : null;
}

// class ConstrPlutusData implements PlutusData {
//     // see: https://github.com/input-output-hk/plutus/blob/1f31e640e8a258185db01fa899da63f9018c0e85/plutus-core/plutus-core/src/PlutusCore/Data.hs#L61
//     // We don't directly serialize the alternative in the tag, instead the scheme is:
//     // - Alternatives 0-6 -> tags 121-127, followed by the arguments in a list
//     // - Alternatives 7-127 -> tags 1280-1400, followed by the arguments in a list
//     // - Any alternatives, including those that don't fit in the above -> tag 102 followed by a list containing
//     //   an unsigned integer for the actual alternative, and then the arguments in a (nested!) list.
//     private static final long GENERAL_FORM_TAG = 102;
//     private long alternative;
//     private ListPlutusData data;

//     public static ConstrPlutusData of(long alternative, PlutusData... plutusDataList) {
//         return ConstrPlutusData.builder()
//                 .alternative(alternative)
//                 .data(ListPlutusData.of(plutusDataList))
//                 .build();
//     }

//     public static ConstrPlutusData deserialize(DataItem di) throws CborDeserializationException {
//         Tag tag = di.getTag();
//         Long alternative = null;
//         ListPlutusData data = null;

//         if (GENERAL_FORM_TAG == tag.getValue()) { //general form
//             Array constrArray = (Array) di;
//             List<DataItem> dataItems = constrArray.getDataItems();

//             if (dataItems.size() != 2)
//                 throw new CborDeserializationException("Cbor deserialization failed. Expected 2 DataItem, found : " + dataItems.size());

//             alternative = ((UnsignedInteger) dataItems.get(0)).getValue().longValue();
//             data = ListPlutusData.deserialize((Array) dataItems.get(1));

//         } else { //concise form
//             alternative = compactCborTagToAlternative(tag.getValue());
//             data = ListPlutusData.deserialize((Array) di);
//         }

//         return ConstrPlutusData.builder()
//                 .alternative(alternative)
//                 .data(data)
//                 .build();
//     }

//     private static Long alternativeToCompactCborTag(long alt) {
//         if (alt <= 6) {
//             return 121 + alt;
//         } else if (alt >= 7 && alt <= 127) {
//             return 1280 - 7 + alt;
//         } else
//             return null;
//     }

//     private static Long compactCborTagToAlternative(long cborTag) {
//         if (cborTag >= 121 && cborTag <= 127) {
//             return cborTag - 121;
//         } else if (cborTag >= 1280 && cborTag <= 1400) {
//             return cborTag - 1280 + 7;
//         } else
//             return null;
//     }

//     @Override
//     public DataItem serialize() throws CborSerializationException {
//         Long cborTag = alternativeToCompactCborTag(alternative);
//         DataItem dataItem = null;

//         if (cborTag != null) {
//             // compact form
//             dataItem = data.serialize();
//             dataItem.setTag(cborTag);
//         } else {
//             //general form
//             Array constrArray = new Array();
//             constrArray.add(new UnsignedInteger(alternative));
//             constrArray.add(data.serialize());
//             dataItem = constrArray;
//             dataItem.setTag(GENERAL_FORM_TAG);
//         }

//         return dataItem;
//     }

// public interface PlutusData {

//    plutus_data = ; New
//    constr<plutus_data>
//  / { * plutus_data => plutus_data }
//  / [ * plutus_data ]
//  / big_int
//  / bounded_bytes

//    big_int = int / big_uint / big_nint ; New
//    big_uint = #6.2(bounded_bytes) ; New
//    big_nint = #6.3(bounded_bytes) ; New

//     DataItem serialize() throws CborSerializationException;

//     static PlutusData deserialize(DataItem dataItem) throws CborDeserializationException {
//         if (dataItem == null)
//             return null;

//         if (dataItem instanceof Number) {
//             return BigIntPlutusData.deserialize((Number) dataItem);
//         } else if (dataItem instanceof ByteString) {
//             return BytesPlutusData.deserialize((ByteString) dataItem);
//         } else if (dataItem instanceof Array) {
//             if (dataItem.getTag() == null) {
//                 return ListPlutusData.deserialize((Array) dataItem);
//             } else { //Tag found .. try Constr
//                 return ConstrPlutusData.deserialize(dataItem);
//             }
//         } else if (dataItem instanceof Map) {
//             return MapPlutusData.deserialize((Map) dataItem);
//         } else
//             throw new CborDeserializationException("Cbor deserialization failed. Invalid type. " + dataItem);
//     }

//     static PlutusData deserialize(@NonNull byte[] serializedBytes) throws CborDeserializationException {
//         try {
//             DataItem dataItem = CborDecoder.decode(serializedBytes).get(0);
//             return deserialize(dataItem);
//         } catch (CborException | CborDeserializationException e) {
//             throw new CborDeserializationException("Cbor de-serialization error", e);
//         }
//     }

//     default String getDatumHash() throws CborSerializationException, CborException {
//         return HexUtil.encodeHexString(getDatumHashAsBytes());
//     }

//     default byte[] getDatumHashAsBytes() throws CborSerializationException, CborException {
//         return KeyGenUtil.blake2bHash256(CborSerializationUtil.serialize(serialize()));
//     }

//     default String serializeToHex()  {
//         try {
//             return HexUtil.encodeHexString(CborSerializationUtil.serialize(serialize()));
//         } catch (Exception e) {
//             throw new CborRuntimeException("Cbor serialization error", e);
//         }
//     }
// }
