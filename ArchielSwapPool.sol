// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ArchielSwapPool {
    string public constant name = "Archiel LP Token";
    string public constant symbol = "ARCL-LP";
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    event LiquidityDeposited(address indexed provider, uint256 amountA, uint256 amountB, uint256 shares);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Swap Function (Generic for any token)
    function executeSwap(
        address _tokenIn, 
        address _tokenOut, 
        uint256 _amountIn, 
        uint256 _amountOut
    ) external {
        IERC20 tokenIn = IERC20(_tokenIn);
        IERC20 tokenOut = IERC20(_tokenOut);

        // Check if pool has enough liquidity
        require(tokenOut.balanceOf(address(this)) >= _amountOut, "Pool: Insufficient liquidity");

        // Execute transfers
        require(tokenIn.transferFrom(msg.sender, address(this), _amountIn), "Swap: Transfer In failed");
        require(tokenOut.transfer(msg.sender, _amountOut), "Swap: Transfer Out failed");
    }

    // Check Liquidity Reserve
    function getReserve(address _token) external view returns (uint256) {
        return IERC20(_token).balanceOf(address(this));
    }

    // Add Liquidity Function (Generic for any pair)
    function addLiquidity(
        address _tokenA, 
        address _tokenB, 
        uint256 _amountADesired, 
        uint256 _amountBDesired
    ) external returns (uint256 shares) {
        IERC20 tokenA = IERC20(_tokenA);
        IERC20 tokenB = IERC20(_tokenB);

        require(tokenA.transferFrom(msg.sender, address(this), _amountADesired), "Transfer A failed");
        require(tokenB.transferFrom(msg.sender, address(this), _amountBDesired), "Transfer B failed");

        if (totalSupply == 0) {
            shares = _sqrt(_amountADesired * _amountBDesired);
        } else {
            uint256 reserveA = tokenA.balanceOf(address(this)) - _amountADesired;
            uint256 reserveB = tokenB.balanceOf(address(this)) - _amountBDesired;
            shares = _min((_amountADesired * totalSupply) / reserveA, (_amountBDesired * totalSupply) / reserveB);
        }

        require(shares > 0, "Shares too low");
        _mint(msg.sender, shares);
        emit LiquidityDeposited(msg.sender, _amountADesired, _amountBDesired, shares);
    }

    function _mint(address _to, uint256 _amount) internal {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
        emit Transfer(address(0), _to, _amount);
    }

    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) { z = x; x = (y / x + x) / 2; }
        } else if (y != 0) { z = 1; }
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}