// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";


contract PointsHook is BaseHook,ERC20{
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    constructor(IPoolManager _manager,string memory _name,string memory _symbol) BaseHook(_manager) ERC20(_name, _symbol, 18) {

        }

         function getHookPermissions()public pure override returns (Hooks.Permissions memory){
        return Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: true,
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

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata swapParams, BalanceDelta delta, bytes calldata hookData) external override onlyPoolManager returns (bytes4,int128) {
            if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, 0);
            if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);
            uint256 ethSpendAmount = uint256(int256(-delta.amount0()));
            uint256 pointsForSwap = ethSpendAmount / 5;
            _assignPoints(hookData, pointsForSwap);
            return (this.afterSwap.selector, 0);
    }

    function afterAddLiquidity(address,PoolKey calldata key,IPoolManager.ModifyLiquidityParams calldata,BalanceDelta delta,BalanceDelta,bytes calldata hookData) external override onlyPoolManager returns (bytes4, BalanceDelta) {
            if (!key.currency0.isAddressZero()) return (this.afterSwap.selector, delta);
            uint256 pointsForAddingLiquidity = uint256(int256(-delta.amount0()));
            _assignPoints(hookData, pointsForAddingLiquidity);
            return (this.afterAddLiquidity.selector, delta);
    }

    function _assignPoints(bytes calldata hookData, uint256 points) internal {
    if (hookData.length == 0) return;
    address user = abi.decode(hookData, (address));
    if (user == address(0)) return;
    _mint(user, points);
    }
}
