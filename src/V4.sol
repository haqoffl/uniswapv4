// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.14;

import {PoolKey,Currency} from "v4-core/src/types/PoolKey.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {IERC20} from  "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAllowanceTransfer} from "@uniswap/permit2/src/interfaces/IAllowanceTransfer.sol";
//import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
contract V4{
// inside a contract, test, or foundry script:
IPositionManager public immutable positionManager;
//PoolKey public immutable poolKey;
constructor(address _positionManager){
    positionManager = IPositionManager(_positionManager);
   // poolKey = _poolKey;
}

uint24 public index;
mapping(uint24=>uint256) public tokenIds;
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

function mintPosition(address _token0,address _token1,uint24 fee, int24 tickSpacing, address hook,uint256 liquidity, uint128 amount0Max, uint128 amount1Max, bytes memory hookData,address permit2) public returns (uint256 tokenId){

    bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
    bytes[] memory params = new bytes[](2);
    Currency currency0 = Currency.wrap(_token0); // tokenAddress1 = 0 for native ETH
    Currency currency1 = Currency.wrap(_token1);
    PoolKey memory poolKey = PoolKey(currency0, currency1, fee,tickSpacing, IHooks(hook)); //currency0,currency1,fee, tickSpacing, hook
    params[0] = abi.encode(poolKey, TickMath.MIN_TICK, TickMath.MAX_TICK, liquidity, amount0Max, amount1Max, address(this), hookData);
    params[1] = abi.encode(currency0, currency1);
    uint256 deadline = block.timestamp + 30 minutes;
    uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;
    IERC20(_token0).approve(permit2, type(uint256).max);
    IERC20(_token1).approve(permit2, type(uint256).max);

    IAllowanceTransfer(permit2).approve(_token0, address(positionManager), type(uint160).max, type(uint48).max);
    IAllowanceTransfer(permit2).approve(_token1, address(positionManager), type(uint160).max, type(uint48).max);
    
    positionManager.modifyLiquidities{value: valueToPass}(
    abi.encode(actions, params),
    deadline
    );
    uint256 tokenId = positionManager.nextTokenId();
    tokenIds[index] = (tokenId-1);
    index = index + 1;
    return tokenId;
}

function createPoolAndMintPosition(address _token0,address _token1,uint24 lpFee, int24 tickSpacing, address hookContract, uint160 sqrtStartPriceX96,uint256 liquidity, uint128 amount0Max, uint128 amount1Max, bytes memory hookData,address permit2) public{
    bytes[] memory params = new bytes[](2);
    Currency currency0 = Currency.wrap(_token0); // tokenAddress1 = 0 for native ETH
    Currency currency1 = Currency.wrap(_token1);
    PoolKey memory pool = PoolKey({
    currency0: currency0,
    currency1: currency1,
    fee: lpFee,
    tickSpacing: tickSpacing,
    hooks: IHooks(hookContract)
    });

    params[0] = abi.encodeWithSelector(
    positionManager.initializePool.selector,
    pool,
    sqrtStartPriceX96
    );

    bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
    bytes[] memory mintParams = new bytes[](2);
    mintParams[0] = abi.encode(pool, TickMath.MIN_TICK, TickMath.MAX_TICK, liquidity, amount0Max, amount1Max,address(this), hookData);
    mintParams[1] = abi.encode(pool.currency0, pool.currency1);
    uint256 deadline = block.timestamp + 30 minutes;
    params[1] = abi.encodeWithSelector(
    positionManager.modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
    );

    IERC20(_token0).approve(permit2, type(uint256).max);
    IERC20(_token1).approve(permit2, type(uint256).max);

    IAllowanceTransfer(permit2).approve(_token0, address(positionManager), type(uint160).max, type(uint48).max);
    IAllowanceTransfer(permit2).approve(_token1, address(positionManager), type(uint160).max, type(uint48).max);
    positionManager.multicall(params);
}
function getLiquidityForAmount(uint160 sqrtPriceX96,uint160 sqrtPriceAX96,uint160 sqrtPriceBX96,uint256 amount0,uint256 amount1) public pure returns (uint128 liquidity){
    uint128 liq = LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, amount0, amount1);
    return liq;
}

function depositTokenInContract(address token, uint256 amount) public{
    IERC20 erc20 = IERC20(token);
    erc20.transferFrom(msg.sender, address(this), amount);
}

function contractBalance(address token) public view returns(uint256){
    IERC20 erc20 = IERC20(token);
    return erc20.balanceOf(address(this));
}

function getNextTokenId() public view returns(uint256){
    uint nextTokenId = positionManager.nextTokenId();
    return nextTokenId;

}

function getTokenId(uint24 _index) public view returns(uint256){
    return tokenIds[_index];
}

function increaseLiquidityDefault(address token0, address token1,uint _tokenId,uint liquidity, uint128 amount0Max, uint128 amount1Max,bytes memory hookData) public{
    bytes memory actions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR));
    bytes[] memory params = new bytes[](2);
    params[0] = abi.encode(_tokenId, liquidity, amount0Max, amount1Max, hookData);
    Currency currency0 = Currency.wrap(token0); 
    Currency currency1 = Currency.wrap(token1);
    params[1] = abi.encode(currency0, currency1);
    uint256 deadline = block.timestamp + 60;

    uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;

    positionManager.modifyLiquidities{value: valueToPass}(
    abi.encode(actions, params),
    deadline
    );
}

function increaseLiquidityAndCollectFee(address token0, address token1,uint _tokenId,uint liquidity, uint128 amount0Max, uint128 amount1Max,bytes memory hookData) public{
    bytes memory actions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.CLOSE_CURRENCY), uint8(Actions.CLOSE_CURRENCY));
    bytes[] memory params = new bytes[](3);
    params[0] = abi.encode(_tokenId, liquidity, amount0Max, amount1Max, hookData);
    Currency currency0 = Currency.wrap(token0); // tokenAddress1 = 0 for native ETH
    Currency currency1 = Currency.wrap(token1);
    params[1] = abi.encode(currency0);
    params[2] = abi.encode(currency1);
    uint256 deadline = block.timestamp + 60;

    uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;

    positionManager.modifyLiquidities{value: valueToPass}(
    abi.encode(actions, params),
    deadline
    );
}

function increaseLiquidityAndIgnoreDust(address token0, address token1,uint _tokenId,uint liquidity, uint128 amount0Max, uint128 amount1Max,bytes memory hookData) public{
    bytes memory actions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.CLEAR_OR_TAKE), uint8(Actions.CLEAR_OR_TAKE));
    bytes[] memory params = new bytes[](3);
    params[0] = abi.encode(_tokenId, liquidity, amount0Max, amount1Max,hookData);
    Currency currency0 = Currency.wrap(token0); // tokenAddress1 = 0 for native ETH
    Currency currency1 = Currency.wrap(token1);
    params[1] = abi.encode(currency0, amount0Max);
    params[2] = abi.encode(currency1, amount1Max);

    uint256 deadline = block.timestamp + 60;

    uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;
    
    positionManager.modifyLiquidities{value: valueToPass}(
    abi.encode(actions, params),
    deadline
    );
}

function getLiquidityOfPool(uint256 _tokenId) public view returns(uint256){
    return positionManager.getPositionLiquidity(_tokenId);
}
}

/*
tick spacing
0.01%	100	    1
0.05%	500	    10
0.30%	3000	60
1.00%	10_000	200

*/