import type { BigNumberish } from 'fuels';
import { bn, NativeAssetId } from 'fuels';
import {Contract} from 'fuels';

import type { FloorContractAbi, SellerContractAbi, VendorContractAbi } from '../../src/types/contracts';

// const { TOKEN_AMOUNT, ETH_AMOUNT } = process.env;
export async function initializeSeller(
  floorContract: FloorContractAbi,
  sellerContract: SellerContractAbi,
  vendorContract: VendorContractAbi,
  overrides: { gasPrice: BigNumberish }
) {
  const protocol_ = sellerContract.protocol_;
  const aggregator_ = sellerContract.aggregator_;
  const guardian_ = sellerContract.guardian_;
  const authority_ = sellerContract.authority_;
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

  process.stdout.write('Initialize Seller\n');
  const deadline = await account.provider.getBlockNumber();
  await sellerContract
    .multiCall([
      // use custom struct support wrapping parameters
      sellerContract.functions.initialize(protocol_, aggregator_, guardian_, authority_),
    ])
    .txParams({
      ...overrides,
      variableOutputs: 2,
      gasLimit: 100_000_000,
    })
    .addContracts([sellerContract as Contract])
    .call();
}
