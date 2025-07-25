// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzepplin-contracts/contracts/mocks/ERC20Mock.sol";

contract DSCEngineTest is Test {
    ///////////////////
    //   Events      //
    ///////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    /////////////////////////
    //   State Variables  //
    ///////////////////////
    DeployDSCEngine deployer;
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    HelperConfig config;
    address weth;
    address wbtc;
    address ethUsdPriceFeed;
    address wbtcUsdPriceFeed;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    address public INVALID_COLLATERAL_ADDR = makeAddr("invalid_token");

    /////////////////////
    //   Setup        //
    ///////////////////
    function setUp() public {
        deployer = new DeployDSCEngine();
        (dsc, engine, config) = deployer.run();
        (ethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////
    // Price Feed Tests //
    /////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18; // 15 WETH
        uint256 expectedUsd = 30000e18; // 15 * $2000/ETH
        uint256 actualUsd = engine.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    /////////////////////////////
    // depositCollateral Tests //
    /////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsIfInvalidCollateralAddress() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__InvalidToken.selector);
        engine.depositCollateral(INVALID_COLLATERAL_ADDR, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testDepositCollateralSuccess() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL);

        vm.expectEmit(true, true, false, true, address(engine));
        emit CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);

        vm.stopPrank();

        uint256 userCollateral = engine.getCollateralBalance(USER, weth);
        assertEq(userCollateral, AMOUNT_COLLATERAL);
        assertEq(ERC20Mock(weth).balanceOf(address(engine)), AMOUNT_COLLATERAL);
        assertEq(ERC20Mock(weth).balanceOf(USER), 0);
    }

    function testRevertsIfInsufficientBalance() public {
        vm.startPrank(USER);
        uint256 excessiveAmount = STARTING_ERC20_BALANCE + 1 ether;
        ERC20Mock(weth).approve(address(engine), excessiveAmount);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        engine.depositCollateral(weth, excessiveAmount);
        vm.stopPrank();
    }

    function testRevertsIfInsufficientAllowance() public {
        vm.startPrank(USER);
        // No approval or insufficient approval
        vm.expectRevert("ERC20: insufficient allowance");
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    function testMultipleDepositsAccumulate() public {
        ERC20Mock(weth).mint(USER, AMOUNT_COLLATERAL * 2);

        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(engine), AMOUNT_COLLATERAL * 2);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        engine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 userCollateral = engine.getCollateralBalance(USER, weth);
        assertEq(userCollateral, AMOUNT_COLLATERAL * 2);
        assertEq(ERC20Mock(weth).balanceOf(address(engine)), AMOUNT_COLLATERAL * 2);
    }

    function testDepositWbtcCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(wbtc).approve(address(engine), AMOUNT_COLLATERAL);
        vm.expectEmit(true, true, false, true, address(engine));
        emit CollateralDeposited(USER, wbtc, AMOUNT_COLLATERAL);
        engine.depositCollateral(wbtc, AMOUNT_COLLATERAL);
        vm.stopPrank();

        uint256 userCollateral = engine.getCollateralBalance(USER, wbtc);
        assertEq(userCollateral, AMOUNT_COLLATERAL);
        assertEq(ERC20Mock(wbtc).balanceOf(address(engine)), AMOUNT_COLLATERAL);
    }
}
