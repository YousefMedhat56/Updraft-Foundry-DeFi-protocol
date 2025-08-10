# Decentralized Stablecoin Project

## Project Overview
This project implements a decentralized stablecoin system, developed as part of the *Advanced Foundry Course* on [Cyfrin Updraft](https://updraft.cyfrin.io/courses/advanced-foundry/develop-defi-protocol/defi-introduction). <br> The system consists of two main smart contracts:
- **DecentralizedStableCoin**: An ERC20 token representing a USD-pegged stablecoin, with minting and burning restricted to the `DSCEngine` contract via `Ownable` access control.
- **DSCEngine**: The core logic contract managing collateral (e.g., WETH, WBTC), minting, burning, and liquidation of the stablecoin. It ensures over-collateralization with a health factor ≥ 1, using Chainlink price feeds for real-time asset pricing.

Key features include depositing collateral, minting stablecoins, redeeming collateral, burning stablecoins, and liquidating under-collateralized positions. The project leverages advanced Solidity 0.8.19 features, secure patterns like Checks-Effects-Interactions, and comprehensive testing with Foundry’s unit, fuzz, and invariant tests.

## Prerequisites
Before setting up the project, ensure you have the following installed:
- **Foundry**: For compiling, testing, and deploying smart contracts.
  - Install with: `curl -L https://foundry.paradigm.xyz | `
- **MetaMask** or another Ethereum wallet (for testnet/mainnet deployment).
- A compatible Ethereum development environment (e.g., Hardhat, Remix, or VS Code with Solidity extensions).

## Setup
1. **Clone the Repository**:
   ```
   git clone https://github.com/YousefMedhat56/Updraft-Foundry-DeFi-protocol.git
   ```

2. **Install Dependencies**:
   - Ensure Foundry is installed:
     ```
     foundryup
     forge --version
     ```
   - Install project dependencies (OpenZeppelin, Chainlink contracts):
     ```
     forge install
     ```

3. **Compile Contracts**:
   ```
   forge build
   ```

## Testing
The project includes extensive unit and fuzz tests using Foundry to ensure contract reliability and security.

1. **Run Unit Tests**:
   - Execute all unit tests in `test/DSCEngineTest.sol`:
     ```
     forge test -vv
     ```
   - Run a specific test (e.g., `testLiquidatorTakesOnUsersDebt`):
     ```
     forge test --match-test testLiquidatorTakesOnUsersDebt -vv
     ```

2. **Run Fuzz Tests**:
   - Execute invariant tests in `test/InvariantTest.sol` to verify properties like non-negative collateral balances and valid health factors:
     ```
     forge test --match-path test/fuzz/Invariants.t.sol -vv
     ```

3. **Generate Coverage Report**:
   - Check test coverage to identify untested code paths:
     ```
     forge coverage
     ```

## Usage
1. **Interact with the System**:
   - **Deposit Collateral**: Deposit WETH or WBTC to back DSC minting.
     ```
     engine.depositCollateral(weth, 10 ether);
     ```
   - **Mint DSC**: Mint stablecoins based on collateral value.
     ```
     engine.mintDsc(1000e18); // Mint $1000 DSC
     ```
   - **Redeem Collateral**: Withdraw collateral if health factor remains ≥ 1.
     ```
     engine.redeemCollateral(weth, 5 ether);
     ```
   - **Burn DSC**: Repay DSC to reduce debt.
     ```
     engine.burnDsc(500e18); // Burn $500 DSC
     ```
   - **Liquidate**: Liquidate under-collateralized users (health factor < 1).
     ```
     engine.liquidate(weth, user, 1000e18);
     ```

2. **Example Workflow**:
   - Deposit 10 WETH ($20,000 at $2,000/ETH).
   - Mint $10,000 DSC (health factor = ($20,000 * 0.5) / $10,000 = 1).
   - If ETH price drops to $1,800, health factor = ($18,000 * 0.5) / $10,000 = 0.9, enabling liquidation.

## Resources
- **Cyfrin Updraft Course**: This project was built as part of the *Advanced Foundry Course* on Cyfrin Updraft: [Advanced Foundry Course](https://updraft.cyfrin.io/courses/advanced-foundry/develop-defi-protocol/defi-introduction).


