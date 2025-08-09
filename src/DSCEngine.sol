// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzepplin-contracts/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzepplin-contracts/contracts/security/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

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
    error DSCEngine__MintFailed();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    /////////////////////////
    //   State Variables   //
    /////////////////////////
    DecentralizedStableCoin private immutable i_dsc;
    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collatralToken => uint256 amount)) s_collateralBalances;
    address[] private s_collateralTokens;
    mapping(address user => uint256 mintedDsc) s_DSCMinted;

    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    int256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;

    ///////////////////
    //   Events      //
    ///////////////////

    event CollateralDeposited(address indexed user, address indexed collateralToken, uint256 collateralAmount);
    event CollateralRedeemed(
        address indexed from, address indexed to, address indexed collateralToken, uint256 collateralAmount
    );
    event DSCMinted(address indexed user, uint256 amountMinted);
    event DSCBurned(address onBehalfOf, address dscFrom, uint256 amountBurned);

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
            s_collateralTokens.push(tokens[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    ///////////////////////////
    //   External Functions  //
    ///////////////////////////
    /*
    * @param tokenCollateralAddress: the address of the token to deposit as collateral
    * @param amountCollateral: The amount of collateral to deposit
    * @param amountDscToMint: The amount of DecentralizedStableCoin to mint
    * @notice: This function will deposit your collateral and mint DSC in one transaction
    */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDsc(amountDscToMint);
    }

    /**
     * @notice Deposits collateral tokens into the DSCEngine contract.
     * @param collateralTokenAddress The address of the ERC20 token (e.g., WETH or WBTC).
     * @param collateralAmount The amount of tokens to deposit (in token decimals).
     * @dev TODO: Requires the user to have approved the DSCEngine contract to spend `collateralAmount` tokens.
     * @dev Emits a `CollateralDeposited` event on success.
     */
    function depositCollateral(address collateralTokenAddress, uint256 collateralAmount)
        public
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

    /**
     * @dev Calls burnDsc and redeemCollateral functions in a single transaction.
     * @param dscBurnedAmount The amount of DSC to burn.
     * @param tokenCollateralAddress The address of the collateral token to redeem.
     * @param amountCollateral The amount of collateral to redeem
     */
    function redeemCollateralForDsc(uint256 dscBurnedAmount, address tokenCollateralAddress, uint256 amountCollateral)
        external
    {
        burnDsc(dscBurnedAmount);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
    }

    /**
     *
     * @notice Redeems collateral tokens from the DSCEngine contract.
     * @dev Calls `_redeemCollateral` function
     * @dev Reverts if the user’s health factor is below the minimum threshold after redeeming.
     * @param tokenCollateralAddress The address of the collateral token to redeem.
     * @param amountCollateral The amount of collateral to redeem (in token decimals)
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Mints DSC tokens for the caller, ensuring sufficient collateral.
     * @param amountDscToMint The amount of DSC to mint.
     * @dev Reverts if the user’s health factor falls below 1e18 after minting.
     * @dev Emits a `DSCMinted` event on success.
     */
    function mintDsc(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            s_DSCMinted[msg.sender] -= amountDscToMint;
            revert DSCEngine__MintFailed();
        }

        emit DSCMinted(msg.sender, amountDscToMint);
    }

    /**
     * @notice Burns DSC tokens from the caller
     * @param amount The amount of DSC to burn.
     * @dev Calls `_burnDsc` function`
     * @dev Reverts if the user’s health factor is below the minimum threshold after redeeming.
     */
    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Liquidates a user's collateral by covering their debt.
     * @param collateralTokenAddress The address of the collateral token to liquidate.
     * @param user The address of the user whose collateral is being liquidated.
     * @param debtToCover The amount of debt to cover in USD (in 18 decimals).
     * @dev Reverts if the user's health factor is above the minimum threshold before liquidation.
     * @dev Reverts if the user's health factor does not improve after liquidation.
     */
    function liquidate(address collateralTokenAddress, address user, uint256 debtToCover)
        external
        isValidToken(collateralTokenAddress)
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor > MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateralTokenAddress, debtToCover);

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateralRedeemed = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(user, msg.sender, collateralTokenAddress, totalCollateralRedeemed);

        _burnDsc(debtToCover, user, msg.sender);

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    /**
     * @notice Calculates the USD value of a given amount of a token using its Chainlink price feed.
     * @param token The ERC20 token address (e.g., WETH, WBTC).
     * @param amount The amount of tokens (in token decimals).
     * @return The USD value in 18 decimals.
     */
    function getUsdValue(address token, uint256 amount) public view isValidToken(token) returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION);
    }

    function getCollateralBalance(address user, address collateralToken)
        public
        view
        isValidToken(collateralToken)
        returns (uint256)
    {
        return s_collateralBalances[user][collateralToken];
    }

    function getDscMinted(address user) public view returns (uint256) {
        return s_DSCMinted[user];
    }

    /**
     * @notice Converts a USD amount (in 18 decimals) to the equivalent token amount using its Chainlink price feed.
     * @param token The ERC20 token address (e.g., WETH, WBTC).
     * @param usdAmountInWei The USD amount in 18 decimals.
     * @return The equivalent token amount in token decimals.
     */
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei)
        public
        view
        isValidToken(token)
        returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * uint256(ADDITIONAL_FEED_PRECISION));
    }

    function getCollateralTokens() public view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getCollateralBalanceOfUser(address collateralToken, address user) public view returns (uint256) {
        return s_collateralBalances[user][collateralToken];
    }

    ////////////////////////////////////
    //   Internal & Private Functions  //
    ////////////////////////////////////

    /**
     * @notice Calculates the health factor for a user, indicating their collateral-to-debt ratio.
     * @param user The user’s address.
     * @return The health factor. Below 1e18 indicates liquidation risk.
     */
    function _healthFactor(address user) internal view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInfo(user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        if (totalDscMinted == 0) {
            return type(uint256).max; // Infinite health factor
        }

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    /**
     * @notice Reverts if the user’s health factor is below the minimum threshold (1e18).
     * @param user The user’s address.
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    function _getAccountInfo(address user)
        internal
        view
        returns (uint256 totalDscMinted, uint256 totalCollateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        totalCollateralValueInUsd = _getAccountCollateralValue(user);

        return (totalDscMinted, totalCollateralValueInUsd);
    }

    function _getAccountCollateralValue(address user) internal view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralBalances[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }

        return totalCollateralValueInUsd;
    }

    /**
     * @notice Internal function to redeem collateral tokens from the DSCEngine contract.
     * @param from The address of the user redeeming collateral.
     * @param to The address to which the collateral will be sent.
     * @param tokenCollateralAddress The address of the collateral token to redeem.
     * @param amountCollateral The amount of collateral to redeem (in token decimals).
     * @dev Emits a `CollateralRedeemed` event on success.
     */
    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
        isValidToken(tokenCollateralAddress)
        moreThanZero(amountCollateral)
        nonReentrant
    {
        s_collateralBalances[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /**
     * @notice Burns DSC tokens from a specified address and updates the user's minted DSC balance.
     * @param amountDscToBurn The amount of DSC to burn.
     * @param onBehalfOf The address on whose behalf the DSC is being burned.
     * @param dscFrom The address from which the DSC is being burned.
     * @dev Emits a `DSCBurned` event on success.
     */
    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        emit DSCBurned(onBehalfOf, dscFrom, amountDscToBurn);

        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        // This conditional is hypothetically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }
}
