// scripts/DeployStableCoin.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployStableCoin is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy the DecentralizedStableCoin contract
        DecentralizedStableCoin stableCoin = new DecentralizedStableCoin();

        vm.stopBroadcast();
    }
}
