# DeployHelper Forge Package

A reusable Foundry deployment helper that provides deterministic CREATE3 deployments with automatic JSON tracking and verification file generation.

## Features

- **Deterministic Deployments**: Uses CREATE3 for consistent addresses across chains
- **Automatic Tracking**: Saves deployment info and verification JSONs
- **Version Management**: Built-in support for `x.x.x-ContractName` versioning
- **Production Safety**: Automatic owner management for mainnet deployments
- **Modular Design**: Easy to integrate into any Foundry project

## Installation

Add to your Foundry project:

```bash
forge install EthSign/deploy-helper
```

Add to your `remappings.txt`:
```
deploy-helper/=lib/deploy-helper-forge/script/
```

## Quick Start

### 1. Contract Implementation

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

### 2. Create Deployment Script

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { DeployHelper } from "deploy-helper/DeployHelper.sol";
import { MyContract } from "../src/MyContract.sol";
import { console } from "forge-std/console.sol";

contract DeployMyContract is DeployHelper {
    function setUp() public override {
        // Set up with "myproject" as the deployment subfolder
        _setUp("myproject");
        
        // Configure production settings
        address productionOwner = 0x1234567890123456789012345678901234567890;
        uint256[] memory mainnetChainIds = new uint256[](3);
        mainnetChainIds[0] = 1;   // Ethereum mainnet
        mainnetChainIds[1] = 137; // Polygon mainnet
        mainnetChainIds[2] = 56;  // BSC mainnet
        
        _configureProduction(productionOwner, mainnetChainIds);
    }
    
    function run() public {
        // Deploy contract using CREATE3
        MyContract myContract = MyContract(
            deploy(type(MyContract).creationCode)
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

### 3. Run Deployment

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
        deploy(type(MyContract).creationCode)
    );
    
    // Deploy second instance with custom salt
    MyContract instance2 = MyContract(
        deployWithSalt(type(MyContract).creationCode, "instance2")
    );
}
```

### Multiple Contract Deployment

```solidity
function run() public {
    // Deploy contracts in sequence
    address tokenAddress = deploy(type(MyToken).creationCode);
    address vaultAddress = deploy(type(MyVault).creationCode);
    address factoryAddress = deploy(type(MyFactory).creationCode);
    
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
├── myproject/              # Your deployment subfolder
│   ├── 1-latest.json      # Latest mainnet deployments
│   ├── 1-user-timestamp.json  # Specific deployment record
│   ├── 11155111-latest.json   # Latest Sepolia deployments
│   └── ...
└── verification/
    └── standard-json-inputs/
        ├── 1.0.0-MyContract.json
        └── ...
```

## Configuration

### Production Chains

Configure which chains should trigger production owner transfers:

```solidity
uint256[] memory productionChainIds = new uint256[](4);
productionChainIds[0] = 1;    // Ethereum
productionChainIds[1] = 137;  // Polygon
productionChainIds[2] = 56;   // BSC
productionChainIds[3] = 43114; // Avalanche

_configureProduction(productionOwner, productionChainIds);
```

### File System Permissions

Ensure your `foundry.toml` includes the required permissions:

```toml
fs_permissions = [
    { access = "read-write", path = "./deployments" },
    { access = "read", path = "./" }
]
ffi = true
```

## Version Format Requirements

Contracts must implement `IVersionable` with the format `x.x.x-ContractName`:

- ✅ `"1.0.0-MyContract"`
- ✅ `"2.1.3-TokenVault"`
- ✅ `"0.1.0-Beta-TestContract"`
- ❌ `"MyContract-1.0.0"` (wrong order)
- ❌ `"1.0.0"` (missing contract name)

## Events

The DeployHelper emits events for tracking:

```solidity
event ContractDeployed(string indexed version, address indexed contractAddress, string contractName);
event OwnershipTransferred(address indexed contractAddress, address indexed newOwner);
```

## Dependencies

- [forge-std](https://github.com/foundry-rs/forge-std)
- [createx-forge](https://github.com/radeksvarz/createx-forge)
- [solady](https://github.com/Vectorized/solady)

## License

MIT