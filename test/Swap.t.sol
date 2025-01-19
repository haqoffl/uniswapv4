// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Test, console} from "forge-std/Test.sol";
import {Swap} from "../src/Swap.sol";

contract CounterTest is Test {
    Swap public swap;
    address payable UniversalRouter = payable(0x3A9D48AB9751398BbFa63ad67599Bb04e4BdF98b);
    address immutable token = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address immutable permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    function setUp() public {
        swap = new Swap(UniversalRouter,token,permit2);
        console.log(address(swap));
    }

    function testApproveTokenWithPermit2() public{
          vm.expectRevert();
        swap.approveTokenWithPermit2(token,1000,1);
        assertTrue(true);
    }
    


  
}
