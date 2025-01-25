// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {V4} from "../src/V4.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from  "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DeployPermit2} from "permit2/test/utils/DeployPermit2.sol";
import {PoolKey,Currency} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

contract V4Test is Test, DeployPermit2{
    V4 public v4;
    address public _psm = 0xf969Aee60879C54bAAed9F3eD26147Db216Fd664; //position manager
    address public immutable USDC = 0x31d0220469e10c4E71834a79b1f276d740d3768F;
    address public immutable DAI = 0xF6F75aF04a6dc552c00f9D7022453DbFfBd0E6AE;
    address public  DAI_HOLDER;
    address public  USDC_HOLDER;
    address public contractAddress;
    address public john;
    address public permit2;
    address payable public  _router = payable(0xf70536B3bcC1bD1a972dc186A2cf84cC6da6Be5D);
    address public _poolManager = 0x00B036B58a818B1BC34d502D3fE730Db729e62AC;

    function setUp() public{
        string memory rpcUrl = vm.envString("UNI_SEPOLIA_RPC_URL");
        uint256 forkId = vm.createFork(rpcUrl);
        vm.selectFork(forkId);
        john = vm.addr(1);
        DAI_HOLDER = 0xF1D9236cf239C58384405cD79bA8775A242B420d;
        USDC_HOLDER = 0xca8cA8840c77589981E63f4D8122fFEc4b74e2a1;
        vm.prank(john);
        v4 = new V4(_psm,_router,_poolManager,permit2);
        contractAddress = address(v4);
        console.log("address of contract: ",address(v4));
        permit2 = deployPermit2();
        console.log("address of permit2: ",address(permit2));


        //send USDC and DAI to contract
        vm.prank(DAI_HOLDER);
        IERC20 dai = IERC20(DAI);
        dai.approve(contractAddress, 1200);
        vm.prank(USDC_HOLDER);
        IERC20 usdc = IERC20(USDC);
        usdc.approve(contractAddress, 1200);
        vm.prank(DAI_HOLDER);
        v4.depositTokenInContract(DAI,1000);
        vm.prank(USDC_HOLDER);
        v4.depositTokenInContract(USDC, 1000);
        
    }

    function test_getBalanceOfContract() public{
            vm.prank(DAI_HOLDER);
          uint256 balance = v4.contractBalance(DAI);
        console.log("balance of DAI: ",balance);
        uint balance1 = v4.contractBalance(USDC);
        console.log("balance of USDC: ",balance1);
        assertTrue(true);
    }

 function test_createPoolAndMintPositionWithoutHook()public{
    vm.prank(john);
     address currency0 = uint160(DAI) < uint160(USDC) ? DAI : USDC;
     address currency1 = uint160(DAI) < uint160(USDC) ? USDC : DAI;
     uint24 lpFee = 100;
     int24 tickSpacing = 1;
     address hookContract = address(0); // Cast to IHooks
     uint160 sqrtStartPriceX96 = 79228162514264337593543950336;
     uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(TickMath.MIN_TICK); //lower price of pair at tick
     uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(TickMath.MAX_TICK); //upper price of pair at tick
     uint256 amount0 = 100;
     uint256 amount1 = 100;
     uint128 amount0Max = 110;
     uint128 amount1Max = 110;
     bytes memory hookData = bytes("");
    uint128 liq = v4.getLiquidityForAmount(sqrtStartPriceX96, sqrtPriceAX96, sqrtPriceBX96, amount0, amount1);
    uint nextTokenID = v4.getNextTokenId();
    console.log("nextTokenID before creating pool: ",nextTokenID);
     v4.createPool(currency0,currency1,lpFee,tickSpacing,hookContract,sqrtStartPriceX96);
     nextTokenID = v4.getNextTokenId();
     console.log("nextTokenID after creating pool but before mint: ",nextTokenID);
    v4.mintPosition(currency0, currency1,lpFee,tickSpacing,hookContract,liq, amount0Max, amount1Max, hookData,permit2);
     nextTokenID = v4.getNextTokenId();
     console.log("nextTokenID after mint: ",nextTokenID);
     uint currentTokenId = v4.getTokenId(0);
     console.log("tokenId of position: ",currentTokenId);
     //getting contract balance after minting position
     uint balance = v4.contractBalance(DAI);
     uint balance1 = v4.contractBalance(USDC);
     console.log("balance of DAI: ",balance);
     console.log("balance of USDC: ",balance1);
     console.log("liq: ",liq);
     console.log("liquidity of pool before increase: ",v4.getLiquidityOfPool(currentTokenId));
     //v4.increaseLiquidityDefault(currency0, currency1,currentTokenId,liq, amount0Max, amount1Max, hookData); // increasing liquidity(default)
     v4.increaseLiquidityAndCollectFee(currency0, currency1,currentTokenId,liq, amount0Max, amount1Max, hookData); //increasing liquidity and collecting fee
    // v4.increaseLiquidityAndIgnoreDust(currency0, currency1,currentTokenId,liq, amount0Max, amount1Max, hookData); //increasing liquidity and ignoring dust
     console.log("liquidity of pool after increase: ",v4.getLiquidityOfPool(currentTokenId));
     console.log("balance of DAI",v4.contractBalance(DAI));
     console.log("balance of USDC",v4.contractBalance(USDC));
   //  v4.decreaseLiquidityAndCollectFee(currency0,currency1,currentTokenId,liq,0,0, hookData);
   v4.decreaseLiquidity(currency0, currency1,currentTokenId,liq,0,0,50,50,hookData);
    console.log("liquidity of pool after decrease: ",v4.getLiquidityOfPool(currentTokenId));
     console.log("balance of DAI",v4.contractBalance(DAI));
     console.log("balance of USDC",v4.contractBalance(USDC));
  

     PoolKey memory key = PoolKey({
    currency0: Currency.wrap(currency0),
    currency1: Currency.wrap(currency1),
    fee: lpFee,
    tickSpacing: tickSpacing,
    hooks: IHooks(hookContract)
    });


    uint128 amountIn = 100;
    uint128 minAmountOut = 100;
    console.log("balance of DAI before swap",v4.contractBalance(DAI));
     console.log("balance of USDC before swap",v4.contractBalance(USDC));
     v4.ExactInputSwapSingle(currency0,currency1,50,50,60,key,2,0,permit2);
    console.log("balance of DAI after swap",v4.contractBalance(DAI));
     console.log("balance of USDC after swap",v4.contractBalance(USDC));
     assertTrue(true);
 }


// function test_createPoolAndMintPositionWithHook()public{
//      vm.prank(john);
//      address currency0 = uint160(DAI) < uint160(USDC) ? DAI : USDC;
//      address currency1 = uint160(DAI) < uint160(USDC) ? USDC : DAI;
//      uint24 lpFee = 100;
//      int24 tickSpacing = 1;
//      address hookContract = address(0); // Cast to IHooks
//      uint160 sqrtStartPriceX96 = 79228162514264337593543950336;
//      uint160 sqrtPriceAX96 = TickMath.getSqrtPriceAtTick(TickMath.MIN_TICK); //lower price of pair at tick
//      uint160 sqrtPriceBX96 = TickMath.getSqrtPriceAtTick(TickMath.MAX_TICK); //upper price of pair at tick
//      uint256 amount0 = 100;
//      uint256 amount1 = 100;
//      uint128 amount0Max = 100;
//      uint128 amount1Max = 100;
//      bytes memory hookData = bytes("");
//     uint128 liq = v4.getLiquidityForAmount(sqrtStartPriceX96, sqrtPriceAX96, sqrtPriceBX96, amount0, amount1);

//     v4.createPoolAndMintPosition(currency0,currency1,lpFee, tickSpacing, hookContract, sqrtStartPriceX96, liq, amount0Max, amount1Max, hookData, permit2);

//     //balance
//     uint balance = v4.contractBalance(DAI);
//     uint balance1 = v4.contractBalance(USDC);
//     console.log("balance of DAI: ",balance);
//     console.log("balance of USDC: ",balance1);
//     assertTrue(true);
// }
}



/*

formula for sqrtPriceX96 setting
let token0 = 500
let token1 = 500
let sqrt = Math.sqrt(token1/token0)
let sqrtPriceX96 = sqrt * (2**96)
console.log(BigInt(sqrtPriceX96))


*/