# DeployHelper Forge Package

A reusable Foundry deployment helper that provides deterministic CREATE3 deployments with automatic JSON tracking and verification file generation.

## Features

- **Deterministic Deployments**: Uses CREATE3 for consistent addresses across chains
- **Automatic Tracking**: Saves deployment info and verification JSONs
- **Version Management**: Built-in support for `x.x.x-ContractName` versioning
- **Production Safety**: Automatic owner management for mainnet deployments
- **Environment Configuration**: Read deployment settings from .env file
- **Deployment Verification**: Pre-deployment checks to prevent accidental deployments with changed code
- **Force Deploy Option**: Override verification checks when needed during development
- **Modular Design**: Easy to integrate into any Foundry project

## Installation

Add to your Foundry project:

```bash
forge install EthSign/deploy-helper
```

Add to your `remappings.txt`:
```
deploy-helper/=lib/deploy-helper/script/
```

Ensure your `foundry.toml` includes the required permissions:

```toml
fs_permissions = [
    { access = "read-write", path = "./deployments" },
    { access = "read", path = "./" }
]
ffi = true
```

## Quick Start

### 1. Configuration

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PROD_OWNER` | Address to receive ownership on mainnet deployments | `0x1234...` |
| `MAINNET_CHAIN_IDS` | Comma-separated list of production chain IDs | `1,56,137,42161` |
| `FORCE_DEPLOY` | Override verification checks (use with caution) | `false` |

### Deployment Verification

DeployHelper performs pre-deployment verification to ensure contract code hasn't changed unexpectedly:

1. **Normal flow**: If the contract code changes, deployment will be aborted with an error
2. **Force deploy**: Set `FORCE_DEPLOY=true` to proceed anyway (saves verification with timestamp)

This prevents accidental deployments when contract code has been modified but version hasn't been updated.

### 2. Contract Implementation

Ensure your contracts implement `IVersionable` with the format `x.x.x-ContractName`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IVersionable } from "deploy-helper/interfaces/IVersionable.sol";

contract MyContract is IVersionable {
    function version() external pure returns (string memory) {
        return "1.0.0-MyContract";
    }
}
```

### 3. Create Deployment Script

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { DeployHelper } from "deploy-helper/DeployHelper.sol";
import { MyContract } from "../src/MyContract.sol";
import { console } from "forge-std/console.sol";

contract DeployMyContract is DeployHelper {
    function setUp() public override {
        // Set up with "myproject" as the deployment subfolder
        // This will automatically read PROD_OWNER, MAINNET_CHAIN_IDS, and FORCE_DEPLOY from .env
        _setUp("myproject");
    }
    
    function run() public {
        // Deploy contract using CREATE3
        MyContract myContract = MyContract(
            _deploy(type(MyContract).creationCode)
        );
        
        // Check and set owner for production chains
        _checkChainAndSetOwner(address(myContract));
        
        // Save deployment information
        _afterAll();
        
        // Log deployment info
        console.log("MyContract deployed at:", address(myContract));
        console.log("MyContract version:", myContract.version());
    }
}
```

### 4. Run Deployment

```bash
# Deploy to local network
forge script script/DeployMyContract.s.sol --fork-url $LOCAL_RPC_URL --broadcast

# Deploy to testnet
forge script script/DeployMyContract.s.sol --fork-url $TESTNET_RPC_URL --broadcast --verify

# Deploy to mainnet
forge script script/DeployMyContract.s.sol --fork-url $MAINNET_RPC_URL --broadcast --verify
```

## Advanced Usage

### Custom Salt Deployment

For deploying multiple instances of the same contract:

```solidity
function run() public {
    // Deploy first instance
    MyContract instance1 = MyContract(
        _deploy(type(MyContract).creationCode)
    );
    
    // Deploy second instance with custom salt
    MyContract instance2 = MyContract(
        _deployWithSalt_(type(MyContract).creationCode, "instance2")
    );
}
```

### Multiple Contract Deployment

```solidity
function run() public {
    // Deploy contracts in sequence
    address tokenAddress = _deploy(type(MyToken).creationCode);
    address vaultAddress = _deploy(type(MyVault).creationCode);
    address factoryAddress = _deploy(type(MyFactory).creationCode);
    
    // Initialize contracts if needed
    vm.startBroadcast();
    MyVault(vaultAddress).setToken(tokenAddress);
    MyFactory(factoryAddress).setVault(vaultAddress);
    vm.stopBroadcast();
    
    // Set owners for production
    _checkChainAndSetOwner(tokenAddress);
    _checkChainAndSetOwner(vaultAddress);
    _checkChainAndSetOwner(factoryAddress);
    
    _afterAll();
}
```

## Directory Structure

After deployment, your project will have:

```
deployments/
└── myproject/                          # Your deployment subfolder
    ├── 1-latest.json                  # Latest mainnet deployments
    ├── 1-user-timestamp.json          # Specific deployment record
    ├── 11155111-latest.json           # Latest Sepolia deployments
    └── standard-json-inputs/          # Verification JSON files
        ├── 1.0.0-MyContract.json
        ├── 1.0.1-MyContract.json
        └── 1.0.1-MyContract-timestamp.json  # Created when FORCE_DEPLOY=true
```

## Version Format Requirements

Contracts must implement `IVersionable` with the format `x.x.x-ContractName`:

- ✅ `"1.0.0-MyContract"`
- ✅ `"2.1.3-TokenVault"`
- ✅ `"0.1.0-Beta-TestContract"`
- ❌ `"MyContract-1.0.0"` (wrong order)
- ❌ `"1.0.0"` (missing contract name)

## Troubleshooting

### "Standard JSON input already exists with different content"

This error occurs when the contract code has changed but you're trying to deploy with the same version. Solutions:

1. **Update the version** in your contract (recommended)
2. **Set FORCE_DEPLOY=true** in .env to override (use carefully)
3. **Delete the existing JSON** if you're sure about the changes

### "Skipping deployment, already deployed"

This occurs when a contract with this version is already deployed on-chain. CREATE3 ensures deterministic addresses, so the same version will always deploy to the same address.

## Starter Repo
Please refer to [deploy-helper-starter](https://github.com/EthSign/deploy-helper-starter)

## Dependencies

- [forge-std](https://github.com/foundry-rs/forge-std)
- [createx-forge](https://github.com/radeksvarz/createx-forge) (already included in script/CreateX/)
- [solady](https://github.com/Vectorized/solady) 
## License

MIT
