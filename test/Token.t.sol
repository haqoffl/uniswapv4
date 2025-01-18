// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {IERC20} from "@openzeppelin-contracts/interfaces/IERC20.sol";
contract TokenTest is Test {
    Token public token;
    address public John;
    address public peter;
    function setUp() public {
        uint256 totalSupply = 100 * 10 ** 18; // Corrected total supply calculation
           John = vm.addr(1);
           peter = vm.addr(2);
        string memory rpcUrl = vm.envString("UNI_SEPOLIA_RPC_URL");
         uint256 forkId = vm.createFork(rpcUrl);
        vm.selectFork(forkId);
       // console.logAddress(John);
        //console.logAddress(peter);
        vm.prank(John);
        token = new Token("HAQ", "HQ", totalSupply);
        console.logAddress(address(token));


    }

    function test_getBalance()public view{
        uint256 balance = token.balanceOf(John);
        console.logUint(balance);
        assertEq(balance, 100 * 10 ** 18);
    }

    function test_getName() public view {
        string memory name = token.name();
        console.logString(name); // Use console2 for string logging
        console.log("addresss: ",address(token));
        assertEq(name, "HAQ");
    }

    function test_transfer() public{
        vm.prank(John);
        uint256 amount = 100000;
        token.transfer(peter, amount);
        console.logUint(token.balanceOf(peter));
        assert(token.balanceOf(peter) == amount);

        
    }

    function test_checkBalance()public view{
        IERC20 _token = IERC20(0x31d0220469e10c4E71834a79b1f276d740d3768F);
        address account = 0xca8cA8840c77589981E63f4D8122fFEc4b74e2a1;
        uint256 balance = _token.balanceOf(account);
        console.logUint(balance);
        assert(balance>0);
    }

    function test_transferUSDC()public{
        IERC20 _token = IERC20(0x31d0220469e10c4E71834a79b1f276d740d3768F);
        address account = 0xca8cA8840c77589981E63f4D8122fFEc4b74e2a1;
        uint256 amount = 100000;
        vm.deal(account, 1 ether);
        vm.prank(account);
        _token.transfer(John, amount);
        console.log("balance of john USDC: ",_token.balanceOf(John));
        console.log("balance of account USDC: ",_token.balanceOf(account));
        assert(_token.balanceOf(John) == amount);
    }
}
