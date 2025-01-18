// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {PoolKey,Currency} from "v4-core/src/types/PoolKey.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
//import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
contract V4{
// inside a contract, test, or foundry script:
IPositionManager public immutable positionManager;
//PoolKey public immutable poolKey;
constructor(address _positionManager){
    positionManager = IPositionManager(_positionManager);
   // poolKey = _poolKey;
}
function createPool(address _token0, address _token1,uint24 lpFee, int24 tickSpacing, address hookContract, uint160 sqrtStartPriceX96) public{
    Currency currency0 = Currency.wrap(_token0);
    Currency currency1 = Currency.wrap(_token1);
    PoolKey memory pool = PoolKey({
    currency0: currency0,
    currency1: currency1,
    fee: lpFee,
    tickSpacing: tickSpacing,
    hooks: IHooks(hookContract)
});
positionManager.initializePool(pool, sqrtStartPriceX96);

}

function mintPosition(address _token0,address _token1,uint24 fee, int24 tickSpacing, address hook,uint256 liquidity, uint128 amount0Max, uint128 amount1Max, bytes memory hookData) public{
    bytes memory actions = abi.encodePacked(Actions.MINT_POSITION,Actions.SETTLE_PAIR);
    bytes[] memory params = new bytes[](2);
    Currency currency0 = Currency.wrap(_token0); // tokenAddress1 = 0 for native ETH
    Currency currency1 = Currency.wrap(_token1);
    PoolKey memory poolKey = PoolKey(currency0, currency1, fee,tickSpacing, IHooks(hook)); //currency0,currency1,fee, tickSpacing, hook
    params[0] = abi.encode(poolKey, TickMath.MIN_TICK, TickMath.MAX_TICK, liquidity, amount0Max, amount1Max, address(this), hookData);
    params[1] = abi.encode(currency0, currency1);
    uint256 deadline = block.timestamp + 30 minutes;
    uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;

    positionManager.modifyLiquidities{value: valueToPass}(
    abi.encode(actions, params),
    deadline
    );
}

function getLiquidityForAmount(uint160 sqrtPriceX96,uint160 sqrtPriceAX96,uint160 sqrtPriceBX96,uint256 amount0,uint256 amount1) internal pure returns (uint128 liquidity){
    uint128 liq = LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, amount0, amount1);
    return liq;
}

}

/*
tick spacing
0.01%	100	    1
0.05%	500	    10
0.30%	3000	60
1.00%	10_000	200

*/