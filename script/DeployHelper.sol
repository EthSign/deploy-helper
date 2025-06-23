// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {CreateXScript} from "./CreateX/CreateXScript.sol";
import {IVersionable} from "./interfaces/IVersionable.sol";
import {strings} from "./utils/strings.sol";

/**
 * @title DeployHelper
 * @notice A reusable deployment helper that extends CreateXScript for deterministic deployments
 * @dev Assumes all contracts implement IVersionable with format "x.x.x-ContractName"
 *      Automatically saves deployment info and verification JSONs
 */
abstract contract DeployHelper is CreateXScript, IVersionable {
    using strings for *;

    // Deployment tracking
    string public jsonPath;
    string public jsonPathLatest;
    string public jsonObjKeyDiff;
    string public jsonObjKeyAll;
    string public finalJson;
    string public finalJsonLatest;
    string public unixTime;

    // Production configuration
    address public productionOwner;
    mapping(uint256 => bool) public isProductionChain;

    // Events
    event ContractDeployed(string indexed version, address indexed contractAddress, string contractName);
    event OwnershipTransferred(address indexed contractAddress, address indexed newOwner);

    /**
     * @notice Must be overridden by implementing contracts
     * @dev Should call _setUp(string) with the deployment subfolder name
     */
    function setUp() public virtual {
        revert("Must override and call `_setUp(string)`!");
    }

    /**
     * @notice Internal setup function to initialize deployment paths
     * @param subfolder The deployment subfolder for organizing deployments
     */
    function _setUp(string memory subfolder) internal withCreateX {
        unixTime = vm.toString(vm.unixTime());

        // Create necessary directories
        string[] memory inputs = new string[](3);
        inputs[0] = "mkdir";
        inputs[1] = "-p";
        inputs[2] = string.concat(vm.projectRoot(), "/deployments/", subfolder);
        vm.ffi(inputs);

        inputs[2] = string.concat(vm.projectRoot(), "/deployments/verification/standard-json-inputs");
        vm.ffi(inputs);

        jsonPath = string.concat(
            vm.projectRoot(),
            "/deployments/",
            subfolder,
            "/",
            vm.toString(block.chainid),
            "-",
            _getUnixHost(),
            "-",
            unixTime,
            ".json"
        );
        jsonPathLatest =
            string.concat(vm.projectRoot(), "/deployments/", subfolder, "/", vm.toString(block.chainid), "-latest.json");
        jsonObjKeyDiff = "deploymentObjKeyDiff";
        jsonObjKeyAll = "deploymentObjKeyAll";
    }

    /**
     * @notice Configure production settings for mainnet deployments
     * @param _productionOwner Address to transfer ownership to on production chains
     * @param _productionChainIds Array of chain IDs considered production chains
     */
    function _configureProduction(address _productionOwner, uint256[] memory _productionChainIds) internal {
        productionOwner = _productionOwner;
        for (uint256 i = 0; i < _productionChainIds.length; i++) {
            isProductionChain[_productionChainIds[i]] = true;
        }
    }

    /**
     * @notice Deploy a contract using CREATE3 for deterministic addresses
     * @param creationCode The contract creation bytecode
     * @return deployed The deployed contract address
     */
    function _deploy(bytes memory creationCode) internal returns (address deployed) {
        (bool didDeploy, address deployedAddress) = __deploy(creationCode);
        if (didDeploy) {
            // Contract was newly deployed
        }
        return deployedAddress;
    }

    /**
     * @notice Deploy a contract with custom salt suffix
     * @param creationCode The contract creation bytecode
     * @param saltSuffix Custom suffix for the salt
     * @return deployed The deployed contract address
     */
    function _deployWithSalt(bytes memory creationCode, string memory saltSuffix) internal returns (address deployed) {
        (bool didDeploy, address deployedAddress) = __deployWithSalt(creationCode, saltSuffix);
        if (didDeploy) {
            // Contract was newly deployed
        }
        return deployedAddress;
    }

    /**
     * @notice Finalize deployment by writing JSON files
     * @dev Should be called at the end of deployment scripts
     */
    function _afterAll() internal {
        if (bytes(finalJson).length > 0) {
            vm.writeJson(finalJson, jsonPath);
        }

        if (bytes(finalJsonLatest).length > 0) {
            vm.writeJson(finalJsonLatest, jsonPathLatest);
        }
    }

    /**
     * @notice Check if current chain is production and transfer ownership if needed
     * @param instance The contract instance to check/transfer ownership
     */
    function _checkChainAndSetOwner(address instance) internal {
        if (!isProductionChain[block.chainid]) {
            console.log(unicode"✅[INFO] Testnet detected, skipping owner reassignment.");
            return;
        }

        if (productionOwner == address(0)) {
            console.log(unicode"⚠️[WARN] Production chain detected but no production owner configured.");
            return;
        }

        if (Ownable(instance).owner() == productionOwner) {
            console.log(
                unicode"✅[INFO] Owner already set to %s for %s, skipping reassignment.", productionOwner, instance
            );
            return;
        }

        vm.broadcast();
        Ownable(instance).transferOwnership(productionOwner);
        console.log(
            unicode"✅[INFO] Production chain detected, owner reassigned to %s for %s.", productionOwner, instance
        );

        emit OwnershipTransferred(instance, productionOwner);
    }

    /**
     * @notice Generate salt for CREATE3 deployment
     * @param versionString The version string from the contract
     * @return salt The generated salt
     */
    function _getSalt(string memory versionString) internal view returns (bytes32) {
        bytes1 crosschainProtectionFlag = bytes1(0x00); // 0: allow crosschain, 1: disallow crosschain
        bytes11 randomSeed = bytes11(keccak256(abi.encode(versionString)));
        return bytes32(abi.encodePacked(msg.sender, crosschainProtectionFlag, randomSeed));
    }

    /**
     * @notice Generate salt with custom suffix
     * @param versionString The version string from the contract
     * @param suffix Custom suffix for the salt
     * @return salt The generated salt
     */
    function _getSaltWithSuffix(string memory versionString, string memory suffix) internal view returns (bytes32) {
        bytes1 crosschainProtectionFlag = bytes1(0x00);
        bytes11 randomSeed = bytes11(keccak256(abi.encode(versionString, suffix)));
        return bytes32(abi.encodePacked(msg.sender, crosschainProtectionFlag, randomSeed));
    }

    /**
     * @notice Internal deployment function with automatic version detection
     * @param creationCode The contract creation bytecode
     * @return didDeploy Whether the contract was newly deployed
     * @return deployed The deployed contract address
     */
    function __deploy(bytes memory creationCode) private returns (bool, address) {
        (string memory name, string memory versionAndVariant) = _getNameVersionAndVariant(creationCode);
        address computed = computeCreate3Address(_getSalt(versionAndVariant), msg.sender);
        finalJsonLatest = vm.serializeAddress(jsonObjKeyAll, versionAndVariant, computed);

        if (computed.code.length != 0) {
            console.log(unicode"⚠️[WARN] Skipping deployment, %s already deployed at %s", versionAndVariant, computed);
            return (false, computed);
        }

        vm.startBroadcast();
        address deployed = create3(_getSalt(versionAndVariant), creationCode);
        vm.stopBroadcast();

        require(computed == deployed, "Computed address mismatch");
        console.log(unicode"✅[INFO] %s deployed at %s", versionAndVariant, computed);

        finalJson = vm.serializeAddress(jsonObjKeyDiff, versionAndVariant, computed);
        _saveContractToStandardJsonInput(name, versionAndVariant);

        emit ContractDeployed(versionAndVariant, deployed, name);

        return (true, deployed);
    }

    /**
     * @notice Internal deployment function with custom salt
     * @param creationCode The contract creation bytecode
     * @param saltSuffix Custom suffix for the salt
     * @return didDeploy Whether the contract was newly deployed
     * @return deployed The deployed contract address
     */
    function __deployWithSalt(bytes memory creationCode, string memory saltSuffix) private returns (bool, address) {
        (string memory name, string memory versionAndVariant) = _getNameVersionAndVariant(creationCode);
        string memory saltKey = string.concat(versionAndVariant, "-", saltSuffix);
        address computed = computeCreate3Address(_getSaltWithSuffix(versionAndVariant, saltSuffix), msg.sender);
        finalJsonLatest = vm.serializeAddress(jsonObjKeyAll, saltKey, computed);

        if (computed.code.length != 0) {
            console.log(unicode"⚠️[WARN] Skipping deployment, %s already deployed at %s", saltKey, computed);
            return (false, computed);
        }

        vm.startBroadcast();
        address deployed = create3(_getSaltWithSuffix(versionAndVariant, saltSuffix), creationCode);
        vm.stopBroadcast();

        require(computed == deployed, "Computed address mismatch");
        console.log(unicode"✅[INFO] %s deployed at %s", saltKey, computed);

        finalJson = vm.serializeAddress(jsonObjKeyDiff, saltKey, computed);
        _saveContractToStandardJsonInput(name, saltKey);

        emit ContractDeployed(saltKey, deployed, name);

        return (true, deployed);
    }

    /**
     * @notice Extract contract name and version from creation code
     * @param creationCode The contract creation bytecode
     * @return name The contract name
     * @return versionAndVariant The full version string (x.x.x-ContractName)
     */
    function _getNameVersionAndVariant(bytes memory creationCode)
        private
        returns (string memory name, string memory versionAndVariant)
    {
        address mockDeploymentAddress;
        assembly {
            mockDeploymentAddress := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        versionAndVariant = IVersionable(mockDeploymentAddress).version();

        // Parse version format: "x.x.x-ContractName"
        strings.slice memory slice = versionAndVariant.toSlice();
        strings.slice memory delimiter = "-".toSlice();
        string[] memory parts = new string[](slice.count(delimiter) + 1);

        for (uint256 i = 0; i < parts.length; i++) {
            parts[i] = slice.split(delimiter).toString();
        }

        require(parts.length >= 2, "Invalid version format. Expected: x.x.x-ContractName");
        name = parts[1];
    }

    /**
     * @notice Get current Unix host for deployment tracking
     * @return host The current Unix host
     */
    function _getUnixHost() private returns (string memory) {
        string[] memory inputs = new string[](1);
        inputs[0] = "whoami";
        return string(vm.ffi(inputs));
    }

    /**
     * @notice Save contract verification JSON for Etherscan
     * @param contractName The contract name
     * @param versionAndVariant The version and variant string
     */
    function _saveContractToStandardJsonInput(string memory contractName, string memory versionAndVariant) private {
        string[] memory inputs = new string[](5);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = "0x0000000000000000000000000000000000000000";
        inputs[3] = contractName;
        inputs[4] = "--show-standard-json-input";
        string memory output = string(vm.ffi(inputs));

        string memory outputPath = string.concat(
            vm.projectRoot(), "/deployments/verification/standard-json-inputs/", versionAndVariant, ".json"
        );

        if (vm.isFile(outputPath)) {
            console.log(
                unicode"⏳[INFO] Verification file for %s already exists, checking for changes...", versionAndVariant
            );
            string memory existingOutput = vm.readFile(outputPath);
            if (keccak256(abi.encodePacked(existingOutput)) == keccak256(abi.encodePacked(output))) {
                console.log(
                    unicode"✅[INFO] No changes detected, skipping writing verification JSON for %s", versionAndVariant
                );
                return;
            } else {
                console.log(
                    unicode"⚠️[WARN] Changes detected, saving verification JSON for %s with current timestamp",
                    versionAndVariant
                );
                outputPath = string.concat(
                    vm.projectRoot(),
                    "/deployments/verification/standard-json-inputs/",
                    versionAndVariant,
                    "-",
                    unixTime,
                    ".json"
                );
            }
        }

        console.log(unicode"✅[INFO] Standard JSON input for %s saved", versionAndVariant);
        vm.writeFile(outputPath, output);
    }

    function version() external pure override returns (string memory) {
        return "1.0.1-DeployHelper";
    }
}
