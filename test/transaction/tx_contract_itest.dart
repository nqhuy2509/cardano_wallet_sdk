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

const apiKeyFilePath = '../blockfrost_project_id.txt';

String _readApiKey() {
  final file = io.File(apiKeyFilePath).absolute;
  return file.readAsStringSync();
}

void main() {
  // Logger.root.level = Level.WARNING; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  final logger = Logger('BcPlutusDataTest');
  final network = Networks.testnet;
  final adapterFactory =
      BlockchainAdapterFactory.fromKey(key: _readApiKey(), network: network);
  final mnemonic =
      'company coast prison denial unknown design paper engage sadness employ phone cherry thunder chimney vapor cake lock afraid frequent myself engage lumber between tip'
          .split(' ');
  final HdAccount sender =
      HdMaster.mnemonic(mnemonic, network: network).account();

  group('Run Contracts -', () {
    test('alwaysSucceed', () {
      //https://github.com/input-output-hk/cardano-node/blob/28c34d813b8176afc653d6612d59fdd37dfeecfb/plutus-example/src/Cardano/PlutusExample/AlwaysSucceeds.hs#L1
      final collateralUtxoHash =
          'ab44e0f5faf56154cc33e757c9d98a60666346179d5a7a0b9d77734c23c42082';
      int collateralIndex = 0;
      final CollateralData collateral =
          _checkCollateral(sender, collateralUtxoHash, collateralIndex);

      final plutusScript = BcPlutusScript(
          description: 'Allways Succeed',
          type: BcScriptType.plutusV1,
          cborHex: '4e4d01000033222220051200120011');

      final scriptAmt = BigInt.from(2479280);
      final scriptAddress = ShelleyAddress.enterpriseScriptAddress(
          script: plutusScript, network: network);

      final plutusData = BcBigIntPlutusData.fromInt(994299); //any random number
      final redeemerData =
          BcBigIntPlutusData.fromInt(4544); //any number doesn't matter
      final datumHash = plutusData.hashHex;

      //Transfer fund to script address
      bool paymentSuccessful = transferToContractAddress(sender, scriptAddress,
          scriptAmt, datumHash, collateral, collateralIndex);
      expect(paymentSuccessful, isTrue,
          reason: "send $scriptAmt to $scriptAddress");

      //Start contract transaction to claim fund
      CoinSelectionAlgorithm coinSelectFunction = largestFirst;
      UtxoSelectionStrategy utxoSelectionStrategy =
          DefaultUtxoSelectionStrategyImpl(utxoSupplier);
      utxoSelectionStrategy.setIgnoreUtxosWithDatumHash(false);
      List<Utxo> utxos = utxoSelectionStrategy.selectUtxos(scriptAddress,
          LOVELACE, BigInteger.valueOf(1), datumHash, Collections.EMPTY_SET);

      assertTrue(utxos.size() != 0,
          "No script utxo found for datumhash : " + datumHash);
      Utxo inputUtxo = utxos.get(0);

/*
        Tuple<String, Integer> collateralTuple = checkCollateral(sender, collateral, collateralIndex);
        if (collateralTuple == null) {
            System.out.println("Collateral cannot be found or created. " + collateral);
            return;
        }

        collateral = collateralTuple._1;
        collateralIndex = collateralTuple._2;

        final scriptAmt = BigInt.from(2479280);
        final scriptAddress = ShelleyAddress.enterpriseScriptAddress(script: plutusScript, network: Networks.testnet,);
        

        Random rand = new Random();
        int randInt = rand.nextInt();
        PlutusData plutusData = new BigIntPlutusData(BigInteger.valueOf(randInt)); //any random number
        PlutusData redeemerData = new BigIntPlutusData(BigInteger.valueOf(4544)); //any number doesn't matter
        String datumHash = plutusData.getDatumHash();

        //Transfer fund to script address
        boolean paymentSuccessful = transferToContractAddress(sender, scriptAddress, scriptAmt, datumHash, collateral, collateralIndex);
        assertTrue(paymentSuccessful);

        //Start contract transaction to claim fund
        UtxoSelectionStrategy utxoSelectionStrategy = new DefaultUtxoSelectionStrategyImpl(utxoSupplier);
        utxoSelectionStrategy.setIgnoreUtxosWithDatumHash(false);
        List<Utxo> utxos = utxoSelectionStrategy.selectUtxos(scriptAddress, LOVELACE, BigInteger.valueOf(1), datumHash, Collections.EMPTY_SET);

        assertTrue(utxos.size() != 0, "No script utxo found for datumhash : " + datumHash);
        Utxo inputUtxo = utxos.get(0);

        //Find utxos first and then create inputs
        List<TransactionInput> inputs = Arrays.asList(
                TransactionInput.builder()
                        .transactionId(inputUtxo.getTxHash())
                        .index(inputUtxo.getOutputIndex()).build()
        );

        TransactionInput collateralInput = TransactionInput.builder()
                .transactionId(collateral)
                .index(collateralIndex).build();

        TransactionOutput change = TransactionOutput
                .builder()
                .address(sender.baseAddress())
                .value(new Value(scriptAmt, null)) //Actual amount will be set after fee estimation
                .build();

        List<TransactionOutput> outputs = Arrays.asList(change);

        //Create the transaction body with dummy fee
        TransactionBody body = TransactionBody.builder()
                .inputs(inputs)
                .outputs(outputs)
                .collateral(Arrays.asList(collateralInput))
                .fee(BigInteger.valueOf(170000)) //Dummy fee
                .ttl(getTtl())
                .networkId(NetworkId.TESTNET)
                .build();

        Redeemer redeemer = Redeemer.builder()
                .tag(RedeemerTag.Spend)
                .data(redeemerData)
                .index(BigInteger.valueOf(0))
                .exUnits(ExUnits.builder()
                        .mem(BigInteger.valueOf(1700))
                        .steps(BigInteger.valueOf(476468)).build()
                ).build();

        TransactionWitnessSet transactionWitnessSet = new TransactionWitnessSet();
        transactionWitnessSet.setPlutusV1Scripts(Arrays.asList(plutusScript));
        transactionWitnessSet.setPlutusDataList(Arrays.asList(plutusData));
        transactionWitnessSet.setRedeemers(Arrays.asList(redeemer));

        byte[] scriptDataHash = ScriptDataHashGenerator.generate(Arrays.asList(redeemer),
                Arrays.asList(plutusData), CostModelUtil.getLanguageViewsEncoding(PlutusV1CostModel));
        body.setScriptDataHash(scriptDataHash);

        CBORMetadata cborMetadata = new CBORMetadata();
        CBORMetadataMap metadataMap = new CBORMetadataMap();
        CBORMetadataList metadataList = new CBORMetadataList();
        metadataList.add("Contract call");
        metadataMap.put("msg", metadataList);
        cborMetadata.put(new BigInteger("674"), metadataMap);

        AuxiliaryData auxiliaryData = AuxiliaryData.builder()
                .metadata(cborMetadata)
                .plutusV1Scripts(Arrays.asList(plutusScript))
                .build();

        Transaction transaction = Transaction.builder()
                .body(body)
                .witnessSet(transactionWitnessSet)
                .auxiliaryData(auxiliaryData)
                .build();

        System.out.println(transaction);
        Transaction signTxnForFeeCalculation = sender.sign(transaction);

        BigInteger baseFee = feeCalculationService.calculateFee(signTxnForFeeCalculation);
        BigInteger scriptFee = feeCalculationService.calculateScriptFee(Arrays.asList(redeemer.getExUnits()));
        BigInteger totalFee = baseFee.add(scriptFee);

        System.out.println("Total Fee ----- " + totalFee);

        //Update change amount based on fee
        BigInteger changeAmt = scriptAmt.subtract(totalFee);
        change.getValue().setCoin(changeAmt);
        body.setFee(totalFee);

        System.out.println("-- fee : " + totalFee);

        Transaction signTxn = sender.sign(transaction); //cbor encoded bytes in Hex format
        System.out.println(signTxn);

        Result<String> result = transactionService.submitTransaction(signTxn.serialize());
        System.out.println(result);
        assertTrue(result.isSuccessful());
        waitForTransaction(result);
    */

      // expect(cbor4.cborValue, map1);
    });
  });
}

bool transferToContractAddress(
  HdAccount sender,
  ShelleyAddress scriptAddress,
  BigInt amount,
  String datumHash,
  String collateralTxHash,
  int collateralIndex,
) {
  return true;
/*
                Utxo collateralUtxo = Utxo.builder()
                                .txHash(collateralTxHash)
                                .outputIndex(collateralIndex)
                                .build();
                Set ignoreUtxos = new HashSet();
                ignoreUtxos.add(collateralUtxo);

                UtxoSelectionStrategy utxoSelectionStrategy = new DefaultUtxoSelectionStrategyImpl(utxoSupplier);
                List<Utxo> utxos = utxoSelectionStrategy.selectUtxos(sender.baseAddress(), LOVELACE, amount,
                                ignoreUtxos);

                PaymentTransaction paymentTransaction = PaymentTransaction.builder()
                                .sender(sender)
                                .receiver(scriptAddress)
                                .amount(amount)
                                .unit("lovelace")
                                .datumHash(datumHash)
                                .utxosToInclude(utxos)
                                .build();

                BigInteger fee = feeCalculationService.calculateFee(paymentTransaction,
                                TransactionDetailsParams.builder().ttl(getTtl()).build(), null);
                paymentTransaction.setFee(fee);

                Result<TransactionResult> result = transactionHelperService.transfer(paymentTransaction,
                                TransactionDetailsParams.builder().ttl(getTtl()).build());
                if (result.isSuccessful())
                        System.out.println("Transaction Id: " + result.getValue());
                else
                        System.out.println("Transaction failed: " + result);

                if (result.isSuccessful()) {
                        Result<String> resultWithTxId = Result.success(result.getResponse()).code(result.code())
                                        .withValue(result.getValue().getTransactionId());

                        waitForTransaction(resultWithTxId);
                } else {
                        System.out.println(result);
                }

                return result.isSuccessful();
                */
}

class CollateralData {
  final String collateralUtxoHash;
  final int collateralIndex;
}

CollateralData _checkCollateral(
  HdAccount sender,
  final String collateralUtxoHash,
  final int collateralIndex,
) {
  return CollateralData(collateralUtxoHash, collateralIndex);
}
/*
private Tuple<String, Integer> checkCollateral(Account sender, final String collateralUtxoHash,
                        final int collateralIndex) throws ApiException, AddressExcepion, CborSerializationException {
                List<Utxo> utxos = utxoService.getUtxos(sender.baseAddress(), 100, 1).getValue(); // Check 1st page 100
                                                                                                  // utxos
                Optional<Utxo> collateralUtxoOption = utxos.stream()
                                .filter(utxo -> utxo.getTxHash().equals(collateralUtxoHash))
                                .findAny();

                if (collateralUtxoOption.isPresent()) {// Collateral present
                        System.out.println("--- Collateral utxo still there");
                        return new Tuple(collateralUtxoHash, collateralIndex);
                } else {

                        Utxo randomCollateral = getRandomUtxoForCollateral(sender.baseAddress());
                        if (randomCollateral != null) {
                                System.out.println("Found random collateral ---");
                                return new Tuple<>(randomCollateral.getTxHash(), randomCollateral.getOutputIndex());
                        } else {
                                System.out.println("*** Collateral utxo not found");

                                // Transfer to self to create collateral utxo
                                BigInteger collateralAmt = BigInteger.valueOf(8000000L);
                                transferFund(sender, sender.baseAddress(), collateralAmt, null, null, null);

                                // Find collateral utxo again
                                utxos = utxoService.getUtxos(sender.baseAddress(), 100, 1).getValue();
                                collateralUtxoOption = utxos.stream().filter(utxo -> {
                                        if (utxo.getAmount().size() == 1 // Assumption: 1 Amount means, only LOVELACE
                                                        && LOVELACE.equals(utxo.getAmount().get(0).getUnit())
                                                        && collateralAmt.equals(utxo.getAmount().get(0).getQuantity()))
                                                return true;
                                        else
                                                return false;
                                }).findFirst();

                                if (!collateralUtxoOption.isPresent()) {
                                        System.out.println("Collateral cannot be created");
                                        return null;
                                }

                                Utxo collateral = collateralUtxoOption.get();
                                String colUtxoHash = collateral.getTxHash();
                                int colIndex = collateral.getOutputIndex();

                                return new Tuple(colUtxoHash, colIndex);
                        }
                }
        }
        */
