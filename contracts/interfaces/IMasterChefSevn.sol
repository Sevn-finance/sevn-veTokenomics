// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMasterChefSevn{

    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }
    
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. SEVNs to distribute per block.
        uint256 lastRewardTimestamp; // Last block number that SEVNs distribution occurs.
        uint256 accSEVNPerShare; // Accumulated SEVNs per share, times 1e12. See below.
    }


    function userInfo(uint256 _pid, address _user) external view returns (IMasterChefSevn.UserInfo memory);

    function poolInfo(uint256 pid) external view returns (IMasterChefSevn.PoolInfo memory);

    function totalAllocPoint() external view returns (uint256);

    function sevnPerSec() external view returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external ;
        
    function farmPercent() external view returns (uint256);
    
    function marketPercent() external view returns (uint256);
    
    function safuPercent() external view returns (uint256);
    
    function treasurePercent() external view returns (uint256);

    function percentDec() external view returns (uint256);
    
}