// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDSC is Script {
    function run() public returns (DecentralizedStableCoin) {
        vm.startBroadcast();
        DecentralizedStableCoin decentralizedStableCoin = new DecentralizedStableCoin();
        console.log(
            "DecentralizedStableCoin deployed at:",
            address(decentralizedStableCoin)
        );
        vm.stopBroadcast();

        return decentralizedStableCoin;
    }
}
