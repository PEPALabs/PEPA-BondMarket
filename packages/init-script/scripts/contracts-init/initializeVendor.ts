import type { BigNumberish } from 'fuels';
import { bn, NativeAssetId } from 'fuels';
import {Contract} from 'fuels';

import type { FloorContractAbi, SellerContractAbi, VendorContractAbi } from '../../src/types/contracts';

// const { TOKEN_AMOUNT, ETH_AMOUNT } = process.env;
export async function initializeVendor(
  floorContract: FloorContractAbi,
  sellerContract: SellerContractAbi,
  vendorContract: VendorContractAbi,
  overrides: { gasPrice: BigNumberish }
) {
  const seller_ = vendorContract.seller_;
  const floor_ = vendorContract.floor_;
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

  process.stdout.write('Initialize Vendor\n');
  const deadline = await account.provider.getBlockNumber();
  await vendorContract
    .multiCall([
      // use custom struct support wrapping parameters
      vendorContract.functions.initialize(seller_, floor_),
    ])
    .txParams({
      ...overrides,
      variableOutputs: 2,
      gasLimit: 100_000_000,
    })
    .addContracts([vendorContract as Contract])
    .call();
}
