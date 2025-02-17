// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {FixedPointMathLib} from "solmate/src/utils/FixedPointMathLib.sol";
import {IERC20} from "@openzeppelin-contracts/interfaces/IERC20.sol";

import {TickMath} from "v4-core/src/libraries/TickMath.sol";
contract TakeProfitHook is BaseHook,ERC1155{

using FixedPointMathLib for uint256;
using StateLibrary for IPoolManager;
using CurrencyLibrary for Currency;
using PoolIdLibrary for PoolKey;

mapping(PoolId poolId =>mapping(int24 tickToSellAt => mapping(bool zeroForOne => uint256 inputAmount))) public pendingOrders;
mapping(uint256 positionId => uint256 claimsSupply)public claimTokensSupply;
mapping(uint256 positionId => uint256 outputClaimable)public claimableOutputTokens;
mapping(PoolId poolId=>int24 lastTick) public lastTicks;

error InvalidOrder();
error NothingToClaim();
error NotEnoughToClaim();

constructor (IPoolManager _poolManager,string memory _uri) BaseHook(_poolManager) ERC1155(_uri)  {

}


function getHookPermissions()  public pure override returns (Hooks.Permissions memory){
    return Hooks.Permissions({
        beforeInitialize: false,
        afterInitialize: true,
        beforeAddLiquidity: false,
        beforeRemoveLiquidity: false,
        afterAddLiquidity: false,
        afterRemoveLiquidity: false,
        beforeSwap: false,
        afterSwap: true,
        beforeDonate: false,
        afterDonate: false,
        beforeSwapReturnDelta: false,
        afterSwapReturnDelta: false,
        afterAddLiquidityReturnDelta: false,
        afterRemoveLiquidityReturnDelta: false
    });
}

function afterInitialize(address, PoolKey calldata key,uint160,int24 tick) external override onlyPoolManager returns (bytes4) {
        lastTicks[key.toId()] = tick;
        return this.afterInitialize.selector;
    }

  function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, BalanceDelta, bytes calldata)external override onlyPoolManager returns (bytes4, int128){
            if(address(this) == msg.sender) return (this.afterSwap.selector, 0);
            bool tryMore = true;
            int24 currentTick = 0;
            while(tryMore){
                (tryMore, currentTick) = tryExecutingOrders(key,!params.zeroForOne);
            }

             lastTicks[key.toId()] = currentTick;
            return (this.afterSwap.selector, 0);
        }

 function tryExecutingOrders(PoolKey calldata key, bool executeZeroForOne) internal returns (bool tryMore, int24 newTick) {
    (, int24 currentTick, , ) = poolManager.getSlot0(key.toId());
    int24 lastTick = lastTicks[key.toId()];
     if (currentTick > lastTick) {
        for (
            int24 tick = lastTick;
            tick <= currentTick;
            tick += key.tickSpacing
        ) {
            uint256 inputAmount = pendingOrders[key.toId()][tick][
                executeZeroForOne
            ];
            if (inputAmount > 0) {
                executeOrder(key, tick, executeZeroForOne, inputAmount);

                return (true, currentTick);
            }
        }
    }

    else {
        for (
            int24 tick = lastTick;
            tick >= currentTick;
            tick -= key.tickSpacing
        ) {
            uint256 inputAmount = pendingOrders[key.toId()][tick][
                executeZeroForOne
            ];
            if (inputAmount > 0) {
                executeOrder(key, tick, executeZeroForOne, inputAmount);
                return (true, currentTick);
            }
        }
    }

    return (false, currentTick);
}

        function getLowerUsableTick(
    int24 tick,
    int24 tickSpacing
) private pure returns (int24) {
    // E.g. tickSpacing = 60, tick = -100
    // closest usable tick rounded-down will be -120

    // intervals = -100/60 = -1 (integer division)
    int24 intervals = tick / tickSpacing;

    // since tick < 0, we round `intervals` down to -2
    // if tick > 0, `intervals` is fine as it is
    if (tick < 0 && tick % tickSpacing != 0) intervals--; // round towards negative infinity

    // actual usable tick, then, is intervals * tickSpacing
    // i.e. -2 * 60 = -120
    return intervals * tickSpacing;
}

function getPositionId(PoolKey calldata key,int24 tick,bool zeroForOne) public pure returns (uint256) {
    return uint256(keccak256(abi.encode(key.toId(), tick, zeroForOne)));
}

function placeOrder(
    PoolKey calldata key,
    int24 tickToSellAt,
    bool zeroForOne,
    uint256 inputAmount
) external returns (int24) {
    // Get lower actually usable tick given `tickToSellAt`
    int24 tick = getLowerUsableTick(tickToSellAt, key.tickSpacing);
    // Create a pending order
    pendingOrders[key.toId()][tick][zeroForOne] += inputAmount;

    // Mint claim tokens to user equal to their `inputAmount`
    uint256 positionId = getPositionId(key, tick, zeroForOne);
    claimTokensSupply[positionId] += inputAmount;
    _mint(msg.sender, positionId, inputAmount, "");

    // Depending on direction of swap, we select the proper input token
    // and request a transfer of those tokens to the hook contract
    address sellToken = zeroForOne
        ? Currency.unwrap(key.currency0)
        : Currency.unwrap(key.currency1);
    IERC20(sellToken).transferFrom(msg.sender, address(this), inputAmount);

    // Return the tick at which the order was actually placed
    return tick;
}

function cancelOrder(
    PoolKey calldata key,
    int24 tickToSellAt,
    bool zeroForOne,
    uint256 amountToCancel
) external {
    // Get lower actually usable tick for their order
    int24 tick = getLowerUsableTick(tickToSellAt, key.tickSpacing);
    uint256 positionId = getPositionId(key, tick, zeroForOne);

    // Check how many claim tokens they have for this position
    uint256 positionTokens = balanceOf(msg.sender, positionId);
    if (positionTokens < amountToCancel) revert NotEnoughToClaim();

    // Remove their `amountToCancel` worth of position from pending orders
    pendingOrders[key.toId()][tick][zeroForOne] -= amountToCancel;
    // Reduce claim token total supply and burn their share
    claimTokensSupply[positionId] -= amountToCancel;
    _burn(msg.sender, positionId, amountToCancel);

    // Send them their input token
    Currency token = zeroForOne ? key.currency0 : key.currency1;
    token.transfer(msg.sender, amountToCancel);
}

function swapAndSettleBalances(
    PoolKey calldata key,
    IPoolManager.SwapParams memory params
) internal returns (BalanceDelta) {
    // Conduct the swap inside the Pool Manager
    BalanceDelta delta = poolManager.swap(key, params, "");

    // If we just did a zeroForOne swap
    // We need to send Token 0 to PM, and receive Token 1 from PM
    if (params.zeroForOne) {
        // Negative Value => Money leaving user's wallet
        // Settle with PoolManager
        if (delta.amount0() < 0) {
            _settle(key.currency0, uint128(-delta.amount0()));
        }

        // Positive Value => Money coming into user's wallet
        // Take from PM
        if (delta.amount1() > 0) {
            _take(key.currency1, uint128(delta.amount1()));
        }
    } else {
        if (delta.amount1() < 0) {
            _settle(key.currency1, uint128(-delta.amount1()));
        }

        if (delta.amount0() > 0) {
            _take(key.currency0, uint128(delta.amount0()));
        }
    }

    return delta;
}

function _settle(Currency currency, uint128 amount) internal {
    // Transfer tokens to PM and let it know
    poolManager.sync(currency);
    currency.transfer(address(poolManager), amount);
    poolManager.settle();
}

function _take(Currency currency, uint128 amount) internal {
    // Take tokens out of PM to our hook contract
    poolManager.take(currency, address(this), amount);
}

function executeOrder(
    PoolKey calldata key,
    int24 tick,
    bool zeroForOne,
    uint256 inputAmount
) internal {
    // Do the actual swap and settle all balances
    BalanceDelta delta = swapAndSettleBalances(
        key,
        IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            // We provide a negative value here to signify an "exact input for output" swap
            amountSpecified: -int256(inputAmount),
            // No slippage limits (maximum slippage possible)
            sqrtPriceLimitX96: zeroForOne
                ? TickMath.MIN_SQRT_PRICE + 1
                : TickMath.MAX_SQRT_PRICE - 1
        })
    );

    // `inputAmount` has been deducted from this position
    pendingOrders[key.toId()][tick][zeroForOne] -= inputAmount;
    uint256 positionId = getPositionId(key, tick, zeroForOne);
    uint256 outputAmount = zeroForOne
        ? uint256(int256(delta.amount1()))
        : uint256(int256(delta.amount0()));

    // `outputAmount` worth of tokens now can be claimed/redeemed by position holders
    claimableOutputTokens[positionId] += outputAmount;
}

function redeem(
    PoolKey calldata key,
    int24 tickToSellAt,
    bool zeroForOne,
    uint256 inputAmountToClaimFor
) external {
    // Get lower actually usable tick for their order
    int24 tick = getLowerUsableTick(tickToSellAt, key.tickSpacing);
    uint256 positionId = getPositionId(key, tick, zeroForOne);

    // If no output tokens can be claimed yet i.e. order hasn't been filled
    // throw error
    if (claimableOutputTokens[positionId] == 0) revert NothingToClaim();

    // they must have claim tokens >= inputAmountToClaimFor
    uint256 positionTokens = balanceOf(msg.sender, positionId);
    if (positionTokens < inputAmountToClaimFor) revert NotEnoughToClaim();

    uint256 totalClaimableForPosition = claimableOutputTokens[positionId];
    uint256 totalInputAmountForPosition = claimTokensSupply[positionId];

    // outputAmount = (inputAmountToClaimFor * totalClaimableForPosition) / (totalInputAmountForPosition)
    uint256 outputAmount = inputAmountToClaimFor.mulDivDown(
        totalClaimableForPosition,
        totalInputAmountForPosition
    );

    // Reduce claimable output tokens amount
    // Reduce claim token total supply for position
    // Burn claim tokens
    claimableOutputTokens[positionId] -= outputAmount;
    claimTokensSupply[positionId] -= inputAmountToClaimFor;
    _burn(msg.sender, positionId, inputAmountToClaimFor);

    // Transfer output tokens
    Currency token = zeroForOne ? key.currency1 : key.currency0;
    token.transfer(msg.sender, outputAmount);
}

}

