// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import { Script, console } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { CreateXScript } from "createx-forge/script/CreateXScript.sol";
import { CREATEX_ADDRESS } from "createx-forge/script/CreateX.d.sol";
import { IVersionable } from "../../src/common/interfaces/IVersionable.sol";
import { strings } from "./strings.sol";
import { Ownable } from "solady/auth/Ownable.sol";

abstract contract DeploymentHelper is CreateXScript {
    using strings for *;

    string public jsonPath;
    string public jsonPathLatest;
    string public jsonObjKeyDiff;
    string public jsonObjKeyAll;
    string public finalJson;
    string public finalJsonLatest;
    string public unixTime;

    // Configuration
    address internal productionOwner;
    uint256[] internal mainnetChainIds;

    function setUp() public virtual {
        revert("Must override and call `_setUp(string)`!");
    }

    function _setUp(string memory subfolder) internal withCreateX {
        unixTime = vm.toString(vm.unixTime());
        jsonPath = string.concat(
            vm.projectRoot(),
            "/deployments/",
            subfolder,
            "/",
            vm.toString(block.chainid),
            "-",
            __getUnixHost(),
            "-",
            unixTime,
            ".json"
        );
        jsonPathLatest =
            string.concat(vm.projectRoot(), "/deployments/", subfolder, "/", vm.toString(block.chainid), "-latest.json");
        jsonObjKeyDiff = "deploymentObjKeyDiff";
        jsonObjKeyAll = "deploymentObjKeyAll";
    }

    function _configureProduction(address _owner, uint256[] memory _chainIds) internal {
        productionOwner = _owner;
        mainnetChainIds = _chainIds;
    }

    function _afterAll() internal {
        vm.writeJson(finalJson, jsonPath);
        vm.writeJson(finalJsonLatest, jsonPathLatest);
    }

    function deploy(bytes memory creationCode) internal returns (address) {
        (, address deployed) = __deploy(creationCode, "");
        return deployed;
    }

    function _checkChainAndSetOwner(address instance) internal {
        bool isMainnet = false;
        for (uint256 i = 0; i < mainnetChainIds.length; i++) {
            if (block.chainid == mainnetChainIds[i]) {
                isMainnet = true;
                break;
            }
        }

        if (!isMainnet) {
            console.log(unicode"✅[INFO] Testnet detected, skipping owner reassignment.");
            return;
        }

        if (Ownable(instance).owner() == productionOwner) {
            console.log(unicode"✅[INFO] Owner already set to %s for %s, skipping reassignment.", productionOwner, instance);
            return;
        }
        
        vm.broadcast();
        Ownable(instance).transferOwnership(productionOwner);
        console.log(unicode"✅[INFO] Mainnet detected, owner reassigned to %s for %s.", productionOwner, instance);
    }

    function _getSalt(string memory version) internal view returns (bytes32) {
        bytes1 crosschainProtectionFlag = bytes1(0x00); // 0: allow crosschain, 1: disallow crosschain
        bytes11 randomSeed = bytes11(keccak256(abi.encode(version)));
        return bytes32(abi.encodePacked(msg.sender, crosschainProtectionFlag, randomSeed));
    }

    function __deploy(bytes memory creationCode, string memory subfolder) private returns (bool, address) {
        (string memory name, string memory versionAndVariant) = __getNameVersionAndVariant(creationCode);
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
        __saveContractToStandardJsonInput(name, versionAndVariant, subfolder);
        return (true, deployed);
    }

    function __getNameVersionAndVariant(bytes memory creationCode)
        private
        returns (string memory name, string memory versionAndVariant)
    {
        address mockDeploymentAddress;
        assembly {
            mockDeploymentAddress := create(0, add(creationCode, 0x20), mload(creationCode))
        }
        versionAndVariant = IVersionable(mockDeploymentAddress).version();
        strings.slice memory slice = versionAndVariant.toSlice();
        strings.slice memory delimiter = "-".toSlice();
        string[] memory parts = new string[](slice.count(delimiter) + 1);
        for (uint256 i = 0; i < parts.length; i++) {
            parts[i] = slice.split(delimiter).toString();
        }
        name = parts[1];
    }

    function __getUnixHost() private returns (string memory) {
        string[] memory inputs = new string[](1);
        inputs[0] = "whoami";
        return string(vm.ffi(inputs));
    }

    function __saveContractToStandardJsonInput(
        string memory contractName,
        string memory versionAndVariant,
        string memory subfolder
    )
        private
    {
        string[] memory inputs = new string[](5);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = "0x0000000000000000000000000000000000000000";
        inputs[3] = contractName;
        inputs[4] = "--show-standard-json-input";
        string memory output = string(vm.ffi(inputs));

        string memory outputPath = string.concat(
            vm.projectRoot(), "/deployments/", subfolder, "/standard-json-inputs/", versionAndVariant, ".json"
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
                    "/deployments/",
                    subfolder,
                    "/standard-json-inputs/",
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
}