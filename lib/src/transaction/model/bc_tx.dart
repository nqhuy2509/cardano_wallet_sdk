// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:bip32_ed25519/bip32_ed25519.dart';
import 'package:cbor/cbor.dart';
import 'package:hex/hex.dart';
import '../../asset/asset.dart';
import '../../util/ada_types.dart';
import '../../util/codec.dart';
import './bc_auxiliary_data.dart';
import './bc_exception.dart';
import './bc_abstract.dart';
import './bc_plutus_data.dart';
import './bc_scripts.dart';
import './bc_redeemer.dart';

class BcAsset {
  final String name;
  final Coin value;

  BcAsset({required this.name, required this.value});

  @override
  String toString() {
    return 'BcAsset(name: $name, value: $value)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BcAsset &&
            other.name == name &&
            other.value == value);
  }

  @override
  int get hashCode => Object.hash(runtimeType, name, value);
}

class BcMultiAsset extends BcAbstractCbor {
  final String policyId;
  final List<BcAsset> assets;

  BcMultiAsset({
    required this.policyId,
    required this.assets,
  });

  BcMultiAsset.lovelace(Coin value)
      : this(policyId: '', assets: [BcAsset(name: lovelaceHex, value: value)]);

  factory BcMultiAsset.fromCbor({required MapEntry mapEntry}) {
    final policyId = HEX.encode((mapEntry.key as CborBytes).bytes);
    final List<BcAsset> assets = [];
    (mapEntry.value as Map).forEach((key, value) => assets.add(BcAsset(
        name: HEX.encode((key as CborBytes).bytes),
        value: (value as CborInt).toInt())));
    return BcMultiAsset(policyId: policyId, assets: assets);
  }

  @override
  CborValue get cborValue => toCborMap();

  //
  //    h'329728F73683FE04364631C27A7912538C116D802416CA1EAF2D7A96': {h'736174636F696E': 4000},
  //
  CborMap toCborMap() {
    final entries = {
      for (var a in assets)
        CborBytes(uint8BufferFromHex(a.name, utf8EncodeOnHexFailure: true)):
            CborSmallInt(a.value)
    };
    return CborMap({CborBytes(uint8BufferFromHex(policyId)): CborMap(entries)});
  }

  @override
  String toString() {
    return 'BcMultiAsset(policyId: $policyId, assets: $assets)';
  }
}

/// Points to an UTXO unspent change entry using a transactionId and index.
class BcTransactionInput extends BcAbstractCbor {
  final String transactionId;
  final int index;
  BcTransactionInput({
    required this.transactionId,
    required this.index,
  });

  factory BcTransactionInput.fromCbor({required CborList list}) {
    return BcTransactionInput(
        transactionId: HEX.encode((list[0] as CborBytes).bytes),
        index: (list[1] as CborSmallInt).toInt());
  }

  @override
  CborValue get cborValue => toCborList();
  CborList toCborList() {
    return CborList(
        [CborBytes(HEX.decode(transactionId)), CborSmallInt(index)]);
  }

  @override
  String toString() {
    return 'BcTransactionInput(transactionId: $transactionId, index: $index)';
  }
}

/// Can be a simple ADA amount using coin or a combination of ADA and Native Tokens and their amounts.
class BcValue extends BcAbstractCbor {
  final Coin coin;
  final List<BcMultiAsset> multiAssets;
  BcValue({
    required this.coin,
    required this.multiAssets,
  });

  factory BcValue.fromCbor({required CborList list}) {
    final List<BcMultiAsset> multiAssets = (list[1] as CborMap)
        .entries
        .map((entry) => BcMultiAsset.fromCbor(mapEntry: entry))
        .toList();
    return BcValue(
        coin: (list[0] as CborInt).toInt(), multiAssets: multiAssets);
  }

  @override
  CborValue get cborValue => toCborList();

  //
  // [
  //  340000,
  //  {
  //    h'329728F73683FE04364631C27A7912538C116D802416CA1EAF2D7A96': {h'736174636F696E': 4000},
  //    h'6B8D07D69639E9413DD637A1A815A7323C69C86ABBAFB66DBFDB1AA7': {h'': 9000}
  //  }
  // ]
  //
  CborList toCborList() {
    final ma = multiAssets
        .map((m) => m.toCborMap())
        .reduce((m1, m2) => m1..addAll(m2));
    return CborList([CborSmallInt(coin), ma]);
  }

  @override
  String toString() {
    return 'BcValue(coin: $coin, multiAssets: $multiAssets)';
  }
}

/// Address to send to and amount to send.
class BcTransactionOutput extends BcAbstractCbor {
  final String address;
  final BcValue value;
  BcTransactionOutput({
    required this.address,
    required this.value,
  });

  factory BcTransactionOutput.fromCbor({required CborList list}) {
    final address =
        bech32ShelleyAddressFromIntList((list[0] as CborBytes).bytes);
    if (list[1] is CborInt) {
      return BcTransactionOutput(
          address: address,
          value: BcValue(coin: (list[1] as CborInt).toInt(), multiAssets: []));
    } else if (list[1] is CborList) {
      final BcValue value = BcValue.fromCbor(list: list[1] as CborList);
      return BcTransactionOutput(address: address, value: value);
    } else {
      throw BcCborDeserializationException();
    }
  }

  @override
  CborValue get cborValue => toCborList();

  CborList toCborList() {
    //length should always be 2
    return CborList([
      CborBytes(unit8BufferFromShelleyAddress(address)),
      value.multiAssets.isEmpty ? CborSmallInt(value.coin) : value.toCborList()
    ]);
  }

  @override
  String toString() {
    return 'BcTransactionOutput(address: $address, value: $value)';
  }
}

/// Core of the Shelley transaction that is signed.
class BcTransactionBody extends BcAbstractCbor {
  final List<BcTransactionInput> inputs;
  final List<BcTransactionOutput> outputs;
  final int fee;
  final int? ttl; //Optional
  final List<int>? metadataHash; //Optional
  final int validityStartInterval;
  final List<BcMultiAsset> mint;

  BcTransactionBody({
    required this.inputs,
    required this.outputs,
    required this.fee,
    this.ttl, //Optional
    this.metadataHash, //Optional
    this.validityStartInterval = 0,
    this.mint = const [],
  });

  factory BcTransactionBody.fromCbor({required CborMap map}) {
    final inputs = (map[const CborSmallInt(0)] as CborList)
        .map((i) => BcTransactionInput.fromCbor(list: i as CborList))
        .toList();
    final outputs = (map[const CborSmallInt(1)] as CborList)
        .map((i) => BcTransactionOutput.fromCbor(list: i as CborList))
        .toList();
    final mint = (map[const CborSmallInt(9)] == null)
        ? null
        : (map[const CborSmallInt(9)] as CborMap)
            .entries
            .map((entry) => BcMultiAsset.fromCbor(mapEntry: entry))
            .toList();
    return BcTransactionBody(
      inputs: inputs,
      outputs: outputs,
      fee: (map[const CborSmallInt(2)] as CborInt).toInt(),
      ttl: map[const CborSmallInt(3)] == null
          ? null
          : (map[const CborSmallInt(3)] as CborInt).toInt(),
      metadataHash: map[const CborSmallInt(7)] == null
          ? null
          : (map[const CborSmallInt(7)] as CborBytes).bytes,
      validityStartInterval: map[const CborSmallInt(8)] == null
          ? 0
          : (map[const CborSmallInt(8)] as CborInt).toInt(),
      mint: mint ?? [],
    );
  }

  @override
  CborValue get cborValue => toCborMap();

  CborMap toCborMap() {
    return CborMap({
      //0:inputs
      const CborSmallInt(0):
          CborList([for (final input in inputs) input.toCborList()]),
      //1:outputs
      const CborSmallInt(1):
          CborList([for (final output in outputs) output.toCborList()]),
      //2:fee
      const CborSmallInt(2): CborSmallInt(fee),
      //3:ttl (optional)
      if (ttl != null) const CborSmallInt(3): CborSmallInt(ttl!),
      //7:metadataHash (optional)
      if (metadataHash != null && metadataHash!.isNotEmpty)
        const CborSmallInt(7): CborBytes(metadataHash!),
      //8:validityStartInterval (optional)
      if (validityStartInterval != 0)
        const CborSmallInt(8): CborSmallInt(validityStartInterval),
      //9:mint (optional)
      if (mint.isNotEmpty)
        const CborSmallInt(9): CborMap(
            mint.map((m) => m.toCborMap()).reduce((m1, m2) => m1..addAll(m2))),
    });
  }

  BcTransactionBody update({
    List<BcTransactionInput>? inputs,
    List<BcTransactionOutput>? outputs,
    int? fee,
    int? ttl,
    List<int>? metadataHash,
    int? validityStartInterval,
    List<BcMultiAsset>? mint,
  }) =>
      BcTransactionBody(
        inputs: inputs ?? this.inputs,
        outputs: outputs ?? this.outputs,
        fee: fee ?? this.fee,
        ttl: ttl ?? this.ttl,
        metadataHash: metadataHash ?? this.metadataHash,
        validityStartInterval:
            validityStartInterval ?? this.validityStartInterval,
        mint: mint ?? this.mint,
      );

  @override
  String toString() {
    return 'BcTransactionBody(inputs: $inputs, outputs: $outputs, fee: $fee, ttl: $ttl, metadataHash: $metadataHash, validityStartInterval: $validityStartInterval, mint: $mint)';
  }
}

/// A witness is a public key and a signature (a signed hash of the body) used for on-chain validation.
class BcVkeyWitness extends BcAbstractCbor {
  final List<int> vkey;
  final List<int> signature;
  BcVkeyWitness({
    required this.vkey,
    required this.signature,
  });

  factory BcVkeyWitness.fromCbor({required CborList list}) {
    return BcVkeyWitness(
        vkey: (list[0] as CborBytes).bytes,
        signature: (list[1] as CborBytes).bytes);
  }

  @override
  CborValue get cborValue => toCborList();

  CborList toCborList() {
    return CborList([CborBytes(vkey), CborBytes(signature)]);
  }

  @override
  String toString() {
    return 'BcVkeyWitness(vkey: $vkey, signature: $signature)';
  }
}

enum BcWitnessSetType {
  verificationKey(0),
  nativeScript(1),
  bootstrap(2),
  plutusScriptV1(3),
  plutusData(4),
  redeemer(5),
  plutusScriptV2(6);

  final int value;
  const BcWitnessSetType(this.value);
}

/// The witness set can be transaction signatures, native scripts, a bootstrap witnesses, plutus V1 or V2 scripts, plutus data or redeemers.
class BcTransactionWitnessSet extends BcAbstractCbor {
  //    transaction_witness_set =
  //    { ? 0: [* vkeywitness ]
  //  , ? 1: [* native_script ]
  //  , ? 2: [* bootstrap_witness ]
  //  , ? 3: [* plutus_v1_script ]
  //  , ? 4: [* plutus_data ]
  //  , ? 5: [* redeemer ]
  //  , ? 6: [* plutus_v2_script ] ; New
  //    }
  final List<BcVkeyWitness> vkeyWitnesses;
  final List<BcNativeScript> nativeScripts;
  final List<BcBootstrapWitness> bootstrapWitnesses;
  final List<BcPlutusScriptV1> plutusScriptsV1;
  final List<BcPlutusData> plutusDataList;
  final List<BcRedeemer> redeemers;
  final List<BcPlutusScriptV2> plutusScriptsV2;
  BcTransactionWitnessSet({
    required this.vkeyWitnesses,
    required this.nativeScripts,
    required this.bootstrapWitnesses,
    required this.plutusScriptsV1,
    required this.plutusDataList,
    required this.redeemers,
    required this.plutusScriptsV2,
  });

  factory BcTransactionWitnessSet.fromCbor({required CborMap map}) {
    final List<BcVkeyWitness> vkeyWitnesses = map[_verificationKey] == null
        ? []
        : (map[_verificationKey] as List)
            .map((list) => BcVkeyWitness.fromCbor(list: list))
            .toList();
    final List<BcNativeScript> nativeScripts = map[_nativeScript] == null
        ? []
        : (map[_nativeScript] as List)
            .map((list) => BcNativeScript.fromCbor(list: list))
            .toList();
    final List<BcBootstrapWitness> bootstrapWitnesses = map[_bootstrap] == null
        ? []
        : (map[_bootstrap] as List)
            .map((list) => BcBootstrapWitness.fromCbor(list: list))
            .toList();
    final List<BcPlutusScriptV1> plutusScriptsV1 = map[_plutusScriptV1] == null
        ? []
        : (map[_plutusScriptV1] as List)
            .map((bytes) =>
                BcPlutusScript.fromCbor(bytes, type: BcScriptType.plutusV1)
                    as BcPlutusScriptV1)
            .toList();
    final List<BcPlutusData> plutusDataList = map[_plutusData] == null
        ? []
        : (map[_plutusData] as List)
            .map((list) => BcPlutusData.fromCbor(list))
            .toList();
    final List<BcRedeemer> redeemers = map[_redeemer] == null
        ? []
        : (map[_redeemer] as List)
            .map((list) => BcRedeemer.fromCbor(list))
            .toList();
    final List<BcPlutusScriptV2> plutusScriptsV2 = map[_plutusScriptV2] == null
        ? []
        : (map[_plutusScriptV2] as List)
            .map((bytes) =>
                BcPlutusScript.fromCbor(bytes, type: BcScriptType.plutusV2)
                    as BcPlutusScriptV2)
            .toList();
    return BcTransactionWitnessSet(
      vkeyWitnesses: vkeyWitnesses,
      nativeScripts: nativeScripts,
      bootstrapWitnesses: bootstrapWitnesses,
      plutusScriptsV1: plutusScriptsV1,
      plutusDataList: plutusDataList,
      redeemers: redeemers,
      plutusScriptsV2: plutusScriptsV2,
    );
  }

  factory BcTransactionWitnessSet.fromHex(String transactionHex) {
    final buff = HEX.decode(transactionHex);
    final cborMap = cbor.decode(buff) as CborMap;
    return BcTransactionWitnessSet.fromCbor(map: cborMap);
  }

  @override
  CborValue get cborValue => toCborMap();

  CborValue toCborMap() {
    return CborMap({
      //0:verificationKey key
      if (vkeyWitnesses.isNotEmpty)
        _verificationKey: CborList.of(vkeyWitnesses.map((w) => w.toCborList())),
      //1:nativeScript key
      if (nativeScripts.isNotEmpty)
        _nativeScript: CborList.of(nativeScripts.map((s) => s.toCborList())),
      //2:bootstrap key
      if (bootstrapWitnesses.isNotEmpty)
        _bootstrap: CborList.of(bootstrapWitnesses.map((s) => s.toCborList())),
      //3:plutusScriptsV1 key
      if (plutusScriptsV1.isNotEmpty)
        _plutusScriptV1: CborList.of(plutusScriptsV1.map((s) => s.cborBytes)),
      //5:redeemer key
      if (redeemers.isNotEmpty)
        _redeemer: CborList.of(redeemers.map((s) => s.cborValue)),
      //6:plutusScriptsV2 key
      if (plutusScriptsV2.isNotEmpty)
        _plutusScriptV2: CborList.of(plutusScriptsV2.map((s) => s.cborBytes)),
    });
  }

  bool get isEmpty =>
      vkeyWitnesses.isEmpty &&
      nativeScripts.isEmpty &&
      bootstrapWitnesses.isEmpty &&
      plutusScriptsV1.isEmpty &&
      plutusDataList.isEmpty &&
      redeemers.isEmpty &&
      plutusScriptsV2.isEmpty;

  bool get isNotEmpty => !isEmpty;

  @override
  String toString() =>
      'BcTransactionWitnessSet(vkeyWitnesses: $vkeyWitnesses, nativeScripts: $nativeScripts, bootstrapWitnesses: $bootstrapWitnesses, $plutusScriptsV1, plutusDataList: $plutusDataList, redeemers: $redeemers, plutusScriptsV2: $plutusScriptsV2)';

  static final _verificationKey =
      CborSmallInt(BcWitnessSetType.verificationKey.value);
  static final _nativeScript =
      CborSmallInt(BcWitnessSetType.nativeScript.value);
  static final _bootstrap = CborSmallInt(BcWitnessSetType.bootstrap.value);
  static final _plutusScriptV1 =
      CborSmallInt(BcWitnessSetType.plutusScriptV1.value);
  static final _plutusData = CborSmallInt(BcWitnessSetType.plutusData.value);
  static final _redeemer = CborSmallInt(BcWitnessSetType.redeemer.value);
  static final _plutusScriptV2 =
      CborSmallInt(BcWitnessSetType.plutusScriptV2.value);
}

class BcBootstrapWitness extends BcAbstractCbor {
  final Uint8List publicKey;
  final Uint8List signature;
  final Uint8List chainCode;
  final Uint8List attributes;

  BcBootstrapWitness({
    required this.publicKey,
    required this.signature,
    required this.chainCode,
    required this.attributes,
  });

  factory BcBootstrapWitness.fromCbor({required CborList list}) =>
      BcBootstrapWitness(
        publicKey: Uint8List.fromList((list[0] as CborBytes).bytes),
        signature: Uint8List.fromList((list[1] as CborBytes).bytes),
        chainCode: Uint8List.fromList((list[2] as CborBytes).bytes),
        attributes: Uint8List.fromList((list[3] as CborBytes).bytes),
      );

  CborList toCborList() => CborList([
        CborBytes(publicKey),
        CborBytes(signature),
        CborBytes(chainCode),
        CborBytes(chainCode),
      ]);

  @override
  CborValue get cborValue => toCborList();
}

///
/// Allow arbitrary metadata via raw CBOR type. Use CborValue and ListBuilder instances to compose complex nested structures.
///
class BcMetadata extends BcAbstractCbor {
  final CborValue value;
  BcMetadata({
    required this.value,
  });

  factory BcMetadata.fromCbor({required CborValue map}) =>
      BcMetadata(value: map);
  factory BcMetadata.fromJson(dynamic json) =>
      BcMetadata(value: BcPlutusData.fromJson(json).cborValue);

  @override
  CborValue get cborValue => value;

  bool get isEmpty => value is CborNull;

  @override
  String toString() {
    return 'BcMetadata(value: $cborJson)';
  }

  dynamic toJson() => BcPlutusData.cborToJson(value);

  BcMetadata merge(BcMetadata metadata1) => BcMetadata(
      value: CborMap(<CborValue, CborValue>{}
        ..addAll(metadata1.value as CborMap)
        ..addAll(value as CborMap)));
}

/// outer wrapper of a Cardano blockchain transaction.
class BcTransaction extends BcAbstractCbor {
  final BcTransactionBody body;
  final BcTransactionWitnessSet? witnessSet;
  final bool? isValid;
  final BcAuxiliaryData auxiliaryData;

  // if metadata present, rebuilds body to include metadataHash
  BcTransaction({
    required BcTransactionBody body,
    this.witnessSet,
    this.isValid = true,
    BcMetadata? metadata,
    List<BcNativeScript> nativeScripts = const [],
    List<BcPlutusScriptV1> plutusV1Scripts = const [],
    List<BcPlutusScriptV2> plutusV2Scripts = const [],
  })  : body = BcTransactionBody(
          //rebuild body to include metadataHash
          inputs: body.inputs,
          outputs: body.outputs,
          fee: body.fee,
          ttl: body.ttl,
          metadataHash: metadata != null && !metadata.isEmpty
              ? metadata.hash
              : null, //optionally add hash if metadata present
          validityStartInterval: body.validityStartInterval,
          mint: body.mint,
        ),
        auxiliaryData = BcAuxiliaryData(
          metadata: metadata,
          nativeScripts: nativeScripts,
          plutusV1Scripts: plutusV1Scripts,
          plutusV2Scripts: plutusV2Scripts,
        );

  factory BcTransaction.fromCbor({required CborList list}) {
    if (list.length < 3) throw BcCborDeserializationException();
    final body = BcTransactionBody.fromCbor(map: list[0] as CborMap);
    final witnessSet =
        BcTransactionWitnessSet.fromCbor(map: list[1] as CborMap);
    final bool? isValid =
        list[2] is CborBool ? (list[2] as CborBool).value : null;
    // final metadata = (list.length >= 3) ? BcMetadata(value: list[3]) : null;
    final auxData = (list.length >= 3 && list[3] is CborMap)
        ? BcAuxiliaryData.fromCbor(list[3] as CborMap)
        : BcAuxiliaryData();
    return BcTransaction(
      body: body,
      witnessSet: witnessSet,
      isValid: isValid,
      metadata: auxData.metadata,
      nativeScripts: auxData.nativeScripts,
      plutusV1Scripts: auxData.plutusV1Scripts,
      plutusV2Scripts: auxData.plutusV2Scripts,
    );
  }

  factory BcTransaction.fromHex(String transactionHex) {
    final buff = HEX.decode(transactionHex);
    final cborList = cbor.decode(buff) as CborList;
    return BcTransaction.fromCbor(list: cborList);
  }

  @override
  CborValue get cborValue => toCborList();

  CborValue toCborList() {
    return CborList([
      body.toCborMap(),
      (witnessSet == null || witnessSet!.isEmpty)
          ? CborMap({})
          : witnessSet!.toCborMap(),
      if (isValid != null) CborBool(isValid ?? true),
      (auxiliaryData.isEmpty) ? const CborNull() : auxiliaryData.toCborMap(),
    ]);
  }

  @override
  String toString() {
    return 'BcTransaction(body: $body, witnessSet: $witnessSet, isValid: $isValid, auxiliaryData: $auxiliaryData)';
  }
}
