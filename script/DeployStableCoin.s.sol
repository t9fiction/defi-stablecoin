// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {PKRSEngine} from "src/PKRSEngine.sol";

contract DeployStableCoin is Script {
    function run() external returns(DecentralizedStableCoin, PKRSEngine) {
        vm.startBroadcast();

        // Deploy the DecentralizedStableCoin contract
        DecentralizedStableCoin stableCoin = new DecentralizedStableCoin();
        // PKRSEngine engine = new PKRSEngine();

        vm.stopBroadcast();
    }
}
