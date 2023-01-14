// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IFeeTracker {

    function token0() external returns(address);
    function token1() external returns(address);
    function factory() external returns(address);
    function userTokenFeeOwner() external returns(address);
    function pair() external returns(address);
    function pairFeesClaimable0() external returns(uint112);
    function pairFeesClaimable1() external returns(uint112);

    event FeesClaimed(uint, uint);
    function claim(uint claim0, uint claim1, address to) external;
    function claim(address to) external;
    function claimFeeTaker(address to) external;
    function addFeesClaimableToPair(uint112 claimable0, uint112 claimable1) external;
    function withdrawAnyButTokens(address token, address to, uint amount) external;
}