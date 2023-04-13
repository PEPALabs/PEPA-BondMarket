import type { BigNumberish } from 'fuels';
import { bn, NativeAssetId } from 'fuels';
import {Contract} from 'fuels';

import type { FloorContractAbi, SellerContractAbi, VendorContractAbi } from '../../src/types/contracts';

//  { TOKEN_AMOUNT, ETH_AMOUNT } = process.env;
export async function initializeFloor(
  floorContract: FloorContractAbi,
  sellerContract: SellerContractAbi,
  vendorContract: VendorContractAbi,
  overrides: { gasPrice: BigNumberish }
) {
  const template_root = floorContract.template_root;
  const owner = floorContract.owner;
  // const account = floorContract.account!;
  // const tokenAmountMint = bn(TOKEN_AMOUNT || '0x44360000');
  // const tokenAmount = bn(TOKEN_AMOUNT || '0x40000');
  // const ethAmount = bn(ETH_AMOUNT || '0xAAAA00');
  // const address = {
  //   value: account.address.toB256(),
  // };
  // clean up after initialization to avoid unassigned id
  // const tokenId = {
  //   value: tokenContract.id.toB256(),
  // };
  // const NativeAsset = {
  //   value: NativeAssetId,
  // }

  process.stdout.write('Initialize Floor\n');
  const deadline = await account.provider.getBlockNumber();
  await floorContract
    .multiCall([
      // use custom struct support wrapping parameters
      floorContract.functions.initialize(template_root, owner),
    ])
    .txParams({
      ...overrides,
      variableOutputs: 2,
      gasLimit: 100_000_000,
    })
    .addContracts([floorContract as Contract])
    .call();
}
