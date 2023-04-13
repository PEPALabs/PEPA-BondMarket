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
import type { RouterContractAbi, RouterContractAbiInterface } from "../RouterContractAbi";

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
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "__tuple_element",
          "type": 13,
          "typeArguments": null
        }
      ],
      "typeParameters": null
    },
    {
      "typeId": 2,
      "type": "b256",
      "components": null,
      "typeParameters": null
    },
    {
      "typeId": 3,
      "type": "enum Identity",
      "components": [
        {
          "name": "Address",
          "type": 8,
          "typeArguments": null
        },
        {
          "name": "ContractId",
          "type": 9,
          "typeArguments": null
        }
      ],
      "typeParameters": null
    },
    {
      "typeId": 4,
      "type": "generic T",
      "components": null,
      "typeParameters": null
    },
    {
      "typeId": 5,
      "type": "raw untyped ptr",
      "components": null,
      "typeParameters": null
    },
    {
      "typeId": 6,
      "type": "str[37]",
      "components": null,
      "typeParameters": null
    },
    {
      "typeId": 7,
      "type": "str[43]",
      "components": null,
      "typeParameters": null
    },
    {
      "typeId": 8,
      "type": "struct Address",
      "components": [
        {
          "name": "value",
          "type": 2,
          "typeArguments": null
        }
      ],
      "typeParameters": null
    },
    {
      "typeId": 9,
      "type": "struct ContractId",
      "components": [
        {
          "name": "value",
          "type": 2,
          "typeArguments": null
        }
      ],
      "typeParameters": null
    },
    {
      "typeId": 10,
      "type": "struct RawVec",
      "components": [
        {
          "name": "ptr",
          "type": 5,
          "typeArguments": null
        },
        {
          "name": "cap",
          "type": 13,
          "typeArguments": null
        }
      ],
      "typeParameters": [
        4
      ]
    },
    {
      "typeId": 11,
      "type": "struct SwapResult",
      "components": [
        {
          "name": "amount_0_out",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_1_out",
          "type": 13,
          "typeArguments": null
        }
      ],
      "typeParameters": null
    },
    {
      "typeId": 12,
      "type": "struct Vec",
      "components": [
        {
          "name": "buf",
          "type": 10,
          "typeArguments": [
            {
              "name": "",
              "type": 4,
              "typeArguments": null
            }
          ]
        },
        {
          "name": "len",
          "type": 13,
          "typeArguments": null
        }
      ],
      "typeParameters": [
        4
      ]
    },
    {
      "typeId": 13,
      "type": "u64",
      "components": null,
      "typeParameters": null
    }
  ],
  "functions": [
    {
      "inputs": [
        {
          "name": "swap_address",
          "type": 2,
          "typeArguments": null
        },
        {
          "name": "amount_0",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_1",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_0_min",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_1_min",
          "type": 13,
          "typeArguments": null
        }
      ],
      "name": "add_liquidity",
      "output": {
        "name": "",
        "type": 1,
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
          "name": "factory",
          "type": 2,
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
          "name": "swap_address",
          "type": 2,
          "typeArguments": null
        },
        {
          "name": "amount_lp",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_0",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_1",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_0_min",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_1_min",
          "type": 13,
          "typeArguments": null
        }
      ],
      "name": "remove_liquidity",
      "output": {
        "name": "",
        "type": 1,
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
          "name": "swap_address",
          "type": 2,
          "typeArguments": null
        },
        {
          "name": "asset_0",
          "type": 9,
          "typeArguments": null
        },
        {
          "name": "asset_1",
          "type": 9,
          "typeArguments": null
        },
        {
          "name": "asset_0_amount",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "asset_1_amount",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_out_min",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "to",
          "type": 3,
          "typeArguments": null
        }
      ],
      "name": "swap_exact_input_for_output",
      "output": {
        "name": "",
        "type": 11,
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
          "name": "swap_factory",
          "type": 2,
          "typeArguments": null
        },
        {
          "name": "path",
          "type": 12,
          "typeArguments": [
            {
              "name": "",
              "type": 2,
              "typeArguments": null
            }
          ]
        },
        {
          "name": "amount_in",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_out_min",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "to",
          "type": 3,
          "typeArguments": null
        }
      ],
      "name": "swap_exact_input_for_output_multihop",
      "output": {
        "name": "",
        "type": 11,
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
          "name": "swap_address",
          "type": 2,
          "typeArguments": null
        },
        {
          "name": "asset_0",
          "type": 9,
          "typeArguments": null
        },
        {
          "name": "asset_1",
          "type": 9,
          "typeArguments": null
        },
        {
          "name": "asset_0_amount",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "asset_1_amount",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_in_max",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_out",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "to",
          "type": 3,
          "typeArguments": null
        }
      ],
      "name": "swap_input_for_exact_output",
      "output": {
        "name": "",
        "type": 11,
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
          "name": "swap_factory",
          "type": 2,
          "typeArguments": null
        },
        {
          "name": "path",
          "type": 12,
          "typeArguments": [
            {
              "name": "",
              "type": 2,
              "typeArguments": null
            }
          ]
        },
        {
          "name": "amount_out",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "amount_in_max",
          "type": 13,
          "typeArguments": null
        },
        {
          "name": "to",
          "type": 3,
          "typeArguments": null
        }
      ],
      "name": "swap_input_for_exact_output_multihop",
      "output": {
        "name": "",
        "type": 11,
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
        "type": 6,
        "typeArguments": null
      }
    },
    {
      "logId": 1,
      "loggedType": {
        "name": "",
        "type": 7,
        "typeArguments": null
      }
    }
  ],
  "messagesTypes": [],
  "configurables": []
}

export class RouterContractAbi__factory {
  static readonly abi = _abi
  static createInterface(): RouterContractAbiInterface {
    return new Interface(_abi) as unknown as RouterContractAbiInterface
  }
  static connect(
    id: string | AbstractAddress,
    accountOrProvider: Account | Provider
  ): RouterContractAbi {
    return new Contract(id, _abi, accountOrProvider) as unknown as RouterContractAbi
  }
}