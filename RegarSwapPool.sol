// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @dev Interface for ERC20 standard token interactions.
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title RegarSwapPool
 * @dev A simple liquidity pool contract for execution of token swaps and liquidity management.
 */
contract RegarSwapPool {
    address public owner;

    // Global events recognized by any blockchain explorer
    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event LiquidityDeposited(
        address indexed token,
        address indexed provider,
        uint256 amount
    );

    event LiquidityWithdrawn(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );

    // Modifier to restrict access to the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Authorization Error: Only owner can execute this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev Executes a peer-to-contract swap between two ERC20 tokens.
     */
    function executeSwap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOut) external {
        require(_amountIn > 0, "Execution Error: Amount must be greater than zero");
        
        IERC20 tokenIn = IERC20(_tokenIn);
        IERC20 tokenOut = IERC20(_tokenOut);

        // 1. Pull user's inbound tokens into this contract liquidity pool
        bool successIn = tokenIn.transferFrom(msg.sender, address(this), _amountIn);
        require(successIn, "Blockchain Error: Token deposit failed. Check user balance and allowance.");

        // 2. Validate if this pool holds enough outbound liquidity to pay the user
        uint256 poolBalance = tokenOut.balanceOf(address(this));
        require(poolBalance >= _amountOut, "Liquidity Error: Insufficient funds inside the pool contract");

        // 3. Dispatch outbound tokens directly to the user's wallet address
        bool successOut = tokenOut.transfer(msg.sender, _amountOut);
        require(successOut, "Blockchain Error: Token payout failed.");

        emit SwapExecuted(msg.sender, _tokenIn, _tokenOut, _amountIn, _amountOut);
    }

    /**
     * @dev Allows the owner to inject liquidity into the pool via backend transferFrom.
     * Use this method to bypass native testnet token direct transfer restrictions.
     */
    function depositLiquidity(address _token, uint256 _amount) external {
        require(_amount > 0, "Execution Error: Deposit amount must be greater than zero");
        
        // Securely pull tokens using approved allowance pathways
        bool success = IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        require(success, "Liquidity Error: Secure deposit failed. Verify token allowance parameters.");
        
        emit LiquidityDeposited(_token, msg.sender, _amount);
    }

    /**
     * @dev Allows the contract owner to safely withdraw pool funds.
     */
    function withdrawToken(address _token, uint256 _amount) external onlyOwner {
        uint256 currentBalance = IERC20(_token).balanceOf(address(this));
        require(currentBalance >= _amount, "Liquidity Error: Request exceeds available pool balance");
        
        bool success = IERC20(_token).transfer(owner, _amount);
        require(success, "Blockchain Error: Withdrawal process failed.");
        
        emit LiquidityWithdrawn(_token, owner, _amount);
    }
}