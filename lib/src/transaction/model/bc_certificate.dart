// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:bip32_ed25519/bip32_ed25519.dart';
import 'package:cbor/cbor.dart';
import '../../util/blake2bhash.dart';
import '../../util/codec.dart';
import '../../util/list_ext.dart';
import './bc_abstract.dart';
import './bc_scripts.dart';

enum BcCertificateType {
  stakeRegistration,
  stakeDeregistration,
  stakeDelegation,
  poolRegistration,
  poolRetirement,
  genesisKeyDelegation,
  moveInstatenousRewqrdsCert;
}

abstract class BcCertificate extends BcAbstractCbor {
  BcCertificateType get type;
  static BcCertificate fromCbor({required CborList list}) {
    final n = (list[0] as CborSmallInt).toInt();
    switch (n) {
      case 0: //BcCertificateType.stakeRegistration
        return BcStakeRegistration.fromCbor(list: list);
      case 1: //BcCertificateType.stakeDeregistration
        return BcStakeDeregistration.fromCbor(list: list);
      case 2: //BcCertificateType.stakeDelegation
        return BcStakeDelegation.fromCbor(list: list);
      case 3: //BcCertificateType.poolRegistration
        throw CborError("pool registration not supported yet");
      case 4: //BcCertificateType.poolRetirement
        throw CborError("pool retirement not supported yet");
      case 5: //BcCertificateType.genesisKeyDelegation
        throw CborError("genesis key delegation not supported yet");
      case 6: //BcCertificateType.moveInstatenousRewqrdsCert
        throw CborError("move instatenous rewqrds cert not supported yet");
      default:
        throw CborError(
            "CBOR parsing error: BcCertificateType out of range[0..6]: $n");
    }
  }
}

class BcStakeRegistration extends BcCertificate {
  @override
  BcCertificateType get type => BcCertificateType.stakeRegistration;
  final BcStakeCredential credential;

  BcStakeRegistration({required this.credential});

  factory BcStakeRegistration.fromCbor({required CborList list}) {
    final cred = BcStakeCredential.fromCbor(list: list[1] as CborList);
    return BcStakeRegistration(credential: cred);
  }

  @override
  CborValue get cborValue => toCborList();
  CborList toCborList() =>
      CborList([CborSmallInt(type.index), credential.cborValue]);
}

class BcStakeDeregistration extends BcStakeRegistration {
  @override
  BcCertificateType get type => BcCertificateType.stakeDeregistration;
  BcStakeDeregistration({required super.credential});
  factory BcStakeDeregistration.fromCbor({required CborList list}) {
    final cred = BcStakeCredential.fromCbor(list: list[1] as CborList);
    return BcStakeDeregistration(credential: cred);
  }
}

class BcStakeDelegation extends BcStakeRegistration {
  @override
  BcCertificateType get type => BcCertificateType.stakeDelegation;

  /// Bech32 pool ID that owns the account (i.e. pool14pdhhugxlqp9vta49pyfu5e2d5s82zmtukcy9x5ylukpkekqk8l)
  final String poolId;

  BcStakeDelegation({required super.credential, required this.poolId});

  factory BcStakeDelegation.fromCbor({required CborList list}) {
    if (list.length != 3) {
      throw CborError(
          "StakeDelegation CBOR deserialization error: expecting list of size 3, not ${list.length}");
    }
    final cred = BcStakeCredential.fromCbor(list: list[1] as CborList);
    final poolId = bech32FromStakePoolBytes((list[2] as CborBytes).bytes);
    return BcStakeDelegation(credential: cred, poolId: poolId);
  }

  @override
  CborList toCborList() => CborList([
        CborSmallInt(type.index),
        credential.cborValue,
        CborBytes(stakePoolBytesFromBech32(poolId))
      ]);
}

enum StakeCredType {
  addrKeyhash,
  scriptHash;
}

class BcStakeCredential extends BcAbstractCbor {
  final StakeCredType type;
  final Uint8List credentialHash;

  BcStakeCredential({required this.type, required this.credentialHash});

  factory BcStakeCredential.fromKeyBytes({required Uint8List verifyKeyBytes}) {
    final credentialHash = Uint8List.fromList(blake2bHash224(verifyKeyBytes));
    return BcStakeCredential(
        type: StakeCredType.addrKeyhash, credentialHash: credentialHash);
  }

  factory BcStakeCredential.fromKey({required VerifyKey verifyKey}) =>
      BcStakeCredential.fromKeyBytes(verifyKeyBytes: verifyKey.asUint8List());

  factory BcStakeCredential.fromKeyHash({required Uint8List keyHash}) =>
      BcStakeCredential(
          type: StakeCredType.addrKeyhash, credentialHash: keyHash);

  factory BcStakeCredential.fromScriptHash({required Uint8List scriptHash}) =>
      BcStakeCredential(
          type: StakeCredType.scriptHash, credentialHash: scriptHash);

  factory BcStakeCredential.fromScript({required BcAbstractScript script}) =>
      BcStakeCredential(
          type: StakeCredType.scriptHash, credentialHash: script.scriptHash);

  factory BcStakeCredential.fromCbor({required CborList list}) {
    final n = (list[0] as CborSmallInt).toInt();
    final type = StakeCredType.values[n];
    final credentialHash = Uint8List.fromList((list[1] as CborBytes).bytes);
    return BcStakeCredential(type: type, credentialHash: credentialHash);
  }

  @override
  CborValue get cborValue => toCborList();

  CborList toCborList() =>
      CborList([CborSmallInt(type.index), CborBytes(credentialHash.toList())]);
}
