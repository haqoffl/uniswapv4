// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;
import {Test,console} from "forge-std/Test.sol";
import {TakeProfitHook} from  "../src/TakeProfitHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

contract TakeProfitHookTest is Test,Deployers {

    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    TakeProfitHook hook;

    function setUp() external {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        uint160 flags = uint160(
        Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG
    );
        address hookAddress = address(flags);
        deployCodeTo("TakeProfitHook.sol",abi.encode(manager,""),hookAddress);

    hook = TakeProfitHook(hookAddress);

    MockERC20(Currency.unwrap(currency0)).approve(
        address(hook),
        type(uint256).max
    );

    MockERC20(Currency.unwrap(currency1)).approve(
        address(hook),
        type(uint256).max
     );

    (key, ) = initPool(
        currency0,
        currency1,
        hook,
        3000,
        SQRT_PRICE_1_1
    );

    // mint position -1
    modifyLiquidityRouter.modifyLiquidity(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 10 ether,
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );

//position 2
    modifyLiquidityRouter.modifyLiquidity(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: -120,
            tickUpper: 120,
            liquidityDelta: 10 ether,
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );
     
    modifyLiquidityRouter.modifyLiquidity(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: TickMath.minUsableTick(60),
            tickUpper: TickMath.maxUsableTick(60),
            liquidityDelta: 10 ether,
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );

    }


    function onERC1155Received(
    address,
    address,
    uint256,
    uint256,
    bytes calldata
) external pure returns (bytes4) {
    return this.onERC1155Received.selector;
}

function onERC1155BatchReceived(
    address,
    address,
    uint256[] calldata,
    uint256[] calldata,
    bytes calldata
) external pure returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
}

function test_placeOrder() public {
    // Place a zeroForOne take-profit order
    // for 10e18 token0 tokens
    // at tick 100
    int24 tick = 100;
    uint256 amount = 10e18;
    bool zeroForOne = true;

    // Note the original balance of token0 we have
    uint256 originalBalance = currency0.balanceOfSelf();

    // Place the order
    int24 tickLower = hook.placeOrder(key, tick, zeroForOne, amount);

    // Note the new balance of token0 we have
    uint256 newBalance = currency0.balanceOfSelf();

    // Since we deployed the pool contract with tick spacing = 60
    // i.e. the tick can only be a multiple of 60
    // the tickLower should be 60 since we placed an order at tick 100
    assertEq(tickLower, 60);

    // Ensure that our balance of token0 was reduced by `amount` tokens
    assertEq(originalBalance - newBalance, amount);

    // Check the balance of ERC-1155 tokens we received
    uint256 positionId = hook.getPositionId(key, tickLower, zeroForOne);
    uint256 tokenBalance = hook.balanceOf(address(this), positionId);

    // Ensure that we were, in fact, given ERC-1155 tokens for the order
    // equal to the `amount` of token0 tokens we placed the order for
    assertTrue(positionId != 0);
    assertEq(tokenBalance, amount);
}

function test_cancelOrder() public{
    //place the order
    uint tick = 100;
    uint inputAmount = 10e18;
    int24 nearest_tick = hook.placeOrder(key,100,true, inputAmount);
    console.log("nearest tick: ",nearest_tick);
    uint positionId = hook.getPositionId(key, nearest_tick, true);

    console.log("total claim of token in position",hook.claimTokensSupply(positionId));
    assertEq(hook.claimTokensSupply(positionId),inputAmount);
    console.log("positionId: ",positionId);

    //cancel the order
    hook.cancelOrder(key,100,true,inputAmount);
    console.log("total claim of token in position",hook.claimTokensSupply(positionId));
     assertEq(hook.claimTokensSupply(positionId),0);
}
}