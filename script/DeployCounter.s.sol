// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import {DeployHelper} from "./DeployHelper.sol";
import {Counter} from "../src/Counter.sol";
import {console} from "../lib/forge-std/src/console.sol";

contract DeployCounter is DeployHelper {
    function setUp() public override {
        // Set up with "counter" as the project subfolder
        _setUp("counter");

        // Configure production settings
        address productionOwner = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // Example address
        uint256[] memory mainnetChainIds = new uint256[](2);
        mainnetChainIds[0] = 1; // Ethereum mainnet
        mainnetChainIds[1] = 137; // Polygon mainnet

        _configureProduction(productionOwner, mainnetChainIds);
    }

    function run() public {
        // Deploy Counter contract
        Counter counter = Counter(deploy(type(Counter).creationCode));

        // Check and set owner for production chains
        _checkChainAndSetOwner(address(counter));

        // Save deployment information
        _afterAll();

        // Log deployment info
        console.log("Counter deployed at:", address(counter));
        console.log("Counter version:", counter.version());
        console.log("Counter owner:", counter.owner());
    }
}
