import { NativeAssetId,
         Provider,
         Account,
         Wallet, 
         WalletUnlocked } from 'fuels';

require('dotenv').config();

export async function getWalletInstance() {
  // Avoid early load of process env
  const { WALLET_SECRET, GENESIS_SECRET, PROVIDER_URL } = process.env;
  if (WALLET_SECRET) {
    const provider = new Provider(PROVIDER_URL!);
    const wallet: WalletUnlocked = Wallet.fromPrivateKey(WALLET_SECRET, provider);
    return wallet;

  }

  throw new Error('You must provide a WALLET_SECRET');
}

export async function getAccountInstance() {
  const { WALLET_SECRET, GENESIS_SECRET, PROVIDER_URL } = process.env;
  if (WALLET_SECRET) {
    const provider = new Provider(PROVIDER_URL!);
    const account: Account= new Account(WALLET_SECRET, provider);
    return account;

  }

  throw new Error('You must provide a WALLET_SECRET');
}

