import type { BigNumberish } from 'fuels';
import { bn } from 'fuels';

import type { OwnerWalletContractAbi } from '../../src/types/contracts';

const { MINT_AMOUNT } = process.env;

export async function initializeOwnerWalletContract(
  ownerWalletContract: OwnerWalletContractAbi,
  overrides: any
) {
  // const mintAmount = bn(MINT_AMOUNT || '0x1D1A94A2000');
  // // console.log(tokenContract.wallet!.address.toB256());
  // const address = {
  //   value: tokenContract.account!.address.toB256(),
  // };

  process.stdout.write('Initialize Owner Wallet\n');
  // await tokenContract.functions.initialize(mintAmount, address).txParams(overrides).call();
  process.stdout.write('Owner Wallet successfully initialized\n');
  
}
