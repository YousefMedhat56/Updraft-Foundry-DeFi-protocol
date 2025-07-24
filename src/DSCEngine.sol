// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzepplin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzepplin-contracts/contracts/security/ReentrancyGuard.sol";

contract DSCEngine is ReentrancyGuard {
    ///////////////////
    //   Errors      //
    ///////////////////
    error DSCEngine__TokensAndPriceFeedsMustBeTheSameLength();
    error DSCEngine__TokensAndPriceFeedsLengthIsZero();
    error DSCEngine__AddressZero();
    error DSCEngine__TokenAlreadyConfigured();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__InvalidToken();
    error DSCEngine__TransferFailed();

    /////////////////////////
    //   State Variables   //
    /////////////////////////
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collatralToken => uint256 amount)) s_collateralBalances;

    ///////////////////
    //   Events      //
    ///////////////////
    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 collateralAmount);

    ///////////////////
    //   Modifiers   //
    ///////////////////
    modifier moreThanZero(uint256 val) {
        if (val <= 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isValidToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__InvalidToken();
        }
        _;
    }

    ///////////////////
    //   Functions   //
    ///////////////////
    /**
     * @notice Initializes the DSCEngine with collateral tokens, their price feeds, and the DSC token address.
     * @param tokens Array of ERC20 token addresses to be used as collateral (e.g., WETH, WBTC).
     * @param priceFeeds Array of Chainlink price feed addresses corresponding to the tokens (e.g., ETH/USD, BTC/USD).
     * @param dscAddress Address of the DecentralizedStableCoin contract.
     * @dev Reverts if:
     *      - The lengths of `tokens` and `priceFeeds` arrays do not match.
     *      - The `tokens` array is empty.
     *      - Any address (`dscAddress`, token, or price feed) is the zero address.
     *      - A token is already configured with a price feed.
     * @dev TODO: The constructor does not verify that `tokens` are valid ERC20 contracts or that `priceFeeds` are valid Chainlink price feeds.
     */
    constructor(address[] memory tokens, address[] memory priceFeeds, address dscAddress) {
        if (tokens.length != priceFeeds.length) {
            revert DSCEngine__TokensAndPriceFeedsMustBeTheSameLength();
        }

        if (tokens.length == 0) {
            revert DSCEngine__TokensAndPriceFeedsLengthIsZero();
        }

        if (dscAddress == address(0)) {
            revert DSCEngine__AddressZero();
        }

        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0) || priceFeeds[i] == address(0)) {
                revert DSCEngine__AddressZero();
            }
            if (s_priceFeeds[tokens[i]] != address(0)) {
                revert DSCEngine__TokenAlreadyConfigured();
            }
            s_priceFeeds[tokens[i]] = priceFeeds[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////////////
    //   External Functions  //
    ///////////////////////////
    function depositCollateralAndMintDsc() external {}

    /**
     * @notice Deposits collateral tokens into the DSCEngine contract.
     * @param collateralTokenAddress The address of the ERC20 token (e.g., WETH or WBTC).
     * @param collateralAmount The amount of tokens to deposit (in token decimals).
     * @dev TODO: Requires the user to have approved the DSCEngine contract to spend `collateralAmount` tokens.
     * @dev Emits a `CollateralDeposited` event on success.
     */
    function depositCollateral(address collateralTokenAddress, uint256 collateralAmount)
        external
        isValidToken(collateralTokenAddress)
        moreThanZero(collateralAmount)
        nonReentrant
    {
        s_collateralBalances[msg.sender][collateralTokenAddress] += collateralAmount;
        emit CollateralDeposited(msg.sender, collateralTokenAddress, collateralAmount);

        bool success = IERC20(collateralTokenAddress).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
