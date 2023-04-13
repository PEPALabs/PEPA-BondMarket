/* Autogenerated file. Do not edit manually. */

/* tslint:disable */
/* eslint-disable */

/*
  Fuels version: 0.35.0
  Forc version: 0.35.3
  Fuel-Core version: 0.17.3
*/

import type {
  BigNumberish,
  BN,
  BytesLike,
  Contract,
  DecodedValue,
  FunctionFragment,
  Interface,
  InvokeFunction,
} from 'fuels';

import type { Enum } from "./common";

export type SwapErrorInput = Enum<{ PlaceholderError: [] }>;
export type SwapErrorOutput = SwapErrorInput;

export type ContractIdInput = { value: string };
export type ContractIdOutput = ContractIdInput;

interface SwapContractAbiInterface extends Interface {
  functions: {
    add_liquidity: FunctionFragment;
    deposit: FunctionFragment;
    get_pair: FunctionFragment;
    get_reserve: FunctionFragment;
    initialize: FunctionFragment;
    quote: FunctionFragment;
    remove_liquidity: FunctionFragment;
    swap: FunctionFragment;
    withdraw: FunctionFragment;
  };

  encodeFunctionData(functionFragment: 'add_liquidity', values: []): Uint8Array;
  encodeFunctionData(functionFragment: 'deposit', values: []): Uint8Array;
  encodeFunctionData(functionFragment: 'get_pair', values: []): Uint8Array;
  encodeFunctionData(functionFragment: 'get_reserve', values: []): Uint8Array;
  encodeFunctionData(functionFragment: 'initialize', values: [ContractIdInput, ContractIdInput]): Uint8Array;
  encodeFunctionData(functionFragment: 'quote', values: [BigNumberish, BigNumberish]): Uint8Array;
  encodeFunctionData(functionFragment: 'remove_liquidity', values: []): Uint8Array;
  encodeFunctionData(functionFragment: 'swap', values: []): Uint8Array;
  encodeFunctionData(functionFragment: 'withdraw', values: [BigNumberish, ContractIdInput]): Uint8Array;

  decodeFunctionData(functionFragment: 'add_liquidity', data: BytesLike): DecodedValue;
  decodeFunctionData(functionFragment: 'deposit', data: BytesLike): DecodedValue;
  decodeFunctionData(functionFragment: 'get_pair', data: BytesLike): DecodedValue;
  decodeFunctionData(functionFragment: 'get_reserve', data: BytesLike): DecodedValue;
  decodeFunctionData(functionFragment: 'initialize', data: BytesLike): DecodedValue;
  decodeFunctionData(functionFragment: 'quote', data: BytesLike): DecodedValue;
  decodeFunctionData(functionFragment: 'remove_liquidity', data: BytesLike): DecodedValue;
  decodeFunctionData(functionFragment: 'swap', data: BytesLike): DecodedValue;
  decodeFunctionData(functionFragment: 'withdraw', data: BytesLike): DecodedValue;
}

export class SwapContractAbi extends Contract {
  interface: SwapContractAbiInterface;
  functions: {
    add_liquidity: InvokeFunction<[], BN>;
    deposit: InvokeFunction<[], void>;
    get_pair: InvokeFunction<[], [string, string]>;
    get_reserve: InvokeFunction<[], [BN, BN]>;
    initialize: InvokeFunction<[address_0: ContractIdInput, address_1: ContractIdInput], void>;
    quote: InvokeFunction<[amount_0: BigNumberish, amount_1: BigNumberish], BN>;
    remove_liquidity: InvokeFunction<[], [BN, BN]>;
    swap: InvokeFunction<[], BN>;
    withdraw: InvokeFunction<[amount: BigNumberish, asset_id: ContractIdInput], void>;
  };
}
