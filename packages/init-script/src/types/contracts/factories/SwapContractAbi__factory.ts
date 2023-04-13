/* Autogenerated file. Do not edit manually. */

/* tslint:disable */
/* eslint-disable */

/*
  Fuels version: 0.35.0
  Forc version: 0.35.3
  Fuel-Core version: 0.17.3
*/

import { Interface, Contract } from "fuels";
import type { Provider, Account, AbstractAddress } from "fuels";
import type { SwapContractAbi, SwapContractAbiInterface } from "../SwapContractAbi";

const _abi = {
  "types": [
    {
      "typeId": 0,
      "type": "()",
      "components": [],
      "typeParameters": null
    },
    {
      "typeId": 1,
      "type": "(_, _)",
      "components": [
        {
          "name": "__tuple_element",
          "type": 3,
          "typeArguments": null
        },
        {
          "name": "__tuple_element",
          "type": 3,
          "typeArguments": null
        }
      ],
      "typeParameters": null
    },
    {
      "typeId": 2,
      "type": "(_, _)",
      "components": [
        {
          "name": "__tuple_element",
          "type": 6,
          "typeArguments": null
        },
        {
          "name": "__tuple_element",
          "type": 6,
          "typeArguments": null
        }
      ],
      "typeParameters": null
    },
    {
      "typeId": 3,
      "type": "b256",
      "components": null,
      "typeParameters": null
    },
    {
      "typeId": 4,
      "type": "enum SwapError",
      "components": [
        {
          "name": "PlaceholderError",
          "type": 0,
          "typeArguments": null
        }
      ],
      "typeParameters": null
    },
    {
      "typeId": 5,
      "type": "struct ContractId",
      "components": [
        {
          "name": "value",
          "type": 3,
          "typeArguments": null
        }
      ],
      "typeParameters": null
    },
    {
      "typeId": 6,
      "type": "u64",
      "components": null,
      "typeParameters": null
    }
  ],
  "functions": [
    {
      "inputs": [],
      "name": "add_liquidity",
      "output": {
        "name": "",
        "type": 6,
        "typeArguments": null
      },
      "attributes": [
        {
          "name": "storage",
          "arguments": [
            "read",
            "write"
          ]
        }
      ]
    },
    {
      "inputs": [],
      "name": "deposit",
      "output": {
        "name": "",
        "type": 0,
        "typeArguments": null
      },
      "attributes": [
        {
          "name": "storage",
          "arguments": [
            "read"
          ]
        },
        {
          "name": "payable",
          "arguments": []
        }
      ]
    },
    {
      "inputs": [],
      "name": "get_pair",
      "output": {
        "name": "",
        "type": 1,
        "typeArguments": null
      },
      "attributes": [
        {
          "name": "storage",
          "arguments": [
            "read"
          ]
        }
      ]
    },
    {
      "inputs": [],
      "name": "get_reserve",
      "output": {
        "name": "",
        "type": 2,
        "typeArguments": null
      },
      "attributes": [
        {
          "name": "storage",
          "arguments": [
            "read"
          ]
        }
      ]
    },
    {
      "inputs": [
        {
          "name": "address_0",
          "type": 5,
          "typeArguments": null
        },
        {
          "name": "address_1",
          "type": 5,
          "typeArguments": null
        }
      ],
      "name": "initialize",
      "output": {
        "name": "",
        "type": 0,
        "typeArguments": null
      },
      "attributes": [
        {
          "name": "storage",
          "arguments": [
            "read",
            "write"
          ]
        }
      ]
    },
    {
      "inputs": [
        {
          "name": "amount_0",
          "type": 6,
          "typeArguments": null
        },
        {
          "name": "amount_1",
          "type": 6,
          "typeArguments": null
        }
      ],
      "name": "quote",
      "output": {
        "name": "",
        "type": 6,
        "typeArguments": null
      },
      "attributes": [
        {
          "name": "storage",
          "arguments": [
            "read"
          ]
        }
      ]
    },
    {
      "inputs": [],
      "name": "remove_liquidity",
      "output": {
        "name": "",
        "type": 2,
        "typeArguments": null
      },
      "attributes": [
        {
          "name": "storage",
          "arguments": [
            "read",
            "write"
          ]
        }
      ]
    },
    {
      "inputs": [],
      "name": "swap",
      "output": {
        "name": "",
        "type": 6,
        "typeArguments": null
      },
      "attributes": [
        {
          "name": "storage",
          "arguments": [
            "read",
            "write"
          ]
        }
      ]
    },
    {
      "inputs": [
        {
          "name": "amount",
          "type": 6,
          "typeArguments": null
        },
        {
          "name": "asset_id",
          "type": 5,
          "typeArguments": null
        }
      ],
      "name": "withdraw",
      "output": {
        "name": "",
        "type": 0,
        "typeArguments": null
      },
      "attributes": [
        {
          "name": "storage",
          "arguments": [
            "read",
            "write"
          ]
        }
      ]
    }
  ],
  "loggedTypes": [
    {
      "logId": 0,
      "loggedType": {
        "name": "",
        "type": 4,
        "typeArguments": []
      }
    },
    {
      "logId": 1,
      "loggedType": {
        "name": "",
        "type": 4,
        "typeArguments": []
      }
    },
    {
      "logId": 2,
      "loggedType": {
        "name": "",
        "type": 4,
        "typeArguments": []
      }
    }
  ],
  "messagesTypes": [],
  "configurables": []
}

export class SwapContractAbi__factory {
  static readonly abi = _abi
  static createInterface(): SwapContractAbiInterface {
    return new Interface(_abi) as unknown as SwapContractAbiInterface
  }
  static connect(
    id: string | AbstractAddress,
    accountOrProvider: Account | Provider
  ): SwapContractAbi {
    return new Contract(id, _abi, accountOrProvider) as unknown as SwapContractAbi
  }
}
