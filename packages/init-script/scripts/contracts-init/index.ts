import { bn, WalletUnlocked } from 'fuels';

import '../../load.envs';
// import './loadDockerEnv';
import { FloorContractAbi__factory, SellerContractAbi__factory, VendorContractAbi__factory, OwnerWalletContractAbi__factory } from '../../src/types/contracts';

import { initializeFloor } from './initializeFloor';
import { initializeSeller } from './initializeSeller';
import { initializeVendor } from './initializeVendor';
import { initializeOwnerWallet } from './initializeOwnerWallet';
import { getWalletInstance, getAccountInstance } from './getWalletInstance';

const { WALLET_SECRET, PROVIDER_URL, GAS_PRICE, VITE_CONTRACT_ID, VITE_TOKEN_ID, VITE_ROUTER_ID, VITE_FACTORY_ID } = process.env;

if (!WALLET_SECRET) {
  process.stdout.write('WALLET_SECRET is not detected!\n');
  process.exit(1);
}

if (!VITE_CONTRACT_ID || !VITE_TOKEN_ID) {
  process.stdout.write('CONTRACT_ID or TOKEN_ID is not detected!\n');
  process.exit(1);
}
console.log(WALLET_SECRET);

async function main() {
  const wallet = await getWalletInstance();
  const account = await getAccountInstance();
  const floorContract = FloorContractAbi__factory.connect(VITE_TOKEN_ID!, wallet);
  const sellerContract = SellerContractAbi__factory.connect(VITE_CONTRACT_ID!, wallet);
  const vendorContract = VendorContractAbi__factory.connect(VITE_FACTORY_ID!, wallet);
  const ownerWalletContract = OwnerWalletContractAbi__factory.connect(VITE_ROUTER_ID!, wallet);
  // exchangeContract.account = account;
  const overrides = {
    gasPrice: bn(GAS_PRICE || 0),
  };

  console.log("Initialization start");

  await initializeFloor(floorContract, overrides);
  await initializeSeller(floorContract, sellerContract, overrides);
  await initializeVendor(floorContract, vendorContract, overrides);
  await initializeOwnerWallet(floorContract, sellerContract, vendorContract, ownerWalletContract, overrides);

  console.log("Initialization complete");
}

main();
