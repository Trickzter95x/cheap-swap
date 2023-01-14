// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICheapswapFactory.sol";
import "./CheapswapPair.sol";

contract CheapswapFactory is ICheapswapFactory {
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(CheapswapPair).creationCode));

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;
    address public feeTaker;

    constructor() { 
        feeTaker = msg.sender;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB, address tokenFeeOwner) external returns (address pair) {
        require(tokenA != tokenB, 'CS: EQ_ADDR');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'CS: ZERO_ADDR');
        require(getPair[token0][token1] == address(0), 'Pancake: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(CheapswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ICheapswapPair(pair).initialize(token0, token1, tokenFeeOwner);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTaker(address _feeTaker) external {
        require(msg.sender == feeTaker, "CheapswapFactory: INVLD_FT");
        feeTaker = _feeTaker;
    }
}