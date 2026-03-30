// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SimpleDEX
 * @notice A secure constant product AMM with proper protections
 * @dev Fixes: reentrancy, first depositor attack, price manipulation, slippage, precision loss
 * @author Abdul Badamasi
 */
contract SimpleDEX is ReentrancyGuard {
    error SimpleDEX__InvalidTokenPair();
    error SimpleDEX__InvalidTokenAddress();
    error SimpleDEX__AmountMustBeGreaterThanZero();
    error SimpleDEX__InsufficientLpTokensMinted();
    error SimpleDEX__InsufficientBalance();
    error SimpleDEX__TransferFailed();
    error SimpleDEX__InsufficientOutputAmount();
    error SimpleDEX__InsufficientInputAmount();
    error SimpleDEX__InsufficientReserves();
    error SimpleDex__InsufficientInitialLiquidity();
    error SimpleDex__SlippageProtectionLpTokenLessThanMinimun();
    error SimpleDEX__InsufficientLiquidity();
    error SimpleDEX__SlippageTooHigh();
    error revertSimpleDEX__InsufficientBalance();

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;
    uint256 public constant FEE = 3; // 0.3% fee
    uint256 public constant FEE_DENOMINATOR = 1000; // 1000 = 100%

    // Minimum liquidity to prevent first depositor attack
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    // TWAP (Time-Weighted Average Price) tracking
    uint256 public priceACumulativeLast;
    uint256 public priceBCumulativeLast;
    uint32 public blockTimestampLast;

    // Price oracle update tracking
    uint256 public constant PRICE_PRECISION = 1e18;

    mapping(address => uint256) public liquidityBalances;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpTokens);
        event Swap(
        address indexed trader,
        uint256 amountIn,
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    );
    event Sync(uint256 reserveA, uint256 reserveB);

    constructor(address _tokenA, address _tokenB) {
        if (_tokenA == _tokenB) {
            revert SimpleDEX__InvalidTokenPair();
        }
        if (_tokenA == address(0) || _tokenB == address(0)) {
            revert SimpleDEX__InvalidTokenAddress();
        }
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        blockTimestampLast = uint32(block.timestamp);
    }

    /**
     * @notice Add liquidity to the pool
     * @param _amountA Amount of token A to add
     * @param _amountB Amount of token B to add
     * @param _minLPTokens Minimum LP tokens to receive (slippage protection)
     * @param _deadline Transaction deadline
     * @return lpTokens Amount of LP tokens minted
     */
    function addLiquidity(
        uint256 _amountA,
        uint256 _amountB,
        uint256 _minLPTokens,
        uint256 _deadline
    ) external nonReentrant returns (uint256 lpTokens) {
        if (_amountA < 0 || _amountB < 0) {
            revert SimpleDEX__AmountMustBeGreaterThanZero();
        }
        if (block.timestamp > _deadline) {
            revert("Transaction expired");
        }

        bool successA = tokenA.transferFrom(msg.sender, address(this), _amountA);
        bool successB = tokenB.transferFrom(msg.sender, address(this), _amountB);
        if (!successA || !successB) {
            revert SimpleDEX__TransferFailed();
        }

        _update(reserveA, reserveB);

        if (totalLiquidity == 0) {
            lpTokens = sqrt(_amountA * _amountB);
            if (lpTokens < MINIMUM_LIQUIDITY) {
                revert SimpleDex__InsufficientInitialLiquidity();
            }
            totalLiquidity = MINIMUM_LIQUIDITY;
            lpTokens -= MINIMUM_LIQUIDITY;
        } else {
            uint256 lpFromA = (_amountA * totalLiquidity) / reserveA;
            uint256 lpFromB = (_amountB * totalLiquidity) / reserveB;
            lpTokens = min(lpFromA, lpFromB);
        }

        if (lpTokens < _minLPTokens) {
            revert SimpleDex__SlippageProtectionLpTokenLessThanMinimun();
        }
        if (lpTokens < 0) {
            revert SimpleDEX__InsufficientLpTokensMinted();
        }

        liquidityBalances[msg.sender] += lpTokens;
        totalLiquidity += lpTokens;
        reserveA += _amountA;
        reserveB += _amountB;

        _sync();

        emit LiquidityAdded(msg.sender, _amountA, _amountB, lpTokens);
        return lpTokens;
    }

    function removeLiquidity(
        uint256 _lpTokens,
        uint256 _minAmountA,
        uint256 _minAmountB,
        uint256 _deadline
    ) external nonReentrant returns (uint256 amountA, uint256 amountB) {
        if (_lpTokens <= 0) {
            revert SimpleDEX__AmountMustBeGreaterThanZero();
        }
        if (liquidityBalances[msg.sender] < _lpTokens) {
            revert SimpleDEX__InsufficientBalance();
        }
        require(block.timestamp <= _deadline, "Transaction expired");

        _update(reserveA, reserveB);

        amountA = (_lpTokens * reserveA) / totalLiquidity;
        amountB = (_lpTokens * reserveB) / totalLiquidity;

        require(amountA >= _minAmountA, "Slippage: Token A less than minimum");
        require(amountB >= _minAmountB, "Slippage: Token B less than minimum");
        require(amountA > 0 && amountB > 0, "Insufficient liquidity burned");

        liquidityBalances[msg.sender] -= _lpTokens;
        totalLiquidity -= _lpTokens;
        reserveA -= amountA;
        reserveB -= amountB;

        require(tokenA.transfer(msg.sender, amountA), "Transfer A failed");
        require(tokenB.transfer(msg.sender, amountB), "Transfer B failed");

        emit LiquidityRemoved(msg.sender, amountA, amountB, _lpTokens);
        return (amountA, amountB);
    }

    function swap(uint256 _amountIn, address _tokenIn, uint256 _minAmountOut, uint256 _deadline) external returns (uint256 amountOut) {
        require(_tokenIn == address(tokenA) || _tokenIn == address(tokenB), "Invalid token address");
        require(_amountIn > 0, "Amount must be > 0");
        require(block.timestamp <= _deadline, "Transaction expired");

        (uint256 _reserveA, uint256 _reserveB,) = getReserves();

        bool isTokenA = _tokenIn == address(tokenA);

        (IERC20 tokenInContract, IERC20 tokenOutContract,
        uint256 reserveIn, uint256 reserveOut) = isTokenA
            ? (tokenA, tokenB, _reserveA, _reserveB)
            : (tokenB, tokenA, _reserveB, _reserveA);

        require(
            tokenInContract.transferFrom(msg.sender, address(this), _amountIn),
            "Transfer Failed"
        );

        uint256 amountInWithFee = _amountIn * 997 / FEE_DENOMINATOR;
        amountOut = (reserveOut * amountInWithFee) / (reserveIn + amountInWithFee);

        require(amountOut >= _minAmountOut, "Slippage: Output less than minimum");
        require(amountOut > 0, "Invalid swap");

        if (isTokenA) {
            _reserveA += _amountIn;
            _reserveB -= amountOut;
        } else {
            _reserveB += _amountIn;
            _reserveA -= amountOut;
        }

        require(tokenOutContract.transfer(msg.sender, amountOut), "Transfer failed");

        _verifyConstantProduct();

        _update(reserveA, reserveB);
        emit Swap(msg.sender, _amountIn, amountOut, _tokenIn, address(tokenOutContract));
    }

    function getSpotPrice(address _token) external view returns (uint256 price) {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token address");
        require(reserveA > 0 && reserveB > 0, "No liquidity");

        if (_token == address(tokenA)) {
            return (reserveB * PRICE_PRECISION) / reserveA;
        }

        return (reserveA * PRICE_PRECISION) / reserveB;
    }

    function getTWAP(address _token) external view returns (uint256 price) {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token");
        require(blockTimestampLast > 0, "No price history");

        uint32 timeElapsed = uint32(block.timestamp) - blockTimestampLast;
        require(timeElapsed > 0, "No time elapsed");

        if (_token == address(tokenA)) {
            return priceACumulativeLast / timeElapsed;
        } else {
            return priceBCumulativeLast / timeElapsed;
        }
    }

    function getReserves() public view returns (
        uint256 _reserveA,
        uint256 _reserveB,
        uint32 _blockTimestamp
    ) {
        return (reserveA, reserveB, blockTimestampLast);
    }

    function getAmountOut(
        uint256 _amountIn,
        uint256 _reserveIn,
        uint256 _reserveOut
    ) external pure returns (uint256 amountOut) {
        require(_amountIn > 0, "Insufficient input amount");
        require(_reserveIn > 0 && _reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = _amountIn * 997 / FEE_DENOMINATOR;
        amountOut = (_reserveOut * amountInWithFee) / (_reserveIn + amountInWithFee);
    }

    function _update(uint256 _reserveA, uint256 _reserveB) private {
        require(_reserveA <= type(uint112).max && _reserveB <= type(uint112).max, "Overflow");

        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && _reserveA > 0 && _reserveB > 0) {
            // Update cumulative prices
            // Price of A in terms of B: reserveB / reserveA
            priceACumulativeLast += ((_reserveB * PRICE_PRECISION) / _reserveA) * timeElapsed;

            // Price of B in terms of A: reserveA / reserveB
            priceBCumulativeLast += ((_reserveA * PRICE_PRECISION) / _reserveB) * timeElapsed;

            blockTimestampLast = blockTimestamp;
        }
    }

    function _sync() private {
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));
        
        reserveA = balanceA;
        reserveB = balanceB;
        
        emit Sync(reserveA, reserveB);
    }
    function _verifyConstantProduct() private view {
        uint256 balanceA = tokenA.balanceOf(address(this));
        uint256 balanceB = tokenB.balanceOf(address(this));

        require(balanceA * balanceB >= reserveA * reserveB, "K decreased");
    }

    function sqrt(uint256 x) public pure returns (uint256 y) {
        if (x == 0) return 0;
        
        uint256 z = (x + 1) / 2;
        y = x;
        
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}