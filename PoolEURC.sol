// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract ArchielSwapPool {
    address public tokenA;
    address public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidityOf;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 shares);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 shares);
    event SwapExecuted(address indexed trader, address indexed tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_tokenA != _tokenB, "Tokens must be different");
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function addLiquidity(
        address _tokenInA,
        address _tokenInB,
        uint256 _amountADesired,
        uint256 _amountBDesired
    ) external returns (uint256 shares) {
        require(
            (_tokenInA == tokenA && _tokenInB == tokenB) || (_tokenInA == tokenB && _tokenInB == tokenA),
            "Tokens do not match pool pair"
        );

        uint256 amountA = _tokenInA == tokenA ? _amountADesired : _amountBDesired;
        uint256 amountB = _tokenInA == tokenA ? _amountBDesired : _amountADesired;

        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer of tokenA failed");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer of tokenB failed");

        if (totalLiquidity == 0) {
            shares = amountA + amountB;
        } else {
            uint256 shareA = (amountA * totalLiquidity) / reserveA;
            uint256 shareB = (amountB * totalLiquidity) / reserveB;
            shares = shareA < shareB ? shareA : shareB;
        }

        require(shares > 0, "Shares cannot be zero");

        liquidityOf[msg.sender] += shares;
        totalLiquidity += shares;

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, shares);
    }

    function swap(address _tokenIn, uint256 _amountIn, uint256 _amountOutMin) external returns (uint256 amountOut) {
        require(_tokenIn == tokenA || _tokenIn == tokenB, "Invalid token for this pool");
        require(_amountIn > 0, "Input amount must be greater than zero");

        bool isTokenA = _tokenIn == tokenA;
        (uint256 reserveIn, uint256 reserveOut) = isTokenA ? (reserveA, reserveB) : (reserveB, reserveA);
        address tokenOut = isTokenA ? tokenB : tokenA;

        require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), "Transfer of input token failed");

        // AMM Formula: x * y = k with a 0.3% fee
        uint256 amountInWithFee = _amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;

        require(amountOut >= _amountOutMin, "Slippage limit exceeded");

        if (isTokenA) {
            reserveA += _amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += _amountIn;
            reserveA -= amountOut;
        }

        require(IERC20(tokenOut).transfer(msg.sender, amountOut), "Transfer of output token failed");

        emit SwapExecuted(msg.sender, _tokenIn, _amountIn, amountOut);
    }

    function getAmountOut(address _tokenIn, uint256 _amountIn) external view returns (uint256) {
        require(_tokenIn == tokenA || _tokenIn == tokenB, "Invalid token");
        bool isTokenA = _tokenIn == tokenA;
        (uint256 reserveIn, uint256 reserveOut) = isTokenA ? (reserveA, reserveB) : (reserveB, reserveA);

        uint256 amountInWithFee = _amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }
}