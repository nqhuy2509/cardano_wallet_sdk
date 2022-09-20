// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:bip32_ed25519/bip32_ed25519.dart';
import 'package:cbor/cbor.dart';
import 'package:hex/hex.dart';
import './bc_abstract.dart';
import './bc_plutus_data.dart';

enum BcRedeemerTag {
  spend(0),
  mint(1),
  cert(2),
  reward(3);

  final int value;
  const BcRedeemerTag(this.value);

  static BcRedeemerTag fromCbor(CborValue value) {
    if (value is CborInt && value.toInt() >= 0 && value.toInt() < 5) {
      return BcRedeemerTag.values[value.toInt()];
    } else {
      throw CborError(
          "BcRedeemerTag expecting CborInt with value in [0..3], not $value");
    }
  }
}

class BcRedeemer extends BcAbstractCbor {
  final BcRedeemerTag tag;
  final BigInt index;
  final BcPlutusData data;
  final BcExUnits exUnits;

  BcRedeemer(
      {required this.tag,
      required this.index,
      required this.data,
      required this.exUnits});

  static BcRedeemer deserialize(Uint8List bytes) =>
      fromCbor(cbor.decode(bytes));

  static BcRedeemer fromCbor(CborValue item) {
    if (item is CborList) {
      if (item.length == 4) {
        return BcRedeemer(
          tag: BcRedeemerTag.fromCbor(item[0]),
          index: (item[1] as CborInt).toBigInt(),
          data: BcPlutusData.fromCbor(item[2]),
          exUnits: BcExUnits.fromCbor(item[3]),
        );
      } else {
        throw CborError(
            "Redeemer list must contain 4 properties, not ${item.length}");
      }
    } else {
      throw CborError("Redeemer expecting CborList, not $item");
    }
  }

  factory BcRedeemer.fromHex(String hex) =>
      BcRedeemer.fromCbor(cbor.decode(HEX.decode(hex)));

  @override
  CborValue get cborValue => CborList([
        CborSmallInt(tag.value),
        CborInt(index),
        data.cborValue,
        exUnits.cborValue,
      ]);
}

class BcExUnits {
  final BigInt mem;
  final BigInt steps;

  BcExUnits(this.mem, this.steps);

  CborValue get cborValue => CborList([
        CborInt(mem),
        CborInt(steps),
      ]);

  static BcExUnits fromCbor(CborValue value) {
    if (value is CborList &&
        value.length == 2 &&
        value[0] is CborInt &&
        value[1] is CborInt) {
      return BcExUnits(
          (value[0] as CborInt).toBigInt(), (value[1] as CborInt).toBigInt());
    } else {
      throw CborError(
          "BcExUnits.fromCbor expecting CborArray of two CborInt's, not $value");
    }
  }
}
