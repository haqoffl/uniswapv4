// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;
import {Test,console} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {DynamicFee} from "../src/DynamicFee.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
contract DynamicFeeTest is Test,Deployers{
using CurrencyLibrary for Currency;
using PoolIdLibrary for PoolKey;
DynamicFee public hook;

function setUp() external {
deployFreshManagerAndRouters();
deployMintAndApprove2Currencies();
 vm.txGasPrice(10 gwei);
  address hookAddress = address(
        uint160(
            Hooks.BEFORE_INITIALIZE_FLAG |
                Hooks.BEFORE_SWAP_FLAG |
                Hooks.AFTER_SWAP_FLAG
        )
    );

    deployCodeTo("DynamicFee.sol",abi.encode(manager), hookAddress);
    hook = DynamicFee(hookAddress);
    
    (key, ) = initPool(
        currency0,
        currency1,
        hook,
        LPFeeLibrary.DYNAMIC_FEE_FLAG, 
        SQRT_PRICE_1_1
        );

       modifyLiquidityRouter.modifyLiquidity(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 100 ether,
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );

}

function test_feeUpdateWithGasPrice() public{
    PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});
    IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
        zeroForOne: true,
        amountSpecified: 0.001 ether,
        sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
    });

    uint128 gasPrice = uint128(tx.gasprice);
    uint128 movingAverageGasPrice = hook.movingAverageGasPrice();
    uint104 movingAverageGasPriceCount = hook.movingAverageGasPriceCount();
    assertEq(gasPrice, 10 gwei);
    assertEq(movingAverageGasPrice, 10 gwei);
    assertEq(movingAverageGasPriceCount, 1);

    swapRouter.swap(key, swapParams, testSettings, ZERO_BYTES);
    console.log("gasPrice after swap: ",tx.gasprice);
    console.log("movingAverageGasPrice after swap: ",hook.movingAverageGasPrice());
    console.log("movingAverageGasPriceCount after swap: ",hook.movingAverageGasPriceCount());
    console.log("fee: ",hook.getFee());
    vm.txGasPrice(50 gwei);
    swapRouter.swap(key, swapParams, testSettings, ZERO_BYTES);

        console.log("gasPrice after swap-2: ",tx.gasprice);
    console.log("movingAverageGasPrice after swap-2: ",hook.movingAverageGasPrice());
    console.log("movingAverageGasPriceCount after swap-2: ",hook.movingAverageGasPriceCount());
    console.log("fee -2: ",hook.getFee());

    // you can see the LP fee changes in above example

}

}