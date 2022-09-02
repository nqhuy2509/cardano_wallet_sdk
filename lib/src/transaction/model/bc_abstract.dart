// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';
import 'package:hex/hex.dart';
import 'package:cbor/cbor.dart';
import '../../util/blake2bhash.dart';

///
/// Base class for mapping binary data structures used on the Cardano blockchain.
///
/// Subclasses should minimally implement a cborValue getter and a fromCbor factory memthod.
/// Polymorphic subclasses should implement an abstract base class (see BcNativeScript for an
/// example) to build the hierarchy.
///
abstract class BcAbstractCbor {
  CborValue get cborValue;
  Uint8List get serialize => _toUint8List(cborValue);
  String get cborJson => _toCborJson(cborValue);
  String get hex => HEX.encode(serialize);
  Uint8List get hash => Uint8List.fromList(blake2bHash256(serialize));
  String get hashHex => HEX.encode(hash);

  @override
  String toString() => hex;

  @override
  int get hashCode => hex.hashCode;

  /// does a byte-by-byte comparison of the serialized representations.
  @override
  bool operator ==(Object other) {
    bool isEq = identical(this, other) ||
        other is BcAbstractCbor && runtimeType == other.runtimeType;
    if (!isEq) return false;
    final Uint8List bytes1 = serialize;
    final Uint8List bytes2 = (other as BcAbstractCbor).serialize;
    return _equalBytes(bytes1, bytes2);
  }

  bool _equalBytes(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Uint8List _toUint8List(CborValue value) =>
      Uint8List.fromList(cbor.encode(value));

  String _toCborJson(CborValue value) => const CborJsonEncoder().convert(value);
}

class CborError extends Error {
  final String message;
  CborError(this.message);
  @override
  String toString() => message;
}
