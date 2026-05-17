// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ArchielSwapPool {
    address public owner;

    event SwapExecuted(
        address indexed user, 
        address indexed tokenIn, 
        address indexed tokenOut, 
        uint256 amountIn, 
        uint256 amountOut
    );

    constructor() {
        owner = msg.sender;
    }

    function executeSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOut) external {
        require(_amountIn > 0, "Amount must be greater than zero");
        
        IERC20 tokenIn = IERC20(_tokenIn);
        IERC20 tokenOut = IERC20(_tokenOut);

        // 1. Pull user's token into this contract pool
        bool successIn = tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        require(successIn, "Token deposit failed. Check allowance.");

        // 2. Check if this pool has enough destination token balance
        uint256 poolBalance = tokenOut.balanceOf(address(this));
        require(poolBalance >= _amountOut, "Insufficient pool liquidity");

        // 3. Send destination token directly to user's wallet
        bool successOut = tokenOut.transfer(msg.sender, _amountOut);
        require(successOut, "Token payout failed");

        emit SwapExecuted(msg.sender, _tokenIn, _tokenOut, _amountIn, _amountOut);
    }

    function withdrawToken(address _token, uint256 _amount) external {
        require(msg.sender == owner, "Only owner can withdraw tokens");
        IERC20(_token).transfer(msg.sender, _amount);
    }
}