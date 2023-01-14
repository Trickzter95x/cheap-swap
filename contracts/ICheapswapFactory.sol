
interface ICheapswapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTaker() external view returns(address);
    function setFeeTaker(address _feeTaker) external;

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB, address tokenFeeOwner) external returns (address pair);

}