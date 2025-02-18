// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";
import  {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
contract CSMM is BaseHook{
	using CurrencySettler for Currency;
    using CurrencyLibrary for Currency;
    error AddLiquidityThroughHook();
    error removeLiquidityThroughHook();
    constructor(IPoolManager _poolManager) BaseHook(_poolManager){}
    struct CallbackData {
    uint256 amountEach; // Amount of each token to add as liquidity
    Currency currency0;
    Currency currency1;
    address sender;
    bool addLiquidity;
    }   

    function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
    CallbackData memory callbackData = abi.decode(data, (CallbackData));
    if(callbackData.addLiquidity){
    callbackData.currency0.settle(poolManager,callbackData.sender,callbackData.amountEach,false);
    callbackData.currency1.settle(poolManager,callbackData.sender,callbackData.amountEach,false);
    callbackData.currency0.take(poolManager,address(this),callbackData.amountEach,true);
    callbackData.currency1.take(poolManager,address(this),callbackData.amountEach,true);
    }else{
        require(poolManager.balanceOf(address(this),callbackData.currency0.toId()) >= callbackData.amountEach,"ISF");
        require(poolManager.balanceOf(address(this),callbackData.currency1.toId()) >= callbackData.amountEach,"ISF");
        callbackData.currency0.settle(poolManager,address(this),callbackData.amountEach,true);
        callbackData.currency1.settle(poolManager,address(this),callbackData.amountEach,true);
        callbackData.currency0.take(poolManager,address(this),callbackData.amountEach,false);
        callbackData.currency1.take(poolManager,address(this),callbackData.amountEach,false);


        
    }
    

    return "";


    }


    function getHookPermissions() public pure override returns (Hooks.Permissions memory){
            return Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

      function beforeAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        revert AddLiquidityThroughHook();
    }

        function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        revert removeLiquidityThroughHook();
    }


    	// Custom add liquidity function
    function addLiquidity(PoolKey calldata key, uint256 amountEach) external {
       poolManager.unlock(abi.encode(
            CallbackData(
                amountEach,
                key.currency0,
                key.currency1,
                msg.sender,
                true
            )
        ));

        
    }

    function removeLiquidity(PoolKey calldata key, uint256 amountEach) external {
        poolManager.unlock(abi.encode(
            CallbackData(
                amountEach,
                key.currency0,
                key.currency1,
                msg.sender,
                false
            )
        ));
    }
    

	function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
		    uint256 amountInOutPositive = params.amountSpecified > 0
        ? uint256(params.amountSpecified)
        : uint256(-params.amountSpecified);

          BeforeSwapDelta beforeSwapDelta = toBeforeSwapDelta(
        int128(-params.amountSpecified), // So `specifiedAmount` = +100
        int128(params.amountSpecified) // Unspecified amount (output delta) = -100
    );

    if (params.zeroForOne) {
        key.currency0.take(
            poolManager,
            address(this),
            amountInOutPositive,
            true
        );

        key.currency1.settle(
            poolManager,
            address(this),
            amountInOutPositive,
            true
        );
    } else {
        key.currency0.settle(
            poolManager,
            address(this),
            amountInOutPositive,
            true
        );
        key.currency1.take(
            poolManager,
            address(this),
            amountInOutPositive,
            true
        );
    }

    return (this.beforeSwap.selector, beforeSwapDelta, 0);
	}

    function balanceOfHooks(uint256 t0, uint256 t1)public view returns (uint256 token0,uint256 token1){
        uint token0Bal = poolManager.balanceOf(address(this),t0);
        uint token1Bal = poolManager.balanceOf(address(this),t1);
        return(token0Bal,token1Bal);

    }
}
