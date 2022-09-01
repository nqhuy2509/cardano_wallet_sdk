// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';
import 'package:cbor/cbor.dart';
import '../../util/blake2bhash.dart';
import './bc_abstract.dart';
import './bc_scripts.dart';
import './bc_tx.dart';

class BcAuxiliaryData extends BcAbstractCbor {
  final BcMetadata? metadata;
  final List<BcNativeScript> nativeScripts;
  final List<BcPlutusScriptV1> plutusV1Scripts;
  final List<BcPlutusScriptV2> plutusV2Scripts;

  BcAuxiliaryData({
    this.metadata,
    this.nativeScripts = const [],
    this.plutusV1Scripts = const [],
    this.plutusV2Scripts = const [],
  });

  factory BcAuxiliaryData.fromCbor(CborMap cborMap) => _fromCborMap(cborMap);

  @override
  String get json => toCborJson(toCborMap);

  @override
  Uint8List get serialize => toUint8List(toCborMap);

  Uint8List get hash => Uint8List.fromList(blake2bHash256(serialize));

  bool get isEmpty =>
      (metadata == null || metadata!.isEmpty) &&
      nativeScripts.isEmpty &&
      plutusV1Scripts.isEmpty &&
      plutusV2Scripts.isEmpty;

  CborMap get toCborMap =>
      //TODO metadata may not be a map

      (metadata != null &&
              nativeScripts.isEmpty &&
              plutusV1Scripts.isEmpty &&
              plutusV2Scripts.isEmpty)
          //Shelley-mary format
          ? metadata!.value as CborMap
          //Alonzo format -> tag 259
          : CborMap(
              {
                if (metadata != null) _metaKey: metadata!.value,
                if (nativeScripts.isNotEmpty)
                  _nativeKey: CborList(
                      nativeScripts.map((s) => s.toCborList()).toList()),
                if (plutusV1Scripts.isNotEmpty)
                  _v1Key: CborList(
                      plutusV1Scripts.map((s) => s.cborBytes).toList()),
                if (plutusV2Scripts.isNotEmpty)
                  _v2Key: CborList(
                      plutusV2Scripts.map((s) => s.cborBytes).toList()),
              },
              tags: [_alonzoTag],
            );

  static BcAuxiliaryData _fromCborMap(CborMap cborMap) =>
      (cborMap.tags.contains(_alonzoTag))
          ? BcAuxiliaryData(
              metadata: cborMap.containsKey(_metaKey)
                  ? BcMetadata.fromCbor(map: cborMap[_metaKey]!)
                  : null,
              nativeScripts: cborMap.containsKey(_nativeKey)
                  ? (cborMap[_nativeKey]! as CborList)
                      .map((s) => BcNativeScript.fromCbor(list: s as CborList))
                      .toList()
                  : [],
              plutusV1Scripts: cborMap.containsKey(_v1Key)
                  ? (cborMap[_v1Key]! as CborList)
                      .map((s) => BcPlutusScript.fromCbor(s as CborBytes,
                          type: BcScriptType.plutusV1) as BcPlutusScriptV1)
                      .toList()
                  : [],
              plutusV2Scripts: cborMap.containsKey(_v2Key)
                  ? (cborMap[_v2Key]! as CborList)
                      .map((s) => BcPlutusScript.fromCbor(s as CborBytes,
                          type: BcScriptType.plutusV2) as BcPlutusScriptV2)
                      .toList()
                  : [],
            )
          : BcAuxiliaryData(metadata: BcMetadata.fromCbor(map: cborMap));

  static const _alonzoTag = 259;
  static const _metaKey = CborSmallInt(0);
  static const _nativeKey = CborSmallInt(1);
  static const _v1Key = CborSmallInt(2);
  static const _v2Key = CborSmallInt(3);
}
