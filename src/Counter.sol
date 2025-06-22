// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import { IVersionable } from "./interfaces/IVersionable.sol";
import { Ownable } from "../lib/solady/src/auth/Ownable.sol";

contract Counter is IVersionable, Ownable {
    string public constant override version = "1.0.0-Counter";
    
    uint256 public number;

    constructor() {
        _initializeOwner(msg.sender);
    }

    function setNumber(uint256 newNumber) public onlyOwner {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}