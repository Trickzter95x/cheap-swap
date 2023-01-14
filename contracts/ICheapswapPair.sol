// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./IFeeTracker.sol";

interface ICheapswapPair {
    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address, address) external;

    // Additional cheapswap functionality.
    function setUserTokenFees(uint16 tokenFees) external;
    function flashloan(address to, uint amount0Out, uint amount1Out, bytes calldata data) external;
    function userTokenFeeOwner() external returns(address);
    function feeTracker() external returns(IFeeTracker);
}