// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICheapswapFactory.sol";
import "./ICheapswapPair.sol";
import "./ICheapswapFlashloan.sol";
import "./IFeeTracker.sol";
import "./CheapswapERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

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

contract FeeTracker is IFeeTracker {

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
        /*require(msg.sender == pair, "Cheapswap: INVLD_SNDR");
        pairFeesClaimable0 += claimable0;
        pairFeesClaimable1 += claimable1;*/
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

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint8 private locked;
    uint112 public userToken0Fees;
    uint112 public factoryToken0Fees;
    uint16 public userToken0Fee;
    uint112 public userToken1Fees;
    uint112 public factoryToken1Fees;
    uint16 public userToken1Fee;

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
        require(liquidity > 0, 'Cheapswap: ILM');
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
        require(amount0 > 0 && amount1 > 0, 'Cheapswap: ILB');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    event UserTokenFeesUpdated(uint16, uint16);
    function setUserTokenFees(uint16 tokenFee0, uint16 tokenFee1) external {
        require(msg.sender == userTokenFeeOwner, "CS: UNAUTH_UTF");
        require(tokenFee0 <= 9990 && tokenFee1 <= 9990, "CS: INVLD_FEES");
        userToken0Fee = tokenFee0;
        userToken1Fee = tokenFee1;
        emit UserTokenFeesUpdated(tokenFee0, tokenFee1);
    }

    event UserTokenFeeOwnerUpdated(address);
    function setUserTokenFeeOwner(address newFeeOwner) external {
        require(msg.sender == userTokenFeeOwner, "CS: UNAUTH_UTF");
        userTokenFeeOwner = newFeeOwner;
        emit UserTokenFeeOwnerUpdated(newFeeOwner);
    }

    // token0 and token1 static 0.1%. We keep 0.05% in the pool and 0.05% for cheapswap.
    // Our fee is a static 0.1% (very cheap!). Others commonly charge 0.2%-0.3% which is twice or more the amount.
    // Only take 50% of our fees to cheapswap - remaining 50% stays in the pool to incentivize people to fill the pool.
    uint8 private constant poolFee = 5;
    function calculateFees(uint amount0In, uint amount1In) private view returns(
        uint amount0FeeToken, uint amount1FeeToken, 
        uint amount0FeePool, uint amount1FeePool) {
        // This may overflow but requires an increadibly high number and therefore almost never happens.
        // The gas saved for every swap justifies this risk.
        unchecked {
            amount0FeePool = amount0In * poolFee / 10000;
            amount1FeePool = amount1In * poolFee / 10000;
            amount0FeeToken = amount0In * userToken0Fee / 10000;
            amount1FeeToken = amount1In * userToken1Fee / 10000;
        }
    }

    function processFees(uint amount0FeeToken, uint amount1FeeToken, uint amount0FeePool, uint amount1FeePool) private {
        // If the token decides to take fees we will take 10% of those fees for cheapswap.
        // Beware: This does not increase fees for traders!
        unchecked{
            if(amount0FeePool > 0){
                if(amount0FeeToken > 0){
                    uint extraToken0ForFactory = (amount0FeeToken / 10);
                    userToken0Fees += uint112(amount0FeeToken - extraToken0ForFactory);
                    factoryToken0Fees += uint112(amount0FeePool + extraToken0ForFactory);
                } else {
                    factoryToken0Fees += uint112(amount0FeePool);
                }
            }
            if(amount1FeePool > 0){
                if(amount1FeeToken > 0){
                    uint extraToken1ForFactory = (amount1FeeToken / 10);
                    userToken1Fees += uint112(amount1FeeToken - extraToken1ForFactory);
                    factoryToken1Fees += uint112(amount1FeePool + extraToken1ForFactory);
                } else {
                    factoryToken1Fees += uint112(amount1FeePool);
                }
            }
        }
    }


    // this low-level function should be called from a contract which performs important safety checks
    error IOA();
    error IL();
    error IT();
    error IIA();
    error K();
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external lock {
        if(amount0Out | amount1Out == 0) revert IOA();
        (uint _reserve0, uint _reserve1) = getReserves(); // gas savings
        if(amount0Out >= _reserve0 || amount1Out >= _reserve1) revert IL();
        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            if(to == _token0 || to == _token1) revert IT();
            
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) ICheapswapFlashloan(to).flashloan(msg.sender, amount0Out, amount1Out, data);
            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint amount0In;
        uint amount1In;
        unchecked {
            amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
            amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
            if(amount0In | amount1In == 0) revert IIA();
        }
        {
            (uint amount0FeeToken, uint amount1FeeToken, uint amount0FeePool, uint amount1FeePool) = calculateFees(amount0In, amount1In);
            processFees(amount0FeeToken, amount1FeeToken, amount0FeePool, amount1FeePool);
            uint balance0Adjusted = balance0 - (amount0FeeToken + amount0FeePool + amount0FeePool); // Additions are cheaper than multiplications.
            uint balance1Adjusted = balance1 - (amount1FeeToken + amount1FeePool + amount1FeePool);
            if(balance0Adjusted * balance1Adjusted < _reserve0 * _reserve1) revert K();
            _update(balance0, balance1);
        }
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    // Flashloan cheap path.
    function flashloan(address to, uint amount0Out, uint amount1Out, bytes calldata data) external lock {
      (uint _reserve0, uint _reserve1) = getReserves();
      address _token0 = token0;
      address _token1 = token1;
      if (amount0Out > 0) {
        if(amount0Out <= 999) revert IOA();
        if(amount0Out > _reserve0) revert IL();
        _safeTransfer(_token0, to, amount0Out);
      }
      if (amount1Out > 0) {
        if(amount1Out <= 999) revert IOA();
        if(amount1Out > _reserve1) revert IL();
        _safeTransfer(_token1, to, amount1Out);
      }
      ICheapswapFlashloan(to).flashloan(msg.sender, amount0Out * 1001 / 1000, amount1Out * 1001 / 1000, data);
      if (amount0Out > 0) {
        uint balanceGained0 = IERC20(_token0).balanceOf(address(this)) - _reserve0;
        if(balanceGained0 < amount0Out / 1000) revert IIA();
        factoryToken0Fees += uint112(balanceGained0 / 2);
      }
      if (amount1Out > 0) {
        uint balanceGained1 = IERC20(_token1).balanceOf(address(this)) - _reserve1;
        if(balanceGained1 < amount1Out / 1000) revert IIA();
        factoryToken1Fees += uint112(balanceGained1 / 2);
      }
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

    // Extra methods for fee takers.
    function claim(address to) external lock {
        require(msg.sender == userTokenFeeOwner, "Cheapswap: CLAIM");
        address pairFeeReceiver = ICheapswapFactory(factory).feeTaker();
        uint _userToken0Fees = userToken0Fees;
        uint _userToken1Fees = userToken1Fees;
        if(_userToken0Fees > 0){
            address _token0 = token0;
            _safeTransfer(_token0, to, _userToken0Fees);
            _safeTransfer(_token0, pairFeeReceiver, factoryToken0Fees);
            userToken0Fees = factoryToken0Fees = 0;
        }
        if(_userToken1Fees > 0) {
            address _token1 = token1;
            _safeTransfer(_token1, to, _userToken1Fees);
            _safeTransfer(_token1, pairFeeReceiver, factoryToken1Fees);
            userToken1Fees = factoryToken1Fees = 0;
        }
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
        emit FeesClaimed(_userToken0Fees, _userToken1Fees);
    }

    event FactoryFeesClaimed(uint, uint);
    function claimFeeTaker(address to) external lock {
        require(msg.sender == ICheapswapFactory(factory).feeTaker(), "Cheapswap: CLAIMFT");
        uint _factoryToken0Fees = factoryToken0Fees;
        uint _factoryToken1Fees = factoryToken1Fees;
        if(_factoryToken0Fees > 0) _safeTransfer(token0, to, _factoryToken0Fees);
        if(_factoryToken1Fees > 0) _safeTransfer(token1, to, _factoryToken1Fees);
        factoryToken0Fees = factoryToken1Fees = 0;
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
        emit FactoryFeesClaimed(_factoryToken0Fees, _factoryToken1Fees);
    }
}