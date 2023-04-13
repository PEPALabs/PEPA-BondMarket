import dotenv from 'dotenv';
import { createConfig, replaceEventOnEnv } from 'pepaswap-scripts';

const { NODE_ENV, OUTPUT_ENV } = process.env;

function getEnvName() {
  return NODE_ENV === 'test' ? '.env.test' : '.env';
}

dotenv.config({
  path: `./docker/${getEnvName()}`,
});

const getDeployOptions = () => ({
  gasPrice: Number(process.env.GAS_PRICE || 0),
});

// building types and contracts
export default createConfig({
  types: {
    artifacts: './contracts/**/out/debug/**-abi.json',
    output: './packages/init-script/src/types/contracts',
  },
  contracts: [
    {
      name: 'VITE_SELLER_ID',
      path: './contracts/seller_contract',
      options: getDeployOptions(),
    },
    {
      name: 'VITE_FLOOR_ID',
      path: './contracts/floor_contract',
      options: getDeployOptions(),
    },
    {
      name: 'VITE_VENDOR_ID',
      path: './contracts/vendor_contract',
      options: getDeployOptions(),
    },
  ],
  onSuccess: (event) => {
    replaceEventOnEnv(`./packages/init-script/${OUTPUT_ENV || getEnvName()}`, event);
  },
});
