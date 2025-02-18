// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {SqrtPriceMath} from "v4-core/src/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {PointsHook} from  "../src/PointsHook.sol";

contract PointsHookTest is Test,Deployers{
using CurrencyLibrary for Currency;

MockERC20 public token;
PointsHook public pointsHook;
Currency ethCurrency = Currency.wrap(address(0));
Currency tokenCurrency;
function setUp() public{
    // Deploy PoolManager and Router contracts
    deployFreshManagerAndRouters();
    //Deploy our erc20 token
    token = new MockERC20("$TRUMP", "TRP", 18);
    tokenCurrency = Currency.wrap(address(token));
    
    //minting token to this address
    token.mint(address(this),1000 ether);
    // Deploy hook to an address that has the proper flags set
    uint160 flags = uint160(
        Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.AFTER_SWAP_FLAG
    );
    deployCodeTo(
        "PointsHook.sol",
        abi.encode(manager, "Points Token", "TEST_POINTS"),
        address(flags)
    );

    // Deploy our hook
    pointsHook = PointsHook(address(flags));
    //approving swapRouter and modifyLiquidityRouter to spend our token
    token.approve(address(swapRouter), type(uint256).max);
    token.approve(address(modifyLiquidityRouter), type(uint256).max);

    (key, ) = initPool(
        ethCurrency, // Currency 0 = ETH
        tokenCurrency, // Currency 1 = TOKEN
        pointsHook, // Hook Contract
        3000, // Swap Fees
        SQRT_PRICE_1_1 // Initial Sqrt(P) value = 1
    );

}

function testAddLiquidityAndSwap() public{
    uint256 pointsBalanceOriginal = pointsHook.balanceOf(address(this));
    bytes memory hookData = abi.encode(address(this));
    uint160 sqrtPriceAtTickLower = TickMath.getSqrtPriceAtTick(-60);
    uint160 sqrtPriceAtTickUpper = TickMath.getSqrtPriceAtTick(60);
    uint256 ethToAdd = 0.1 ether;
    uint128 liquidityDelta = LiquidityAmounts.getLiquidityForAmount0(
        sqrtPriceAtTickLower,
        SQRT_PRICE_1_1,
        ethToAdd
    );

    uint256 tokenToAdd = LiquidityAmounts.getAmount1ForLiquidity(
        sqrtPriceAtTickLower,
        SQRT_PRICE_1_1,
        liquidityDelta
    );

    modifyLiquidityRouter.modifyLiquidity{value: ethToAdd}(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: int256(uint256(liquidityDelta)),
            salt: bytes32(0)
        }),
        hookData
    );
    uint256 pointsBalanceAfterAddLiquidity = pointsHook.balanceOf(address(this));
    //assert(pointsBalanceAfterAddingLiquidity > pointsBalanceOriginal);
    assertApproxEqAbs(
    pointsBalanceAfterAddLiquidity - pointsBalanceOriginal, // Actual change in points balance
    0.1 ether,                                             // Expected change in points balance
    0.001 ether                                            // Allowed margin of error
    );


        swapRouter.swap{value: 0.001 ether}(
        key,
        IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -0.001 ether, // Exact input for output swap
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }),
        PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        }),
        hookData
        );

        uint256 pointsBalanceAfterSwap = pointsHook.balanceOf(address(this));
    assertEq(
        pointsBalanceAfterSwap - pointsBalanceAfterAddLiquidity,
        2 * 10 ** 14
    );
}

}


/*
steps to create Hooks

1. inherit Base Hook
2. import hook contract
3. Need for Pool Manager to initiate Base Hook contract via constructor
4. get Hook Permissions
5. structurize your contract according to need like beforeSwap,afterSwap, beforeInitialize etc..
6. import Pool key for using as an parameter for beforeSwap,afterSwap so on..
7. according to need, import the libraries


steps to test hook contract

import {test,console} library from forge-std/Test.sol;
import IpoolManager and PoolManager
import deployer from v4-core/test/utils/Deployers.sol

 */

 // pm.unlock()

// callback pm.take()

// pm.sync()

// token.transfer(pm)

// pm.settle()