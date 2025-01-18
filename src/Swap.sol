// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { UniversalRouter } from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import { IPermit2 } from "@uniswap/permit2/src/interfaces/IPermit2.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract Swap{
UniversalRouter public  immutable universalRouter;
IERC20 public immutable ierc20;
IPermit2 public immutable permit2;
constructor(address payable _universalRouter,address _token,address _permit2){
    universalRouter = UniversalRouter(_universalRouter);
    ierc20 = IERC20(_token);
    permit2 = IPermit2(_permit2);

}

function approveTokenWithPermit2(address _token,uint160 amount,uint48 expiration)public{
ierc20.approve(address(permit2),type(uint256).max);
permit2.approve(_token,address(universalRouter), amount, expiration);
}
}
