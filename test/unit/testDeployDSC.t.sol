// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract DeployDSCTest is Test {
    function testDeployDSC() public {
        DeployDSC deployer = new DeployDSC();
        DecentralizedStableCoin dsc = deployer.run();

        assertEq(dsc.name(), "DecentralizedStableCoin");
        assertEq(dsc.symbol(), "DSC");
        assertEq(dsc.owner(), address(msg.sender));
    }
}
