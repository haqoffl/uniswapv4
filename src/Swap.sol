// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import { UniversalRouter } from "../lib/universal-router/contracts/UniversalRouter.sol";
//import { IPermit2 } from "../lib/permit2/contracts/interfaces/IPermit2.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
contract Swap{
UniversalRouter public immutable universalRouter;
constructor(address _universalRouter){
    universalRouter = UniversalRouter(_universalRouter);
}

function swapForExactInput(address ) public{
}
}
