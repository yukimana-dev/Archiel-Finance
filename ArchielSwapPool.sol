// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ArchielSwapPool {
    address public owner;
    constructor() { owner = msg.sender; }
    modifier onlyOwner() { require(msg.sender == owner, "Hanya owner"); _; }

    // Fungsi Swap dengan hitungan otomatis
    function swap(address _tokenIn, address _tokenOut, uint256 _amountIn) external {
        uint256 reserveIn = IERC20(_tokenIn).balanceOf(address(this));
        uint256 reserveOut = IERC20(_tokenOut).balanceOf(address(this));
        uint256 amountOut = (reserveOut * _amountIn) / (reserveIn + _amountIn);
        
        require(amountOut > 0, "Input terlalu kecil");
        IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
        IERC20(_tokenOut).transfer(msg.sender, amountOut);
    }

    // Fungsi Withdraw jika ada kesalahan kirim
    function withdrawToken(address _token, uint256 _amount) external onlyOwner {
        IERC20(_token).transfer(msg.sender, _amount);
    }
}