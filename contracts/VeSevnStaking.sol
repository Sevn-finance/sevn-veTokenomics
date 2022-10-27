// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IBoostedMasterChefSevn.sol";
import "./VeSevn.sol";

/// @title Vote Escrow Sevn Staking
/// @author Sevn.finance
/// @notice Stake Sevn to earn veSevn, which you can use to earn higher farm yields and gain
/// voting power. Note that unstaking any amount of Sevn will burn all of your existing veSevn.

contract VeSevnStaking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice Info for each user
    /// `balance`: Amount of SEVN currently staked by user
    /// `rewardDebt`: The reward debt of the user
    /// `lastClaimTimestamp`: The timestamp of user's last claim or withdraw
    /// `speedUpEndTimestamp`: The timestamp when user stops receiving speed up benefits, or
    /// zero if user is not currently receiving speed up benefits
     struct UserInfo {
        uint256 balance;
        uint256 rewardDebt;
        uint256 lastClaimTimestamp;
        uint256 speedUpEndTimestamp;
        /**
         * @notice We do some fancy math here. Basically, any point in time, the amount of veSEVN
         * entitled to a user but is pending to be distributed is:
         *
         *   pendingReward = pendingBaseReward + pendingSpeedUpReward
         *
         *   pendingBaseReward = (user.balance * accVeSevnPerShare) - user.rewardDebt
         *
         *   if user.speedUpEndTimestamp != 0:
         *     speedUpCeilingTimestamp = min(block.timestamp, user.speedUpEndTimestamp)
         *     speedUpSecondsElapsed = speedUpCeilingTimestamp - user.lastClaimTimestamp
         *     pendingSpeedUpReward = speedUpSecondsElapsed * user.balance * speedUpVeSevnPerSharePerSec
         *   else:
         *     pendingSpeedUpReward = 0
         */
    }

    IERC20 public sevn;
    VeSevn public veSevn;

    /// @notice the BoostedMasterChefSevn contract
    IBoostedMasterChefSevn public boostedMasterChef;

     /// @notice The maximum limit of veSEVN user can have as percentage points of staked SEVN
    /// For example, if user has `n` SEVN staked, they can own a maximum of `n * maxCapPct / 100` veSEVN.
    uint256 public maxCapPct;

    /// @notice The upper limit of `maxCapPct`
    uint256 public upperLimitMaxCapPct;

    /// @notice The accrued veSevn per share, scaled to `ACC_VESEVN_PER_SHARE_PRECISION`
    uint256 public accVeSevnPerShare;

    /// @notice Precision of `accVeSevnPerShare`
    uint256 public ACC_VESEVN_PER_SHARE_PRECISION;

    /// @notice The last time that the reward variables were updated
    uint256 public lastRewardTimestamp;

    /// @notice veSEVN per sec per SEVN staked, scaled to `VESEVN_PER_SHARE_PER_SEC_PRECISION`
    uint256 public veSevnPerSharePerSec;

    /// @notice Speed up veSEVN per sec per SEVN staked, scaled to `VESEVN_PER_SHARE_PER_SEC_PRECISION`
    uint256 public speedUpVeSevnPerSharePerSec;

    /// @notice The upper limit of `veSevnPerSharePerSec` and `speedUpVeSevnPerSharePerSec`
    uint256 public upperLimitVeSevnPerSharePerSec;

    /// @notice Precision of `veSevnPerSharePerSec`
    uint256 public VESEVN_PER_SHARE_PER_SEC_PRECISION;

    /// @notice Percentage of user's current staked SEVN user has to deposit in order to start
    /// receiving speed up benefits, in parts per 100.
    /// @dev Specifically, user has to deposit at least `speedUpThreshold/100 * userStakedSevn` SEVN.
    /// The only exception is the user will also receive speed up benefits if they are depositing
    /// with zero balance
    uint256 public speedUpThreshold;

    /// @notice The length of time a user receives speed up benefits
    uint256 public speedUpDuration;

    mapping(address => UserInfo) public userInfo;

    event Claim(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event UpdateMaxCapPct(address indexed user, uint256 maxCapPct);
    event UpdateRewardVars(uint256 lastRewardTimestamp, uint256 accVeSevnPerShare);
    event UpdateSpeedUpThreshold(address indexed user, uint256 speedUpThreshold);
    event UpdateVeSevnPerSharePerSec(address indexed user, uint256 veSevnPerSharePerSec);
    event Withdraw(address indexed user, uint256 withdrawAmount, uint256 burnAmount);
    event UpdateBoostedMasterChefSevn(address indexed user, address boostedMasterChef);

    constructor(
        IERC20 _sevn,
        VeSevn _veSevn,
        uint256 _veSevnPerSharePerSec,
        uint256 _speedUpVeSevnPerSharePerSec,
        uint256 _speedUpThreshold,
        uint256 _speedUpDuration,
        uint256 _maxCapPct
    ){

        require(address(_sevn) != address(0), "VeSevnStaking: unexpected zero address for _sevn");
        require(address(_veSevn) != address(0), "VeSevnStaking: unexpected zero address for _veSevn");

        upperLimitVeSevnPerSharePerSec = 1e36;
        require(
            _veSevnPerSharePerSec <= upperLimitVeSevnPerSharePerSec,
            "VeSevnStaking: expected _veSevnPerSharePerSec to be <= 1e36"
        );
        require(
            _speedUpVeSevnPerSharePerSec <= upperLimitVeSevnPerSharePerSec,
            "VeSevnStaking: expected _speedUpVeSevnPerSharePerSec to be <= 1e36"
        );

        require(
            _speedUpThreshold != 0 && _speedUpThreshold <= 100,
            "VeSevnStaking: expected _speedUpThreshold to be > 0 and <= 100"
        );

        require(_speedUpDuration <= 365 days, "VeSevnStaking: expected _speedUpDuration to be <= 365 days");

        upperLimitMaxCapPct = 10000000;
        require(
            _maxCapPct != 0 && _maxCapPct <= upperLimitMaxCapPct,
            "VeSevnStaking: expected _maxCapPct to be non-zero and <= 10000000"
        );

        maxCapPct = _maxCapPct;
        speedUpThreshold = _speedUpThreshold;
        speedUpDuration = _speedUpDuration;
        sevn = _sevn;
        veSevn = _veSevn;
        veSevnPerSharePerSec = _veSevnPerSharePerSec;
        speedUpVeSevnPerSharePerSec = _speedUpVeSevnPerSharePerSec;
        lastRewardTimestamp = block.timestamp;
        ACC_VESEVN_PER_SHARE_PRECISION = 1e18;
        VESEVN_PER_SHARE_PER_SEC_PRECISION = 1e18;
    }

    /// @notice Set maxCapPct
    /// @param _maxCapPct The new maxCapPct
    function setMaxCapPct(uint256 _maxCapPct) external onlyOwner {
        require(_maxCapPct > maxCapPct, "VeSevnStaking: expected new _maxCapPct to be greater than existing maxCapPct");
        require(
            _maxCapPct != 0 && _maxCapPct <= upperLimitMaxCapPct,
            "VeSevnStaking: expected new _maxCapPct to be non-zero and <= 10000000"
        );
        maxCapPct = _maxCapPct;
        emit UpdateMaxCapPct(_msgSender(), _maxCapPct);
    }

    /// @notice Set veSevnPerSharePerSec
    /// @param _veSevnPerSharePerSec The new veSevnPerSharePerSec
    function setVeSevnPerSharePerSec(uint256 _veSevnPerSharePerSec) external onlyOwner {
        require(
            _veSevnPerSharePerSec <= upperLimitVeSevnPerSharePerSec,
            "VeSevnStaking: expected _veSevnPerSharePerSec to be <= 1e36"
        );
        updateRewardVars();
        veSevnPerSharePerSec = _veSevnPerSharePerSec;
        emit UpdateVeSevnPerSharePerSec(_msgSender(), _veSevnPerSharePerSec);
    }

    /// @notice Set speedUpThreshold
    /// @param _speedUpThreshold The new speedUpThreshold
    function setSpeedUpThreshold(uint256 _speedUpThreshold) external onlyOwner {
        require(
            _speedUpThreshold != 0 && _speedUpThreshold <= 100,
            "VeSevnStaking: expected _speedUpThreshold to be > 0 and <= 100"
        );  
        speedUpThreshold = _speedUpThreshold;
        emit UpdateSpeedUpThreshold(_msgSender(), _speedUpThreshold);
    }

    /// @dev Sets the address of the master chef contract this updates
    /// @param _boostedMasterChef the address of BoostedMasterChefSevn
    function setBoostedMasterChefSevn(address _boostedMasterChef) external onlyOwner {
        // We allow 0 address here if we want to disable the callback operations
        boostedMasterChef = IBoostedMasterChefSevn(_boostedMasterChef);
        emit UpdateBoostedMasterChefSevn(_msgSender(), _boostedMasterChef);
    }

    /// @notice Deposits SEVN to start staking for veSEVN. Note that any pending veSEVN
    /// will also be claimed in the process.
    /// @param _amount The amount of SEVN to deposit
    function deposit(uint256 _amount) external {
        require(_amount > 0, "VeSevnStaking: expected deposit amount to be greater than zero");

        updateRewardVars();

        UserInfo storage userInfo = userInfo[_msgSender()];

        if (_getUserHasNonZeroBalance(_msgSender())) {
            // Transfer to the user their pending veSEVN before updating their UserInfo
            _claim();

            // We need to update user's `lastClaimTimestamp` to now to prevent
            // passive veSEVN accrual if user hit their max cap.
            userInfo.lastClaimTimestamp = block.timestamp;

            uint256 userStakedSevn = userInfo.balance;

            // User is eligible for speed up benefits if `_amount` is at least
            // `speedUpThreshold / 100 * userStakedSevn`
            if (_amount.mul(100) >= speedUpThreshold.mul(userStakedSevn)) {
                userInfo.speedUpEndTimestamp = block.timestamp.add(speedUpDuration);
            }
        } else {
            // If user is depositing with zero balance, they will automatically
            // receive speed up benefits
            userInfo.speedUpEndTimestamp = block.timestamp.add(speedUpDuration);
            userInfo.lastClaimTimestamp = block.timestamp;
        }

        userInfo.balance = userInfo.balance.add(_amount);
        userInfo.rewardDebt = accVeSevnPerShare.mul(userInfo.balance).div(ACC_VESEVN_PER_SHARE_PRECISION);

        sevn.safeTransferFrom(_msgSender(), address(this), _amount);

        emit Deposit(_msgSender(), _amount);
    }

    /// @notice Withdraw staked SEVN. Note that unstaking any amount of SEVN means you will
    /// lose all of your current veSEVN.
    /// @param _amount The amount of SEVN to unstake
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "VeSevnStaking: expected withdraw amount to be greater than zero");

        UserInfo storage userInfo = userInfo[_msgSender()];

        require(
            userInfo.balance >= _amount,
            "VeSevnStaking: cannot withdraw greater amount of SEVN than currently staked"
        );
        updateRewardVars();

        // Note that we don't need to claim as the user's veSEVN balance will be reset to 0
        userInfo.balance = userInfo.balance.sub(_amount);
        userInfo.rewardDebt = accVeSevnPerShare.mul(userInfo.balance).div(ACC_VESEVN_PER_SHARE_PRECISION);
        userInfo.lastClaimTimestamp = block.timestamp;
        userInfo.speedUpEndTimestamp = 0;

        // Burn the user's current veSEVN balance
        uint256 userVeSevnBalance = veSevn.balanceOf(_msgSender());
        veSevn.burnFrom(_msgSender(), userVeSevnBalance);
        _updateFactor(_msgSender());
        // Send user their requested amount of staked SEVN
        sevn.safeTransfer(_msgSender(), _amount);

        emit Withdraw(_msgSender(), _amount, userVeSevnBalance);
    }

    /// @notice Claim any pending veSEVN
    function claim() external {
        require(_getUserHasNonZeroBalance(_msgSender()), "VeSevnStaking: cannot claim veSEVN when no SEVN is staked");
        updateRewardVars();
        _claim();
    }

    /// @notice Get the pending amount of veSEVN for a given user
    /// @param _user The user to lookup
    /// @return The number of pending veSEVN tokens for `_user`
    function getPendingVeSevn(address _user) public view returns (uint256) {
        if (!_getUserHasNonZeroBalance(_user)) {
            return 0;
        }

        UserInfo memory user = userInfo[_user];

        // Calculate amount of pending base veSEVN
        uint256 _accVeSevnPerShare = accVeSevnPerShare;
        uint256 secondsElapsed = block.timestamp.sub(lastRewardTimestamp);
        if (secondsElapsed > 0) {
            _accVeSevnPerShare = _accVeSevnPerShare.add(
                secondsElapsed.mul(veSevnPerSharePerSec).mul(ACC_VESEVN_PER_SHARE_PRECISION).div(
                    VESEVN_PER_SHARE_PER_SEC_PRECISION
                )
            );
        }
        uint256 pendingBaseVeSevn = _accVeSevnPerShare.mul(user.balance).div(ACC_VESEVN_PER_SHARE_PRECISION).sub(
            user.rewardDebt
        );

        // Calculate amount of pending speed up veSEVN
        uint256 pendingSpeedUpVeSevn;
        if (user.speedUpEndTimestamp != 0) {
            uint256 speedUpCeilingTimestamp = block.timestamp > user.speedUpEndTimestamp
                ? user.speedUpEndTimestamp
                : block.timestamp;
            uint256 speedUpSecondsElapsed = speedUpCeilingTimestamp.sub(user.lastClaimTimestamp);
            uint256 speedUpAccVeSevnPerShare = speedUpSecondsElapsed.mul(speedUpVeSevnPerSharePerSec);
            pendingSpeedUpVeSevn = speedUpAccVeSevnPerShare.mul(user.balance).div(VESEVN_PER_SHARE_PER_SEC_PRECISION);
        }

        uint256 pendingVeSevn = pendingBaseVeSevn.add(pendingSpeedUpVeSevn);

        // Get the user's current veSEVN balance
        uint256 userVeSevnBalance = veSevn.balanceOf(_user);

        // This is the user's max veSEVN cap multiplied by 100
        uint256 scaledUserMaxVeSevnCap = user.balance.mul(maxCapPct);

        if (userVeSevnBalance.mul(100) >= scaledUserMaxVeSevnCap) {
            // User already holds maximum amount of veSEVN so there is no pending veSEVN
            return 0;
        } else if (userVeSevnBalance.add(pendingVeSevn).mul(100) > scaledUserMaxVeSevnCap) {
            return scaledUserMaxVeSevnCap.sub(userVeSevnBalance.mul(100)).div(100);
        } else {
            return pendingVeSevn;
        }
    }

    /// @notice Update reward variables
    function updateRewardVars() public {
        if (block.timestamp <= lastRewardTimestamp) {
            return;
        }

        if (sevn.balanceOf(address(this)) == 0) {
            lastRewardTimestamp = block.timestamp;
            return;
        }

        uint256 secondsElapsed = block.timestamp.sub(lastRewardTimestamp);
        accVeSevnPerShare = accVeSevnPerShare.add(
            secondsElapsed.mul(veSevnPerSharePerSec).mul(ACC_VESEVN_PER_SHARE_PRECISION).div(
                VESEVN_PER_SHARE_PER_SEC_PRECISION
            )
        );
        lastRewardTimestamp = block.timestamp;

        emit UpdateRewardVars(lastRewardTimestamp, accVeSevnPerShare);
    }

    /// @notice Checks to see if a given user currently has staked SEVN
    /// @param _user The user address to check
    /// @return Whether `_user` currently has staked SEVN
    function _getUserHasNonZeroBalance(address _user) private view returns (bool) {
        return userInfo[_user].balance > 0;
    }

    /// @dev Helper to claim any pending veSEVN
    function _claim() private {
        uint256 veSevnToClaim = getPendingVeSevn(_msgSender());

        UserInfo storage userInfo = userInfo[_msgSender()];

        userInfo.rewardDebt = accVeSevnPerShare.mul(userInfo.balance).div(ACC_VESEVN_PER_SHARE_PRECISION);

        // If user's speed up period has ended, reset `speedUpEndTimestamp` to 0
        if (userInfo.speedUpEndTimestamp != 0 && block.timestamp >= userInfo.speedUpEndTimestamp) {
            userInfo.speedUpEndTimestamp = 0;
        }

        if (veSevnToClaim > 0) {
            userInfo.lastClaimTimestamp = block.timestamp;

            veSevn.mint(_msgSender(), veSevnToClaim);
            _updateFactor(_msgSender());
            emit Claim(_msgSender(), veSevnToClaim);
        }
    }

    function _updateFactor(address _account) internal {
        if (address(boostedMasterChef) != address(0)) {
            uint256 balance = veSevn.balanceOf(_account);
            boostedMasterChef.updateFactor(_account, balance);
        }
    }

}