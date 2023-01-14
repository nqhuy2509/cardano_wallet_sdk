// Copyright 2021 Richard Easterling
// SPDX-License-Identifier: Apache-2.0

import 'package:cardano_wallet_sdk/cardano_wallet_sdk.dart';
import 'package:logging/logging.dart';
import 'package:cbor/cbor.dart';

class FeeCalculationService {
  final logger = Logger('FeeCalculationService');
  final ProtocolParameters protocolParameters;

  FeeCalculationService(this.protocolParameters);

  ///
  /// calculate transaction fee based on transaction length and minimum constants
  ///
  BigInt calculateMinFee({required BcTransaction transaction}) {
    return calculateMinFeeFromBytes(cbor.encode(transaction.toCborList()));
  }

  ///
  /// calculate transaction fee based on bytes length and minimum constants
  ///
  BigInt calculateMinFeeFromBytes(List<int> bytes) {
    final result = BigInt.from(
        protocolParameters.minFeeA * bytes.length + protocolParameters.minFeeB);
    logger.info(
        "calculateMinFeeFromBytes(minFeeA * tx.len + minFeeB) = ${protocolParameters.minFeeA} * ${bytes.length} + ${protocolParameters.minFeeB} = $result");
    return result;
  }

  ///
  /// Calculate fee needed to submit script.
  /// TODO uses double because Dart doesn't support BigDecimal, use 3rd party lib?
  ///
  BigInt calculateScriptFee(List<BcExUnits> exUnitsList) {
    num priceMem = protocolParameters.priceMem ?? 0.0;
    num priceSteps = protocolParameters.priceStep ?? 0.0;
    double scriptFee = 0.0;
    String? log = logger.isLoggable(Level.INFO) ? "" : null;
    for (BcExUnits exUnits in exUnitsList) {
      double memCost = priceMem * exUnits.mem.toDouble();
      double stepCost = priceSteps * exUnits.steps.toDouble();
      scriptFee = scriptFee + memCost + stepCost;
      if (log != null) {
        log = "($memCost + $stepCost),$log";
      }
    }
    //round
    final result = BigInt.from(scriptFee.ceil().toInt());
    logger.info(
        "calculateScriptFee ∑ ExUnits(memCost + stepCost) = $log = $result");
    return result;
  }
}
