// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;
import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
contract DynamicFee is BaseHook{
     using LPFeeLibrary for uint24;
    error MustUseDynamicFee();
    uint128 public movingAverageGasPrice;
    uint104 public movingAverageGasPriceCount;
    uint24 public BASE_FEE = 5000;

constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
    updateMovingAverage();
}
function getHookPermissions()  public pure override returns (Hooks.Permissions memory){
    return Hooks.Permissions({
        beforeInitialize: true,
        afterInitialize: false,
        beforeAddLiquidity: false,
        beforeRemoveLiquidity: false,
        afterAddLiquidity: false,
        afterRemoveLiquidity: false,
        beforeSwap: true,
        afterSwap: true,
        beforeDonate: false,
        afterDonate: false,
        beforeSwapReturnDelta: false,
        afterSwapReturnDelta: false,
        afterAddLiquidityReturnDelta: false,
        afterRemoveLiquidityReturnDelta: false
    });
}

    function beforeInitialize(address, PoolKey calldata key, uint160) external override returns (bytes4) {
        if(!key.fee.isDynamicFee()) revert MustUseDynamicFee();
       return this.beforeInitialize.selector;
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata) external override returns (bytes4, BeforeSwapDelta, uint24){
        uint24 fee = getFee();
        uint24 feeWithFlag = fee | LPFeeLibrary.OVERRIDE_FEE_FLAG;
        return (this.beforeSwap.selector,BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

     function afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)external override returns (bytes4, int128){
            updateMovingAverage();
            return (this.afterSwap.selector, 0);
    }

    function updateMovingAverage() internal {
    uint128 gasPrice = uint128(tx.gasprice);

    // New Average = ((Old Average * # of Txns Tracked) + Current Gas Price) / (# of Txns Tracked + 1)
    movingAverageGasPrice =
        ((movingAverageGasPrice * movingAverageGasPriceCount) + gasPrice) /
        (movingAverageGasPriceCount + 1);

    movingAverageGasPriceCount++;
}

function getFee() public view returns (uint24) {
    uint128 gasPrice = uint128(tx.gasprice);

    // if gasPrice > movingAverageGasPrice * 1.1, then half the fees
    if (gasPrice > (movingAverageGasPrice * 11) / 10) {
        return BASE_FEE / 2;
    }

    // if gasPrice < movingAverageGasPrice * 0.9, then double the fees
    if (gasPrice < (movingAverageGasPrice * 9) / 10) {
        return BASE_FEE * 2;
    }

    return BASE_FEE;
}
}
