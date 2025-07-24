// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

contract DSCEngine {
    ///////////////////
    //   Errors      //
    ///////////////////
    error DSCEngine__TokensAndPriceFeedsMustBeTheSameLength();
    error DSCEngine__TokensAndPriceFeedsLengthIsZero();
    error DSCEngine__AddressZero();
    error DSCEngine__TokenAlreadyConfigured();

    /////////////////////////
    //   State Variables   //
    /////////////////////////
    mapping(address token => address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;

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
    constructor(
        address[] memory tokens,
        address[] memory priceFeeds,
        address dscAddress
    ) {
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

    function depositCollateral() external {}

    function redeemCollateralForDsc() external {}

    function redeemCollateral() external {}

    function mintDsc() external {}

    function burnDsc() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
