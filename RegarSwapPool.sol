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
 * @dev A liquidity pool contract enabling automated token swaps, liquidity provision, and share tracking.
 */
contract RegarSwapPool {
    address public owner;

    // --- STATE VARIABLES FOR LP TOKEN SPECIFICATIONS ---
    string public constant name = "Regar LP Token";
    string public constant symbol = "RGR-LP";
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    // Global events recognized by any blockchain explorer
    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event LiquidityDeposited(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );

    event LiquidityWithdrawn(
        address indexed recipient,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    );

    event Transfer(address indexed from, address indexed to, uint256 value);

    // Modifier to restrict access to the contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Authorization Error: Only owner can execute this function");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // --- INTERNAL ERC-20 UTILITIES FOR LP TOKEN MINTING AND BURNING ---
    function _mint(address _to, uint256 _amount) internal {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
        emit Transfer(address(0), _to, _amount);
    }

    function _burn(address _from, uint256 _amount) internal {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
        emit Transfer(_from, address(0), _amount);
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
     * @dev Allows users to add liquidity to the pool. 
     * Computes optimal share allocation based on Constant Product invariant mechanisms.
     */
    function addLiquidity(
        address _tokenA, 
        address _tokenB, 
        uint256 _amountADesired, 
        uint256 _amountBDesired
    ) external returns (uint256 shares) {
        IERC20 tokenA = IERC20(_tokenA);
        IERC20 tokenB = IERC20(_tokenB);

        // Capture current reserve values BEFORE pulling inbound tokens
        uint256 reserveA = tokenA.balanceOf(address(this));
        uint256 reserveB = tokenB.balanceOf(address(this));

        // Pull respective asset allocations from user workspace
        require(tokenA.transferFrom(msg.sender, address(this), _amountADesired), "Blockchain Error: Token A deposit failed");
        require(tokenB.transferFrom(msg.sender, address(this), _amountBDesired), "Blockchain Error: Token B deposit failed");

        if (totalSupply == 0) {
            // Initial pool setup configuration uses geometric mean calculation
            shares = _sqrt(_amountADesired * _amountBDesired);
        } else {
            // Standard ratio matching algorithms to ensure proportional fairness
            uint256 sharesA = (_amountADesired * totalSupply) / reserveA;
            uint256 sharesB = (_amountBDesired * totalSupply) / reserveB;
            shares = _min(sharesA, sharesB);
        }

        require(shares > 0, "Liquidity Error: Minted pool shares value too low");
        
        // Distribute newly minted LP receipt assets directly to provider
        _mint(msg.sender, shares);

        emit LiquidityDeposited(msg.sender, _amountADesired, _amountBDesired, shares);
    }

    /**
     * @dev Removes liquidity from the pool by burning the specified LP shares.
     * Reclaims original token values proportionally to the sender address.
     */
    function removeLiquidity(
        address _tokenA, 
        address _tokenB, 
        uint256 _shares
    ) external returns (uint256 amountA, uint256 amountB) {
        require(balanceOf[msg.sender] >= _shares, "Liquidity Error: Insufficient LP shares balance");

        IERC20 tokenA = IERC20(_tokenA);
        IERC20 tokenB = IERC20(_tokenB);

        uint256 reserveA = tokenA.balanceOf(address(this));
        uint256 reserveB = tokenB.balanceOf(address(this));

        // Resolve underlying token amounts mathematically based on burn targets
        amountA = (_shares * reserveA) / totalSupply;
        amountB = (_shares * reserveB) / totalSupply;

        require(amountA > 0 && amountB > 0, "Liquidity Error: Resolved withdrawal amounts are invalid");

        // Destroy tracking assets prior to distribution
        _burn(msg.sender, _shares);

        // Issue primary asset payload segments back to caller
        require(tokenA.transfer(msg.sender, amountA), "Blockchain Error: Token A refund transfer failed");
        require(tokenB.transfer(msg.sender, amountB), "Blockchain Error: Token B refund transfer failed");

        emit LiquidityWithdrawn(msg.sender, amountA, amountB, _shares);
    }

    /**
     * @dev Emergency recovery routine allowing the platform owner to safely sweep pool components.
     */
    function withdrawToken(address _token, uint256 _amount) external onlyOwner {
        uint256 currentBalance = IERC20(_token).balanceOf(address(this));
        require(currentBalance >= _amount, "Liquidity Error: Request exceeds available pool balance");
        
        bool success = IERC20(_token).transfer(owner, _amount);
        require(success, "Blockchain Error: Withdrawal process failed.");
    }

    // --- MATHEMATICAL UTILITIES ---
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return x < y ? x : y;
    }
}
