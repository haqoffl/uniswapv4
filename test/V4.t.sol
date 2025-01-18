// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {V4} from "../src/V4.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";

contract V4Test is Test {
    V4 public v4;
    address public _psm = 0xf969Aee60879C54bAAed9F3eD26147Db216Fd664; //position manager
    address public john;
    address public immutable USDC = 0x31d0220469e10c4E71834a79b1f276d740d3768F;
    address public immutable DAI = 0xF6F75aF04a6dc552c00f9D7022453DbFfBd0E6AE;
    address public immutable DAI_HOLDER = 0xF1D9236cf239C58384405cD79bA8775A242B420d;
    address public immutable USDC_HOLDER = 0xca8cA8840c77589981E63f4D8122fFEc4b74e2a1;
    function setUp() public{
        string memory rpcUrl = vm.envString("UNI_SEPOLIA_RPC_URL");
        uint256 forkId = vm.createFork(rpcUrl);
        vm.selectFork(forkId);
        john = vm.addr(1);
        vm.prank(john);
        v4 = new V4(_psm);
        console.log("address of contract: ",address(v4));
    }


 function test_createPool()public{

    address currency0 = uint160(DAI) < uint160(USDC) ? DAI : USDC;
    address currency1 = uint160(DAI) < uint160(USDC) ? USDC : DAI;
     uint24 lpFee = 500;
     int24 tickSpacing = 10;
    IHooks hookContract = IHooks(address(0)); // Cast to IHooks
     uint160 sqrtStartPriceX96 = 79228162514264337593543950336;
     v4.createPool(currency0,currency1,lpFee,tickSpacing,hookContract,sqrtStartPriceX96);
 }

 function test_getLiquidityForAmount()public{
     uint160 sqrtPriceX96 = 79228162514264337593543950336;
     uint160 sqrtPriceAX96 = 79228162514264337593543950336;
     uint160 sqrtPriceBX96 = 79228162514264337593543950336;
     uint256 amount0 = 100;
     uint256 amount1 = 100;
     uint128 liq = v4.getLiquidityForAmount(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, amount0, amount1);
     console.logUint(liq);
 }

//  function test_mintPosition()public{
//     address currency0 = uint160(DAI) < uint160(USDC) ? DAI : USDC;
//     address currency1 = uint160(DAI) < uint160(USDC) ? USDC : DAI;
//      uint24 lpFee = 500;
//      int24 tickSpacing = 10;
//     IHooks hookContract = IHooks(address(0)); // Cast to IHooks
//      uint160 sqrtStartPriceX96 = 79228162514264337593543950336;
//      int24 tickLower = 0;
//      int24 tickUpper = 100;
//      uint256 liquidity = 1000;
//      uint128 amount0Max = 50;
//      uint128 amount1Max = 50;
//      bytes memory hookData = bytes(0);
//     // v4.createPool(currency0,currency1,lpFee,tickSpacing,hookContract,sqrtStartPriceX96);
//      v4.mintPosition(currency0, currency1, lpfee, tickSpacing, hookContract,liquidity, amount0Max, amount1Max, hookData);
//  }
}



/*

formula for sqrtPriceX96 setting
let token0 = 500
let token1 = 500
let sqrt = Math.sqrt(token1/token0)
let sqrtPriceX96 = sqrt * (2**96)
console.log(BigInt(sqrtPriceX96))


*/