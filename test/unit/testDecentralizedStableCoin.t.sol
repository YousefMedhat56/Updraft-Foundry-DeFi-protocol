// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {Ownable} from "@openzepplin-contracts/contracts/access/Ownable.sol";

contract DecentralizedStableCoinTest is Test {
    DeployDSC public deployer;
    DecentralizedStableCoin public dsc;

    address public owner;
    address public user = address(0x123);
    uint256 public constant MINT_AMOUNT = 1000 * 10 ** 18; // 1000 DSC tokens
    uint256 public constant BURN_AMOUNT = 500 * 10 ** 18; // 500 DSC tokens

    function setUp() public {
        deployer = new DeployDSC();
        dsc = deployer.run();
        owner = dsc.owner(); // Owner is set by the DeployDSC script
    }

    // Test constructor initialization
    function testConstructor() public view {
        assertEq(dsc.name(), "DecentralizedStableCoin");
        assertEq(dsc.symbol(), "DSC");
        assertEq(dsc.decimals(), 18);
        assertEq(dsc.totalSupply(), 0);
        assertEq(dsc.owner(), owner);
    }

    // Test minting functionality
    function testMintSuccess() public {
        vm.prank(owner);
        bool success = dsc.mint(user, MINT_AMOUNT);
        assertTrue(success);
        assertEq(dsc.balanceOf(user), MINT_AMOUNT);
        assertEq(dsc.totalSupply(), MINT_AMOUNT);
    }

    function testMintToZeroAddressReverts() public {
        vm.prank(owner);
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__AddressZero
                .selector
        );
        dsc.mint(address(0), MINT_AMOUNT);
    }

    function testMintZeroAmountReverts() public {
        vm.prank(owner);
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__AmountLessThanZero
                .selector
        );
        dsc.mint(user, 0);
    }

    function testMintNonOwnerReverts() public {
        vm.prank(user);
        vm.expectRevert();
        dsc.mint(user, MINT_AMOUNT);
    }

    // Test burning functionality
    function testBurnSuccess() public {
        // First mint tokens to owner
        vm.startPrank(owner);
        dsc.mint(owner, MINT_AMOUNT);
        dsc.burn(BURN_AMOUNT);
        vm.stopPrank();

        assertEq(dsc.balanceOf(owner), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(dsc.totalSupply(), MINT_AMOUNT - BURN_AMOUNT);
    }

    function testBurnZeroAmountReverts() public {
        vm.prank(owner);
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__AmountLessThanZero
                .selector
        );
        dsc.burn(0);
    }

    function testBurnExceedsBalanceReverts() public {
        vm.startPrank(owner);
        dsc.mint(owner, MINT_AMOUNT);
        vm.expectRevert(
            DecentralizedStableCoin
                .DecentralizedStableCoin__BurnAmountExceedsBalance
                .selector
        );
        dsc.burn(MINT_AMOUNT + 1);
        vm.stopPrank();
    }

    function testBurnNonOwnerReverts() public {
        vm.prank(user);
        vm.expectRevert();
        dsc.burn(MINT_AMOUNT);
    }

    // Test basic ERC20 functionality
    function testTransfer() public {
        address recipient = address(0x456);
        vm.startPrank(owner);
        dsc.mint(owner, MINT_AMOUNT);
        bool success = dsc.transfer(recipient, MINT_AMOUNT / 2);
        vm.stopPrank();

        assertTrue(success);
        assertEq(dsc.balanceOf(owner), MINT_AMOUNT / 2);
        assertEq(dsc.balanceOf(recipient), MINT_AMOUNT / 2);
    }

    // Test ownership transfer
    function testTransferOwnership() public {
        address newOwner = address(0x789);
        vm.prank(owner);
        dsc.transferOwnership(newOwner);
        assertEq(dsc.owner(), newOwner);
    }

    function testTransferOwnershipNonOwnerReverts() public {
        vm.prank(user);
        vm.expectRevert();
        dsc.transferOwnership(address(0x789));
    }
}
