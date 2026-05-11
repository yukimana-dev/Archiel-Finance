// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RegarStaking is Ownable {
    IERC20 public regarToken;
    
   
    
    // Deklarasikan variabel tanpa mengisi nilai di sini
    uint256 public rewardRate; 

    mapping(address => uint256) public stakedAmount;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public rewards;

    constructor(address _regarToken) Ownable(msg.sender) {
        regarToken = IERC20(_regarToken);
        // Isi nilainya di dalam constructor agar tidak terjadi error konversi tipe
        rewardRate = uint256(100 * 1e18) / 86400;
    }

    // Fungsi untuk menghitung reward yang sudah terkumpul
    function earned(address _account) public view returns (uint256) {
        uint256 duration = block.timestamp - lastUpdateTime[_account];
        return rewards[_account] + (stakedAmount[_account] * duration * rewardRate / 1e18);
    }

    // Mengunci Token
    function stake(uint256 _amount) external {
        require(_amount > 0, "Jumlah harus lebih dari 0");
        rewards[msg.sender] = earned(msg.sender);
        lastUpdateTime[msg.sender] = block.timestamp;
        
        stakedAmount[msg.sender] += _amount;
        regarToken.transferFrom(msg.sender, address(this), _amount);
    }

    // Menarik Token dan Hadiah
    function withdraw(uint256 _amount) external {
        require(_amount <= stakedAmount[msg.sender], "Saldo staking tidak cukup");
        rewards[msg.sender] = earned(msg.sender);
        lastUpdateTime[msg.sender] = block.timestamp;

        stakedAmount[msg.sender] -= _amount;
        regarToken.transfer(msg.sender, _amount);
    }

    // Mengambil Hadiah saja
    function claimReward() external {
        uint256 reward = earned(msg.sender);
        require(reward > 0, "Tidak ada hadiah");
        
        rewards[msg.sender] = 0;
        lastUpdateTime[msg.sender] = block.timestamp;
        regarToken.transfer(msg.sender, reward);
    }
}