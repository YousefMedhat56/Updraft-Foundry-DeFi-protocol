// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "@chainlink/contracts/src/v0.8/tests/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzepplin-contracts/contracts/mocks/ERC20Mock.sol";

contract DeployDSCEngineTest is Test {
    DeployDSCEngine public deployer;
    HelperConfig public config;
    DecentralizedStableCoin public dsc;
    DSCEngine public engine;

    address public weth;
    address public wbtc;
    address public wethUsdPriceFeed;
    address public wbtcUsdPriceFeed;
    uint256 public constant SEPLOIA_CHAIN_ID = 11155111;
    uint256 public constant ANVIL_CHAIN_ID = 31337;
    uint256 public constant ETH_USD_PRICE = 2000e8;
    uint256 public constant BTC_USD_PRICE = 1000e8;
    uint8 public constant DECIMALS = 8;

    function setUp() public {
        deployer = new DeployDSCEngine();
        config = new HelperConfig();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, weth, wbtc,) = config.activeNetworkConfig();
    }

    // Tests for Anvil (local testnet)
    function testDeployOnAnvil() public {
        // Ensure Anvil environment
        vm.chainId(ANVIL_CHAIN_ID);
        (dsc, engine, config) = deployer.run();

        // Verify non-zero addresses
        assertTrue(address(dsc) != address(0), "DSC address is zero");
        assertTrue(address(engine) != address(0), "DSCEngine address is zero");

        // Verify DSC ownership
        assertEq(dsc.owner(), address(engine), "DSC ownership not transferred to DSCEngine");

        // Verify token and price feed configuration
        address[] memory expectedTokens = new address[](2);
        address[] memory expectedPriceFeeds = new address[](2);
        expectedTokens[0] = weth;
        expectedTokens[1] = wbtc;
        expectedPriceFeeds[0] = wethUsdPriceFeed;
        expectedPriceFeeds[1] = wbtcUsdPriceFeed;

        // Verify mock price feeds
        (, int256 ethPrice,,,) = MockV3Aggregator(wethUsdPriceFeed).latestRoundData();
        (, int256 btcPrice,,,) = MockV3Aggregator(wbtcUsdPriceFeed).latestRoundData();
        assertEq(ethPrice, int256(ETH_USD_PRICE), "Incorrect ETH/USD price");
        assertEq(btcPrice, int256(BTC_USD_PRICE), "Incorrect BTC/USD price");

        // Verify mock token balances
        assertEq(ERC20Mock(weth).balanceOf(address(this)), 1000e8, "Incorrect WETH balance");
        assertEq(ERC20Mock(wbtc).balanceOf(address(this)), 1000e8, "Incorrect WBTC balance");
    }

    // Tests for Sepolia
    // TODO: Uncomment when Sepolia test is needed
    // function testDeployOnSepolia() public {
    //     // Set chain ID to Sepolia
    //     vm.chainId(SEPLOIA_CHAIN_ID);
    //     (dsc, engine, config) = deployer.run();

    //     // Verify non-zero addresses
    //     assertTrue(address(dsc) != address(0), "DSC address is zero");
    //     assertTrue(address(engine) != address(0), "DSCEngine address is zero");

    //     // Verify DSC ownership
    //     assertEq(dsc.owner(), address(engine), "DSC ownership not transferred to DSCEngine");

    //     // Verify Sepolia configuration
    //     address[] memory expectedTokens = new address[](2);
    //     address[] memory expectedPriceFeeds = new address[](2);
    //     expectedTokens[0] = 0xdd13E55209Fd76AfE204dBda4007C227904f0a81; // Sepolia WETH
    //     expectedTokens[1] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063; // Sepolia WBTC
    //     expectedPriceFeeds[0] = 0x694AA1769357215DE4FAC081bf1f309aDC325306; // Sepolia ETH/USD
    //     expectedPriceFeeds[1] = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43; // Sepolia BTC/USD
    // }

    // Test HelperConfig separately
    function testHelperConfigAnvil() public {
        vm.chainId(ANVIL_CHAIN_ID);
        HelperConfig helperConfig = new HelperConfig();
        (address ethUsdPriceFeed, address btcUsdPriceFeed, address wethToken, address wbtcToken, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        assertTrue(ethUsdPriceFeed != address(0), "Anvil ETH price feed is zero");
        assertTrue(btcUsdPriceFeed != address(0), "Anvil BTC price feed is zero");
        assertTrue(wethToken != address(0), "Anvil WETH is zero");
        assertTrue(wbtcToken != address(0), "Anvil WBTC is zero");
        assertEq(
            deployerKey, 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80, "Incorrect deployer key"
        );

        // Verify mock price feeds
        (, int256 ethPrice,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        (, int256 btcPrice,,,) = MockV3Aggregator(btcUsdPriceFeed).latestRoundData();
        assertEq(ethPrice, int256(ETH_USD_PRICE), "Incorrect ETH/USD price");
        assertEq(btcPrice, int256(BTC_USD_PRICE), "Incorrect BTC/USD price");
    }

    // TODO: Uncomment when Sepolia test is needed
    // function testHelperConfigSepolia() public {
    //     vm.chainId(SEPLOIA_CHAIN_ID);
    //     HelperConfig helperConfig = new HelperConfig();
    //     (address ethUsdPriceFeed, address btcUsdPriceFeed, address wethToken, address wbtcToken, uint256 deployerKey) =
    //         helperConfig.activeNetworkConfig();

    //     assertEq(ethUsdPriceFeed, 0x694AA1769357215DE4FAC081bf1f309aDC325306, "Incorrect Sepolia ETH price feed");
    //     assertEq(btcUsdPriceFeed, 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43, "Incorrect Sepolia BTC price feed");
    //     assertEq(wethToken, 0xdd13E55209Fd76AfE204dBda4007C227904f0a81, "Incorrect Sepolia WETH");
    //     assertEq(wbtcToken, 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063, "Incorrect Sepolia WBTC");
    //     assertEq(deployerKey, vm.envUint("PRIVATE_KEY"), "Incorrect deployer key");
    // }
}
