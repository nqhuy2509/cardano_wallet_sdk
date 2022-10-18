// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';
import 'package:oxidized/oxidized.dart';
import '../network/network_id.dart';
import '../transaction/min_fee_function.dart';
import '../transaction/transaction.dart';
import '../wallet/impl/wallet_update.dart';
import '../address/shelley_address.dart';
import './blockchain_cache.dart';

///
/// High-level abstraction to blockchain tailored towards balences and transactions.
///
abstract class BlockchainAdapter extends BlockchainCache {
  /// Collects the latest transactions for the wallet given it's staking address.
  Future<Result<WalletUpdate, String>> updateWallet({
    required ShelleyAddress stakeAddress,
    CancelAction? cancelAction,
    TemperalSortOrder sortOrder = TemperalSortOrder.descending,
  });

  /// Returns last latest Block instance from blockchain if successful.
  Future<Result<Block, String>> latestBlock({CancelAction? cancelAction});

  /// Submit ShelleyTransaction encoded as CBOR. Returns hex transaction ID if successful.
  Future<Result<String, String>> submitTransaction(
      {required Uint8List cborTransaction, CancelAction? cancelAction});

  /// Return the fee parameters for the given epoch number or the latest epoch if no number supplied.
  Future<Result<LinearFee, String>> latestEpochParameters(
      {int epochNumber = 0, CancelAction? cancelAction});
  Networks get network;

  /// Return an implementation-specific instance of CancelAction.
  CancelAction cancelActionInstance();
}

/// You can cancel a request by using a cancel token.
/// One token can be shared with different requests.
/// when a token's [cancel] method invoked, all requests
/// with this token will be cancelled.
abstract class CancelAction {
  /// If request have been canceled, save the cancel Error.
  Exception? get cancelError;

  /// whether cancelled
  bool get isCancelled => cancelError != null;

  /// When cancelled, this future will be resolved.
  Future<Exception> get whenCancel;

  /// Cancel the request
  void cancel([dynamic reason]);
}
