// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:bip32_ed25519/bip32_ed25519.dart';
import 'package:hex/hex.dart';
import 'package:cbor/cbor.dart';
import '../../crypto/key_util.dart';
import '../../util/blake2bhash.dart';
import '../../util/codec.dart';
import './bc_exception.dart';
import './bc_abstract.dart';

///
/// From the Shelley era onwards, Cardano has supported scripts and script addresses.
///
/// Cardano is designed to support multiple script languages, and most features that
/// are related to scripts work the same irrespective of the script language (or
/// version of a script language).
///
/// The Shelley era supports a single, simple script language, which can be used for
/// multi-signature addresses. The Allegra era (token locking) extends the simple
/// script language with a feature to make scripts conditional on time. This can be
/// used to make address with so-called "time locks", where the funds cannot be
/// withdrawn until after a certain point in time.
///
/// see https://github.com/input-output-hk/cardano-node/blob/master/doc/reference/simple-scripts.md
///

enum BcScriptType {
  unknown(-1),
  native(0),
  plutusV1(1),
  plutusV2(2);

  final int header;
  const BcScriptType(this.header);

  factory BcScriptType.fromName(String name) => BcScriptType.values
      .firstWhere((e) => e.name == name, orElse: () => BcScriptType.unknown);
  factory BcScriptType.fromHeader(int header) =>
      BcScriptType.values.firstWhere((e) => e.header == header,
          orElse: () => BcScriptType.unknown);
}

abstract class BcAbstractScript extends BcAbstractCbor {
  BcScriptType get type;
  // TODO rename hash?
  Uint8List get scriptHash => Uint8List.fromList(blake2bHash224(_hashBytes));

  List<int> get _hashBytes => [
        ...[type.header],
        ...serialize,
      ];
}

abstract class BcPlutusScript extends BcAbstractScript {
  @override
  final BcScriptType type;
  final CborBytes cborValue;
  final String? description;

  BcPlutusScript({
    required this.type,
    required this.cborValue,
    this.description,
  });
  BcPlutusScript.parse(
      {required String cborHex, required this.type, this.description})
      : cborValue = cbor.decode(HEX.decode(cborHex)) as CborBytes;

  // factory BcPlutusScript.fromCbor(CborBytes cborBytes, {String? description}) =>
  //     cborBytes.bytes[0] == BcScriptType.plutusV1.header
  //         ? BcPlutusScriptV1(
  //             description: description,
  //             cborHex: HEX.encode(cborBytes.bytes.sublist(1)),
  //           )
  //         : BcPlutusScriptV2(
  //             description: description,
  //             cborHex: HEX.encode(cborBytes.bytes.sublist(1)),
  //           );
  factory BcPlutusScript.fromCbor(CborBytes cborBytes,
          {required BcScriptType type, String? description}) =>
      type == BcScriptType.plutusV1
          ? BcPlutusScriptV1(
              description: description,
              cborValue: cborBytes,
            )
          : BcPlutusScriptV2(
              description: description,
              cborValue: cborBytes,
            );

  // CborBytes toCborBytes() => CborBytes(_bytes);
  //   final dec = cbor.decode(_bytes);
  //   return dec as CborBytes;
  // }
  // => cbor.decode(serialize) as CborBytes;

  CborBytes get cborBytes => cborValue;

  String get cborHex => toHex;

  // Uint8List get _bytes =>
  //     uint8ListFromHex(cborHex, utf8EncodeOnHexFailure: true);

  @override
  Uint8List get serialize => toUint8List(cborValue);

  @override
  String toString() {
    return 'BcPlutusScript(type: $type, description: $description, cborHex: $cborHex)';
  }

  // TODO rename hash?
  // @override
  // Uint8List get scriptHash => Uint8List.fromList(blake2bHash224(_hashBytes));

  @override
  String get json => toCborJson(cborBytes);

  Map<String, dynamic> get toJson => <String, dynamic>{
        if (description != null) 'description': description,
        'type': type.name,
        'cborHex': cborHex,
      };

  factory BcPlutusScript.fromJson(Map<String, dynamic> json) =>
      BcScriptType.fromName(json['type'] as String) == BcScriptType.plutusV1
          ? BcPlutusScriptV1.parse(
              description: json['description'] as String?,
              cborHex: json['cborHex'] as String,
            )
          : BcPlutusScriptV2.parse(
              description: json['description'] as String?,
              cborHex: json['cborHex'] as String,
            );
}

class BcPlutusScriptV1 extends BcPlutusScript {
  BcPlutusScriptV1({required CborBytes cborValue, String? description})
      : super(
            cborValue: cborValue,
            description: description,
            type: BcScriptType.plutusV1);
  BcPlutusScriptV1.parse({required String cborHex, String? description})
      : super.parse(
          cborHex: cborHex,
          description: description,
          type: BcScriptType.plutusV1,
        );
}

class BcPlutusScriptV2 extends BcPlutusScript {
  BcPlutusScriptV2({required CborBytes cborValue, String? description})
      : super(
            cborValue: cborValue,
            description: description,
            type: BcScriptType.plutusV2);
  BcPlutusScriptV2.parse({required String cborHex, String? description})
      : super.parse(
          cborHex: cborHex,
          description: description,
          type: BcScriptType.plutusV2,
        );
}

enum BcNativeScriptType {
  unknown(-1),
  sig(0),
  all(1),
  any(2),
  atLeast(3),
  after(4),
  before(5);

  final int code;
  const BcNativeScriptType(this.code);
  factory BcNativeScriptType.fromName(String name) =>
      BcNativeScriptType.values.firstWhere((e) => e.name == name,
          orElse: () => BcNativeScriptType.unknown);
  factory BcNativeScriptType.fromCode(int code) =>
      BcNativeScriptType.values.firstWhere((e) => e.code == code,
          orElse: () => BcNativeScriptType.unknown);
}

abstract class BcNativeScript extends BcAbstractScript {
  @override
  final BcScriptType type = BcScriptType.native;
  BcNativeScriptType get nativeType;

  CborList toCborList();

  @override
  Uint8List get serialize => toUint8List(toCborList());

  static BcNativeScript fromCbor({required CborList list}) {
    final selector = list[0] as CborSmallInt;
    final nativeType = BcNativeScriptType.fromCode(selector.toInt());
    switch (nativeType) {
      case BcNativeScriptType.sig:
        return BcScriptPubkey.fromCbor(list: list);
      case BcNativeScriptType.all:
        return BcScriptAll.fromCbor(list: list);
      case BcNativeScriptType.any:
        return BcScriptAny.fromCbor(list: list);
      case BcNativeScriptType.atLeast:
        return BcScriptAtLeast.fromCbor(list: list);
      case BcNativeScriptType.after:
        return BcRequireTimeAfter.fromCbor(list: list);
      case BcNativeScriptType.before:
        return BcRequireTimeBefore.fromCbor(list: list);
      case BcNativeScriptType.unknown:
        throw BcCborDeserializationException(
            "unknown native script selector: $selector");
    }
  }

  String get policyId => HEX.encode(blake2bHash224([
        ...[type.header],
        ...serialize
      ]));

  static List<BcNativeScript> deserializeScripts(CborList scriptList) {
    return <BcNativeScript>[
      for (dynamic blob in scriptList)
        BcNativeScript.fromCbor(list: blob as CborList),
    ];
  }

  @override
  String get json => toCborJson(toCborList());

  Map<String, dynamic> get toJson;

  static BcNativeScript fromJson(Map<String, dynamic> json) {
    final selector = json['type'] as String;
    final nativeType = BcNativeScriptType.fromName(selector);
    switch (nativeType) {
      case BcNativeScriptType.sig:
        return BcScriptPubkey.fromJson(json);
      case BcNativeScriptType.all:
        return BcScriptAll.fromJson(json);
      case BcNativeScriptType.any:
        return BcScriptAny.fromJson(json);
      case BcNativeScriptType.atLeast:
        return BcScriptAtLeast.fromJson(json);
      case BcNativeScriptType.after:
        return BcRequireTimeAfter.fromJson(json);
      case BcNativeScriptType.before:
        return BcRequireTimeBefore.fromJson(json);
      case BcNativeScriptType.unknown:
        throw BcCborDeserializationException(
            "unknown native script selector: $selector");
    }
  }
}

class BcScriptPubkey extends BcNativeScript {
  @override
  final BcNativeScriptType nativeType = BcNativeScriptType.sig;
  final String keyHash;

  BcScriptPubkey({
    required this.keyHash,
  });

  factory BcScriptPubkey.fromCbor({required CborList list}) {
    final keyHash = list[1] as CborBytes;
    return BcScriptPubkey(keyHash: HEX.encode(keyHash.bytes));
  }

  factory BcScriptPubkey.fromKey({required VerifyKey verifyKey}) =>
      BcScriptPubkey(keyHash: KeyUtil.keyHash(verifyKey: verifyKey));

  factory BcScriptPubkey.fromJson(Map<String, dynamic> json) =>
      BcScriptPubkey(keyHash: (json['keyHash'] as String));

  @override
  CborList toCborList() => CborList([
        CborSmallInt(nativeType.code),
        CborBytes(uint8BufferFromHex(keyHash, utf8EncodeOnHexFailure: true))
      ]);

  @override
  String toString() {
    return 'BcScriptPubkey(nativeType: $nativeType, keyHash: $keyHash)';
  }

  @override
  Map<String, dynamic> get toJson => {
        'type': nativeType.name,
        'keyHash': keyHash,
      };
}

class BcScriptAll extends BcNativeScript {
  @override
  final BcNativeScriptType nativeType = BcNativeScriptType.all;
  final List<BcNativeScript> scripts;

  BcScriptAll({
    required this.scripts,
  });

  factory BcScriptAll.fromCbor({required CborList list}) {
    final scripts = BcNativeScript.deserializeScripts(list[1] as CborList);
    return BcScriptAll(scripts: scripts);
  }

  factory BcScriptAll.fromJson(Map<String, dynamic> json) => BcScriptAll(
      scripts: (json['scripts'] as List<dynamic>)
          .map((e) => BcNativeScript.fromJson(e as Map<String, dynamic>))
          .toList());

  @override
  CborList toCborList() {
    return CborList([
      CborSmallInt(nativeType.code),
      CborList([for (var s in scripts) s.toCborList()]),
    ]);
  }

  @override
  String toString() {
    return 'BcScriptAll(nativeType: $nativeType, scripts: $scripts)';
  }

/*
  {"name":"MultiSigPolicy",
    "policyScript":{"type":"all","scripts":[
      {"type":"sig","keyHash":"2e5adb21a00882b43e7b9c16d457cfab78699d27cb7833b7a8bd11b6"},
      {"type":"sig","keyHash":"786645049d724ace01dbb397646fa4de5d936c770f02c5eb1b89456a"},
      {"type":"sig","keyHash":"e5df1f1439c7bf1c265db00d46ea07fe2708af720fafcef560bded27"}
      ]},
    "policyKeys":[
      {"type":"PaymentVerificationKeyShelley_ed25519","description":"Payment Signing Key","cborHex":"582088dfc434edf14d3e72ba518c2aad3132e51d721a183662dc9c42156caebee48c"},
      {"type":"PaymentVerificationKeyShelley_ed25519","description":"Payment Signing Key","cborHex":"5820389f6de926f003c648f9184ad7d74cea8951ef3c6fa875da2ab4626febc6542d"},
      {"type":"PaymentVerificationKeyShelley_ed25519","description":"Payment Signing Key","cborHex":"58201d74e9f2e6bfa76afd60a5a7851df601f607d5c7a01351ee43fa9253975dda16"}
      ],
    "policyId":"403687b05f2c8f8f8e7a5c860c0b489fc041bf75f8404c409d9a3b80"
  }
  */
  @override
  Map<String, dynamic> get toJson => {
        'type': nativeType.name,
        'scripts': [for (BcNativeScript s in scripts) s.toJson],
      };
}

class BcScriptAny extends BcNativeScript {
  @override
  final BcNativeScriptType nativeType = BcNativeScriptType.any;
  final List<BcNativeScript> scripts;
  BcScriptAny({
    required this.scripts,
  });

  factory BcScriptAny.fromCbor({required CborList list}) {
    final scripts = BcNativeScript.deserializeScripts(list[1] as CborList);
    return BcScriptAny(scripts: scripts);
  }

  factory BcScriptAny.fromJson(Map<String, dynamic> json) => BcScriptAny(
      scripts: (json['scripts'] as List<dynamic>)
          .map((e) => BcNativeScript.fromJson(e as Map<String, dynamic>))
          .toList());

  @override
  CborList toCborList() {
    return CborList([
      CborSmallInt(nativeType.code),
      CborList([for (var s in scripts) s.toCborList()]),
    ]);
  }

  @override
  String toString() {
    return 'BcScriptAny(nativeType: $nativeType, scripts: $scripts)';
  }

  @override
  Map<String, dynamic> get toJson => {
        'type': nativeType.name,
        'scripts': [for (BcNativeScript s in scripts) s.toJson],
      };
}

class BcScriptAtLeast extends BcNativeScript {
  @override
  final BcNativeScriptType nativeType = BcNativeScriptType.atLeast;
  final int amount;
  final List<BcNativeScript> scripts;
  BcScriptAtLeast({
    required this.amount,
    required this.scripts,
  });

  factory BcScriptAtLeast.fromCbor({required CborList list}) {
    final scripts = BcNativeScript.deserializeScripts(list[2] as CborList);
    return BcScriptAtLeast(
        amount: (list[1] as CborSmallInt).toInt(), scripts: scripts);
  }

  factory BcScriptAtLeast.fromJson(Map<String, dynamic> json) =>
      BcScriptAtLeast(
          amount: json['amount'] as int,
          scripts: (json['scripts'] as List<dynamic>)
              .map((e) => BcNativeScript.fromJson(e as Map<String, dynamic>))
              .toList());

  @override
  CborList toCborList() {
    return CborList([
      CborSmallInt(nativeType.code),
      CborSmallInt(amount),
      CborList([for (var s in scripts) s.toCborList()]),
    ]);
  }

  @override
  String toString() {
    return 'BcScriptAtLeast(nativeType: $nativeType, amount: $amount, scripts: $scripts)';
  }

  @override
  Map<String, dynamic> get toJson => {
        'type': nativeType.name,
        'amount': amount,
        'scripts': [for (BcNativeScript s in scripts) s.toJson],
      };
}

class BcRequireTimeAfter extends BcNativeScript {
  @override
  final BcNativeScriptType nativeType = BcNativeScriptType.after;
  final int slot;
  BcRequireTimeAfter({
    required this.slot,
  });

  factory BcRequireTimeAfter.fromCbor({required CborList list}) {
    return BcRequireTimeAfter(slot: (list[1] as CborSmallInt).toInt());
  }

  factory BcRequireTimeAfter.fromJson(Map<String, dynamic> json) =>
      BcRequireTimeAfter(slot: json['slot'] as int);

  @override
  CborList toCborList() {
    return CborList([
      CborSmallInt(nativeType.code),
      CborSmallInt(slot),
    ]);
  }

  @override
  String toString() {
    return 'BcRequireTimeAfter(nativeType: $nativeType, slot: $slot)';
  }

  @override
  Map<String, dynamic> get toJson => {
        'type': nativeType.name,
        'slot': slot,
      };
}

class BcRequireTimeBefore extends BcNativeScript {
  @override
  final BcNativeScriptType nativeType = BcNativeScriptType.before;
  final int slot;
  BcRequireTimeBefore({
    required this.slot,
  });

  factory BcRequireTimeBefore.fromCbor({required CborList list}) {
    return BcRequireTimeBefore(slot: (list[1] as CborSmallInt).toInt());
  }

  factory BcRequireTimeBefore.fromJson(Map<String, dynamic> json) =>
      BcRequireTimeBefore(slot: json['slot'] as int);

  @override
  CborList toCborList() {
    return CborList([
      CborSmallInt(nativeType.code),
      CborSmallInt(slot),
    ]);
  }

  @override
  String toString() {
    return 'BcRequireTimeBefore(nativeType: $nativeType, slot: $slot)';
  }

  @override
  Map<String, dynamic> get toJson => {
        'type': nativeType.name,
        'slot': slot,
      };
}
