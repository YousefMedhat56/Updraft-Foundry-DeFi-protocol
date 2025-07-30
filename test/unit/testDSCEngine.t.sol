// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzepplin-contracts/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    ///////////////////
    //   Events      //
    ///////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);
    event CollateralRedeemed(address indexed from, address indexed to, address indexed token, uint256 amount);
    event DSCMinted(address indexed user, uint256 amountMinted);
    event DSCBurned(address indexed onBehalfOf, address indexed dscFrom, uint256 amountBurned);

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
    address public LIQUIDATOR = makeAddr("liquidator");
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // 10 WETH or WBTC
    uint256 public constant AMOUNT_DSC_TO_MINT = 1000 ether; // $1000 DSC
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
        ERC20Mock(weth).mint(LIQUIDATOR, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(LIQUIDATOR, STARTING_ERC20_BALANCE);
    }

    // Helper function to deposit collateral
    function depositCollateral(address user, address token, uint256 amount) internal {
        vm.startPrank(user);
        ERC20Mock(token).approve(address(engine), amount);
        engine.depositCollateral(token, amount);
        vm.stopPrank();
    }

    // Helper function to mint DSC
    function mintDsc(address user, uint256 amount) internal {
        vm.startPrank(user);
        engine.mintDsc(amount);
        vm.stopPrank();
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

    ///////////////////////
    // mintDsc Tests //
    ///////////////////////

    function testMintDscSuccess() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL); // 10 WETH = $20,000
        uint256 expectedHealthFactor = 10e18; // ($20,000 * 0.5) / $1000 = 10

        vm.startPrank(USER);
        vm.expectEmit(true, false, false, true, address(engine));
        emit DSCMinted(USER, AMOUNT_DSC_TO_MINT);
        engine.mintDsc(AMOUNT_DSC_TO_MINT);
        vm.stopPrank();

        assertEq(dsc.balanceOf(USER), AMOUNT_DSC_TO_MINT, "Incorrect DSC balance");
        assertEq(engine.getDscMinted(USER), AMOUNT_DSC_TO_MINT, "Incorrect s_DSCMinted");
        assertEq(engine.getCollateralBalance(USER, weth), AMOUNT_COLLATERAL, "Collateral balance changed");
        assertApproxEqAbs(engine.getHealthFactor(USER), expectedHealthFactor, 1e15, "Incorrect health factor");
    }

    function testRevertsIfMintZero() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.mintDsc(0);
        vm.stopPrank();
    }

    function testRevertsIfHealthFactorBroken() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL); // 10 WETH = $20,000
        uint256 excessiveDsc = 10001e18; // $10,001 DSC

        vm.startPrank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0.999900009999000099e18)
        );
        engine.mintDsc(excessiveDsc);
        vm.stopPrank();
    }

    function testRevertsIfNoCollateral() public {
        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        engine.mintDsc(AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
    }

    function testMintWithMultipleCollateral() public {
        depositCollateral(USER, weth, 5 ether); // 5 WETH = $10,000
        depositCollateral(USER, wbtc, 5 ether); // 5 WBTC = $5,000
        uint256 dscToMint = 7500e18; // $7,500 DSC, health factor = ($15,000 * 0.5) / $7,500 = 1

        vm.startPrank(USER);
        vm.expectEmit(true, false, false, true, address(engine));
        emit DSCMinted(USER, dscToMint);
        engine.mintDsc(dscToMint);
        vm.stopPrank();

        assertEq(dsc.balanceOf(USER), dscToMint, "Incorrect DSC balance");
        assertEq(engine.getDscMinted(USER), dscToMint, "Incorrect s_DSCMinted");
        assertEq(engine.getCollateralBalance(USER, weth), 5 ether, "WETH balance changed");
        assertEq(engine.getCollateralBalance(USER, wbtc), 5 ether, "WBTC balance changed");
    }

    /////////////////////////////
    // redeemCollateral Tests //
    /////////////////////////////

    function testRedeemCollateralSuccess() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL); // 10 WETH = $20,000
        uint256 redeemAmount = 5 ether; // 5 WETH
        uint256 expectedHealthFactor = type(uint256).max; // No DSC debt

        vm.startPrank(USER);
        vm.expectEmit(true, true, true, true, address(engine));
        emit CollateralRedeemed(USER, USER, weth, redeemAmount);
        engine.redeemCollateral(weth, redeemAmount);
        vm.stopPrank();

        assertEq(
            engine.getCollateralBalance(USER, weth), AMOUNT_COLLATERAL - redeemAmount, "Incorrect collateral balance"
        );
        assertEq(ERC20Mock(weth).balanceOf(USER), redeemAmount, "Incorrect user WETH balance");
        assertEq(
            ERC20Mock(weth).balanceOf(address(engine)),
            AMOUNT_COLLATERAL - redeemAmount,
            "Incorrect contract WETH balance"
        );
        assertEq(engine.getHealthFactor(USER), expectedHealthFactor, "Incorrect health factor");
    }

    function testRevertsIfRedeemZero() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        engine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsIfInsufficientCollateral() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        uint256 excessiveAmount = AMOUNT_COLLATERAL + 1 ether;
        vm.startPrank(USER);
        vm.expectRevert();
        engine.redeemCollateral(weth, excessiveAmount);
        vm.stopPrank();
    }

    function testRedeemAllCollateralNoDebt() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectEmit(true, true, true, true, address(engine));
        emit CollateralRedeemed(USER, USER, weth, AMOUNT_COLLATERAL);
        engine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();

        assertEq(engine.getCollateralBalance(USER, weth), 0, "Collateral balance not zero");
        assertEq(ERC20Mock(weth).balanceOf(USER), AMOUNT_COLLATERAL, "Incorrect user WETH balance");
        assertEq(ERC20Mock(weth).balanceOf(address(engine)), 0, "Contract WETH balance not zero");
        assertEq(engine.getHealthFactor(USER), type(uint256).max, "Incorrect health factor");
    }
}
