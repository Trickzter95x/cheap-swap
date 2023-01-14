// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICheapswapFactory.sol";
import "./ICheapswapPair.sol";
import "./ICheapswapFlashloan.sol";
import "./CheapswapERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

contract FeeTracker {

    address public token0;
    address public token1;
    address public factory;
    address public userTokenFeeOwner;
    address public pair;
    uint112 public pairFeesClaimable0;
    uint112 public pairFeesClaimable1;

    constructor(
        address _token0, address _token1, 
        address _factory, address _userTokenFeeOwner) {
        token0 = _token0;
        token1 = _token1;
        factory = _factory;
        userTokenFeeOwner = _userTokenFeeOwner;
        pair = msg.sender;
    }

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Cheapswap: TRANSFER_FAILED');
    }

    event FeesClaimed(uint, uint);
    function claim(uint claim0, uint claim1, address to) public {
        require(msg.sender == userTokenFeeOwner, "Cheapswap: CLAIM");
        address pairFeeReceiver = ICheapswapFactory(factory).feeTaker();
        if(claim0 > 0){
            address _token0 = token0;
            uint112 _pairFeesClaimable0 = pairFeesClaimable0;
            _safeTransfer(_token0, to, claim0 - _pairFeesClaimable0);
            _safeTransfer(_token0, pairFeeReceiver, _pairFeesClaimable0);
            pairFeesClaimable0 = 0;
        }
        if(claim1 > 0) {
            address _token1 = token1;
            uint112 _pairFeesClaimable1 = pairFeesClaimable1;
            _safeTransfer(_token1, to, claim1 - _pairFeesClaimable1);
            _safeTransfer(_token1, pairFeeReceiver, _pairFeesClaimable1);
            pairFeesClaimable1 = 0;
        }
        emit FeesClaimed(claim0, claim1);
    }
    
    function claim(address to) external {
        uint token0Balance = IERC20(token0).balanceOf(address(this));
        uint token1Balance = IERC20(token1).balanceOf(address(this));
        claim(token0Balance, token1Balance, to);
    }

    function claimFeeTaker(address to) external {
        require(msg.sender == ICheapswapFactory(factory).feeTaker(), "Cheapswap: CLAIMFT");
        _safeTransfer(token0, to, pairFeesClaimable0);
        _safeTransfer(token1, to, pairFeesClaimable1);
        pairFeesClaimable0 = pairFeesClaimable1 = 0;
    }

    function addFeesClaimableToPair(uint112 claimable0, uint112 claimable1) external {
        require(msg.sender == pair, "Cheapswap: INVLD_SNDR");
        pairFeesClaimable0 += claimable0;
        pairFeesClaimable1 += claimable1;
    }

    // Allows the fee setter to withdraw any tokens sent to this contract except for fee tokens.
    // This ensures the fee setter can never withdraw fees that belong to the `userTokenFeeOwner`.
    function withdrawAnyButTokens(address token, address to, uint amount) external {
        require(token != token0 && token != token1, "Cheapswap: WTHDRW_INVLD_TKN");
        require(msg.sender == ICheapswapFactory(factory).feeTaker(), "Cheapswap: WITHDRW_INVLD_CLLR");
        _safeTransfer(token, to, amount);
    }
}

contract CheapswapPair is ICheapswapPair, CheapswapERC20 {

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public factory;
    address public token0;
    address public token1;
    address public userTokenFeeOwner;
    FeeTracker public feeTracker;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint8 private locked;
    uint16 private userTokenFees; // We save token0 and token1 fees in here with a granularity of 10000.

    modifier lock() {
        require(locked == 0, 'Cheapswap: LOCKED');
        locked = 1;
        _;
        locked = 0;
    }

    function getReserves() public view returns (uint112 _reserve0, uint112 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Cheapswap: TRANSFER_FAILED');
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1, address tokenFeeOwner) external {
        require(msg.sender == factory, 'Cheapswap: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
        userTokenFeeOwner = tokenFeeOwner;
        feeTracker = new FeeTracker(_token0, _token1, factory, tokenFeeOwner);
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1) private {
        require(balance0 <= ~uint112(0) && balance1 <= ~uint112(0), 'Cheapswap: OVERFLOW');
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) external lock returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves(); // gas savings
        uint balance0 = IERC20(token0).balanceOf(address(this));
        uint balance1 = IERC20(token1).balanceOf(address(this));
        uint amount0 = balance0 - _reserve0;
        uint amount1 = balance1 - _reserve1;

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - 10**3;
           _mint(address(0), 10**3); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(amount0 * _totalSupply / _reserve0, amount1 * _totalSupply / _reserve1);
        }
        require(liquidity > 0, 'Cheapswap: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external lock returns (uint amount0, uint amount1) {
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IERC20(_token0).balanceOf(address(this));
        uint balance1 = IERC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity * balance0 / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity * balance1 / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'Cheapswap: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    event UserTokenFeesUpdated(uint16);
    function setUserTokenFees(uint16 tokenFees) external {
        require(msg.sender == userTokenFeeOwner, "CS: UNAUTH_UTF");
        userTokenFees = tokenFees;
        emit UserTokenFeesUpdated(tokenFees);
    }

    function calculateFees(uint amount0In, uint amount1In) private view returns(
        uint amount0FeePair, uint amount0FeeToken, 
        uint amount1FeePair, uint amount1FeeToken) {
        uint16 pairBaseTax = 10; // token0 and token1 static 0.1%.
        uint16 tokenTax = userTokenFees; // Saves gas.
        // Our fee is a static 0.1% (very cheap!). Others commonly charge 0.2%-0.3% which is twice or more the amount.
        // Also 30% of 0.1% are held within this pair to incentivize people to fill the pool.
        // Additionally, if the token owner seeks to take fees 10% of those fees are also kept within the pool.
        // This is to ensure profits taken are also given to pool stakeholders (which is more fair, in our understanding).
        amount0FeePair = amount0In * pairBaseTax / 10000;
        amount1FeePair = amount1In * pairBaseTax / 10000;
        // token0 fees are saved within the first [0, 9990] interval of the data.
        amount0FeeToken = amount0In * (tokenTax % 9991) / 10000;
        // token1 fees are saved within the [10000, 19990] interval of the data.
        amount1FeeToken = (tokenTax > 10000 ? amount1In * ((tokenTax - 10000) % 9991) : 0) / 10000;
    }

    function processFees(uint amount0FeePair, uint amount0FeeToken, uint amount1FeePair, uint amount1FeeToken) private {
        // Only take 70% of our fees to cheapswap - remaining 30% stays in the pool.
        uint amount0FeePairTaken = amount0FeePair * 70 / 100;
        uint amount1FeePairTaken = amount1FeePair * 70 / 100;
        // If the token decides to take fees we will take 5% of those fees for cheapswap.
        // Beware: This does not increase fees for traders!
        if(amount0FeeToken > 0)
            amount0FeePairTaken += amount0FeePairTaken * 5 / 100;
        if(amount1FeeToken > 0)
            amount1FeePairTaken += amount1FeePairTaken * 5 / 100;
        
        _safeTransfer(token0, address(feeTracker), amount0FeePair + amount0FeeToken);
        _safeTransfer(token1, address(feeTracker), amount1FeePair + amount1FeeToken);
        feeTracker.addFeesClaimableToPair(uint112(amount0FeePairTaken), uint112(amount1FeePairTaken));
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        require(amount0Out > 0 || amount1Out > 0, 'Cheapswap: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'Cheapswap: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, 'Cheapswap: INVALID_TO');
        if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
        if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
        if (data.length > 0) ICheapswapFlashloan(to).flashloan(msg.sender, amount0Out, amount1Out, data);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'Cheapswap: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
        (uint amount0FeePair, uint amount0FeeToken, uint amount1FeePair, uint amount1FeeToken) = calculateFees(amount0In, amount1In);
        processFees(amount0FeePair, amount0FeeToken, amount1FeePair, amount1FeeToken);
        uint balance0Adjusted = balance0 - (amount0FeePair + amount0FeeToken);
        uint balance1Adjusted = balance1 - (amount1FeePair + amount1FeeToken);
        require(balance0Adjusted * balance1Adjusted >= uint(_reserve0) * _reserve1 * 10000**2, 'Cheapswap: K');
        }

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // Flashloan fast path.
    function flashloan(address to, uint amount0Out, uint amount1Out, bytes calldata data) external lock {
      address _token0 = token0;
      address _token1 = token1;
      uint _reserve0 = reserve0;
      uint _reserve1 = reserve1;
      if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out);
      if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out);
      ICheapswapFlashloan(to).flashloan(msg.sender, amount0Out, amount1Out, data);
      uint balance0 = IERC20(_token0).balanceOf(address(this));
      uint balance1 = IERC20(_token1).balanceOf(address(this));
      // Fees are 0.1% again.
      require(balance0 - _reserve0 >= amount0Out / 1000, "CS: FL0");
      require(balance1 - _reserve1 >= amount1Out / 1000, "CS: FL1");
      _update(balance0, balance1);
    }

    // force balances to match reserves
    function skim(address to) external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    // force reserves to match balances
    function sync() external lock {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }
}