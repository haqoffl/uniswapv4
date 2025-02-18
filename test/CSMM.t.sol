// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;
import {Test,console} from "forge-std/Test.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {IERC20Minimal} from "v4-core/src/interfaces/external/IERC20Minimal.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";

import "../src/CSMM.sol";

contract CSMMtest is Test,Deployers{
    using PoolIdLibrary for PoolId;
    using CurrencyLibrary for Currency;

    CSMM hook;
    function setUp() public{
        
          deployFreshManagerAndRouters();
          (currency0, currency1) = deployMintAndApprove2Currencies();
          address hookAddress = address(
            uint160(
                Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                    Hooks.BEFORE_SWAP_FLAG |
                    Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            )
        );
        deployCodeTo("CSMM.sol", abi.encode(manager), hookAddress);
        hook = CSMM(hookAddress);

        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            3000,
            SQRT_PRICE_1_1
        );

        IERC20Minimal(Currency.unwrap(key.currency0)).approve(
            hookAddress,
            1000 ether
        );
        IERC20Minimal(Currency.unwrap(key.currency1)).approve(
            hookAddress,
            1000 ether
        );

        hook.addLiquidity(key, 1000e18);

    }

function test_cannotModifyLiquidity() public {
    vm.expectRevert();
    modifyLiquidityRouter.modifyLiquidity(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 1e18,
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );
}

function test_claimTokenBalances() public view {

    uint token0ClaimID = CurrencyLibrary.toId(currency0);
    uint token1ClaimID = CurrencyLibrary.toId(currency1);

    uint token0ClaimsBalance = manager.balanceOf(
        address(hook),
        token0ClaimID
    );
    uint token1ClaimsBalance = manager.balanceOf(
        address(hook),
        token1ClaimID
    );

    console.log("token0 claims balance: ",token0ClaimsBalance);
    console.log("token1 claims balance: ",token1ClaimsBalance);

    assertEq(token0ClaimsBalance, 1000e18);
    assertEq(token1ClaimsBalance, 1000e18);
}


function test_removeLiquidity() public{
    hook.removeLiquidity(key, 100e18);
(uint bal1,uint bal2) = hook.balanceOfHooks(key.currency0.toId(),key.currency1.toId());
 console.log("balance1:",bal1);
 console.log("balance2",bal2);


} 

function test_swap_exactInput_zeroForOne() public {
    PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
        takeClaims: false,
        settleUsingBurn: false
    });

    // Swap exact input 100 Token A
    uint balanceOfTokenABefore = key.currency0.balanceOfSelf();
    uint balanceOfTokenBBefore = key.currency1.balanceOfSelf();
    swapRouter.swap(
        key,
        IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: -100e18,
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        }),
        settings,
        ZERO_BYTES
    );
    uint balanceOfTokenAAfter = key.currency0.balanceOfSelf();
    uint balanceOfTokenBAfter = key.currency1.balanceOfSelf();
    console.log("balance of tokenA before: ",balanceOfTokenABefore);
    console.log("balance of tokenB before: ",balanceOfTokenBBefore);
    console.log("balance of tokenA after: ",balanceOfTokenAAfter);
    console.log("balance of tokenB after: ",balanceOfTokenBAfter);

    assertEq(balanceOfTokenBAfter - balanceOfTokenBBefore, 100e18);
    assertEq(balanceOfTokenABefore - balanceOfTokenAAfter, 100e18);
}



function test_balance() public{
 (uint bal1,uint bal2) = hook.balanceOfHooks(key.currency0.toId(),key.currency1.toId());
 console.log("balance1:",bal1);
 console.log("balance2",bal2);
}
}