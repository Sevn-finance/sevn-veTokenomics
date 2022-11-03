// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;
pragma experimental ABIEncoderV2;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IMasterChefSevn.sol";
import "./libs/Math.sol";

/// @notice The (older) MasterChefSevnV2 contract gives out a constant number of SEVN
/// tokens per block.  It is the only address with minting rights for SEVN.  The idea
/// for this BoostedMasterChefSevn (BMCS) contract is therefore to be the owner of a
/// dummy token that is deposited into the MasterChefSevnV2 (MCSV2) contract.  The
/// allocation point for this pool on MCSV2 is the total allocation point for all
/// pools on BMCV.
///
/// This MasterChef also skews how many rewards users receive, it does this by
/// modifying the algorithm that calculates how many tokens are rewarded to
/// depositors. Whereas MasterChef calculates rewards based on emission rate and
/// total liquidity, this version uses adjusted parameters to this calculation.
///
/// A users `boostedAmount` (liquidity multiplier) is calculated by the actual supplied
/// liquidity multiplied by a boost factor. The boost factor is calculated by the
/// amount of veSEVN held by the user over the total veSEVN amount held by all pool
/// participants. Total liquidity is the sum of all boosted liquidity.

contract BoostedMasterChefSevn is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /// @notice Info of each BMCS user
    /// `amount` LP token amount the user has provided
    /// `rewardDebt` The amount of SEVN entitled to the user
    /// `factor` the users factor, use _getUserFactor
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 factor;
    }

    /// @notice Info of each BMCS pool
    /// `allocPoint` The amount of allocation points assigned to the pool
    /// Also known as the amount of SEVN to distribute per block
    struct PoolInfo {
        // Address are stored in 160 bits, so we store allocPoint in 96 bits to
        // optimize storage (160 + 96 = 256)
        IERC20 lpToken;
        uint96 allocPoint;
        uint256 accSevnPerShare;
        uint256 accSevnPerFactorPerShare;
        // Address are stored in 160 bits, so we store lastRewardTimestamp in 64 bits and
        // veSevnShareBp in 32 bits to optimize storage (160 + 64 + 32 = 256)
        uint64 lastRewardTimestamp;
        // Share of the reward to distribute to veSevn holders
        uint32 veSevnShareBp;
        // The sum of all veSevn held by users participating in this farm
        // This value is updated when
        // - A user enter/leaves a farm
        // - A user claims veSEVN
        // - A user unstakes SEVN
        uint256 totalFactor;
        // The total LP supply of the farm
        // This is the sum of all users boosted amounts in the farm. Updated when
        // someone deposits or withdraws.
        // This is used instead of the usual `lpToken.balanceOf(address(this))` for security reasons
        uint256 totalLpSupply;
    }

     /// @notice Address of MCJV2 contract
    IMasterChefSevn public MASTER_CHEF_V2;
    /// @notice Address of SEVN contract
    IERC20 public SEVN;
    /// @notice Address of veSEVN contract
    IERC20 public VESEVN;
    /// @notice Address of veSevnStaking contract
    address public VESEVNSTAKING;
    /// @notice The index of BMCS master pool in MCSV2
    uint256 public MASTER_PID;

     /// @notice Info of each BMCS pool
    PoolInfo[] public poolInfo;
    /// @dev Maps an address to a bool to assert that a token isn't added twice
    mapping(IERC20 => bool) private checkPoolDuplicate;

    /// @notice Info of each user that stakes LP tokens
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    /// @dev Total allocation points. Must be the sum of all allocation points in all pools
    uint256 public totalAllocPoint;
    uint256 private ACC_TOKEN_PRECISION;

    /// @dev Amount of claimable Sevn the user has, this is required as we
    /// need to update rewardDebt after a token operation but we don't
    /// want to send a reward at this point. This amount gets added onto
    /// the pending amount when a user claims
    mapping(uint256 => mapping(address => uint256)) public claimableSevn;

    event Add(
        uint256 indexed pid,
        uint256 allocPoint,
        uint256 veSevnShareBp,
        IERC20 indexed lpToken
    );
    event Set(
        uint256 indexed pid,
        uint256 allocPoint,
        uint256 veSevnShareBp
    );
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event UpdatePool(
        uint256 indexed pid,
        uint256 lastRewardTimestamp,
        uint256 lpSupply,
        uint256 accSevnPerShare,
        uint256 accSevnPerFactorPerShare
    );
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Init(uint256 amount);

    /// @param _MASTER_CHEF_V2 The MCSV2 contract address
    /// @param _sevn The SEVN token contract address
    /// @param _veSevn The veSEVN token contract address
    /// @param _veSevnStaking The veSEVNStaking contract address
    /// @param _MASTER_PID The pool ID of the dummy token on the base MCSV2 contract
    constructor(
        IMasterChefSevn _MASTER_CHEF_V2,
        IERC20 _sevn,
        IERC20 _veSevn,
        address _veSevnStaking,
        uint256 _MASTER_PID
    ){
        MASTER_CHEF_V2 = _MASTER_CHEF_V2;
        SEVN = _sevn;
        VESEVN = _veSevn;
        MASTER_PID = _MASTER_PID;
        VESEVNSTAKING = _veSevnStaking;
        ACC_TOKEN_PRECISION = 1e18;
    }

    /// @notice Deposits a dummy token to `MASTER_CHEF_V2` MCSV2. This is required because MCSV2
    /// holds the minting rights for SEVN.  Any balance of transaction sender in `_dummyToken` is transferred.
    /// The allocation point for the pool on MCSV2 is the total allocation point for all pools that receive
    /// double incentives.
    /// @param _dummyToken The address of the ERC-20 token to deposit into MCSV2.
    function init(IERC20 _dummyToken) external onlyOwner {
        require(
            _dummyToken.balanceOf(address(MASTER_CHEF_V2)) == 0,
            "BoostedMasterChefSevn: Already has a balance of dummy token"
        );
        uint256 balance = _dummyToken.balanceOf(_msgSender());
        require(balance != 0, "BoostedMasterChefSevn: Balance must exceed 0");
        _dummyToken.safeTransferFrom(_msgSender(), address(this), balance);
        _dummyToken.approve(address(MASTER_CHEF_V2), balance);
        MASTER_CHEF_V2.deposit(MASTER_PID, balance);
        emit Init(balance);
    }

    /// @notice Add a new LP to the pool. Can only be called by the owner.
    /// @param _allocPoint AP of the new pool.
    /// @param _veSevnShareBp Share of rewards allocated in proportion to user's liquidity
    /// and veSevn balance
    /// @param _lpToken Address of the LP ERC-20 token.
    /// @param _massUpdate Need update all pool`s
    function add(
        uint96 _allocPoint,
        uint32 _veSevnShareBp,
        IERC20 _lpToken,
        bool _massUpdate
    ) external onlyOwner {
        require(!checkPoolDuplicate[_lpToken], "BoostedMasterChefSevn: LP already added");
        require(_veSevnShareBp <= 10_000, "BoostedMasterChefSevn: veSevnShareBp needs to be lower than 10000");
        checkPoolDuplicate[_lpToken] = true;
        // Sanity check to ensure _lpToken is an ERC20 token
        _lpToken.balanceOf(address(this));

        if(_massUpdate)
            massUpdatePools();

        totalAllocPoint = totalAllocPoint.add(_allocPoint);

        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                accSevnPerShare: 0,
                accSevnPerFactorPerShare: 0,
                lastRewardTimestamp: uint64(block.timestamp),
                veSevnShareBp: _veSevnShareBp,
                totalFactor: 0,
                totalLpSupply: 0
            })
        );
        emit Add(poolInfo.length - 1, _allocPoint, _veSevnShareBp, _lpToken);
    }

    /// @notice Update the given pool's SEVN allocation point. Can only be called by the owner.
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _allocPoint New AP of the pool
    /// @param _veSevnShareBp Share of rewards allocated in proportion to user's liquidity
    /// @param _massUpdate Need update all pool`s
    /// and veSevn balance
    function set(
        uint256 _pid,
        uint96 _allocPoint,
        uint32 _veSevnShareBp,
        bool _massUpdate
    ) external onlyOwner {
        require(_veSevnShareBp <= 10_000, "BoostedMasterChefSevn: veSevnShareBp needs to be lower than 10000");
        if(_massUpdate)
            massUpdatePools();

        PoolInfo storage pool = poolInfo[_pid];
        totalAllocPoint = totalAllocPoint.add(_allocPoint).sub(pool.allocPoint);
        pool.allocPoint = _allocPoint;
        pool.veSevnShareBp = _veSevnShareBp;

        emit Set(_pid, _allocPoint, _veSevnShareBp);
    }

    /// @notice Deposit LP tokens to BMCS for SEVN allocation
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _amount LP token amount to deposit
    function deposit(uint256 _pid, uint256 _amount) external nonReentrant {
        harvestFromMasterChef();
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        // Pay a user any pending rewards
        if (user.amount != 0) {
            _harvestSevn(user, pool, _pid);
        }

        uint256 balanceBefore = pool.lpToken.balanceOf(address(this));
        pool.lpToken.safeTransferFrom(_msgSender(), address(this), _amount);
        uint256 receivedAmount = pool.lpToken.balanceOf(address(this)).sub(balanceBefore);

        _updateUserAndPool(user, pool, receivedAmount, true);

        emit Deposit(_msgSender(), _pid, receivedAmount);
    }

    /// @notice Withdraw LP tokens from BMCS
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _amount LP token amount to withdraw
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        harvestFromMasterChef();
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(user.amount >= _amount, "BoostedMasterChefSevn: withdraw not good");

        if (user.amount != 0) {
            _harvestSevn(user, pool, _pid);
        }

        _updateUserAndPool(user, pool, _amount, false);

        pool.lpToken.safeTransfer(_msgSender(), _amount);

        emit Withdraw(_msgSender(), _pid, _amount);
    }

    /// @notice Updates factor after after a veSevn token operation.
    /// This function needs to be called by the veSevnStaking contract after
    /// every mint / burn.
    /// @param _user The users address we are updating
    /// @param _newVeSevnBalance The new balance of the users veSevn
    function updateFactor(address _user, uint256 _newVeSevnBalance) external {
        require(_msgSender() == address(VESEVNSTAKING), "BoostedMasterChefSevn: Caller not veSevnStaking");
        uint256 len = poolInfo.length;
        uint256 _ACC_TOKEN_PRECISION = ACC_TOKEN_PRECISION;

        for (uint256 pid; pid < len; ++pid) {
            UserInfo storage user = userInfo[pid][_user];

            // Skip if user doesn't have any deposit in the pool
            uint256 amount = user.amount;
            if (amount == 0) {
                continue;
            }

            PoolInfo storage pool = poolInfo[pid];

            updatePool(pid);
            uint256 oldFactor = user.factor;
            (uint256 accSevnPerShare, uint256 accSevnPerFactorPerShare) = (
                pool.accSevnPerShare,
                pool.accSevnPerFactorPerShare
            );
            uint256 pending = amount
                .mul(accSevnPerShare)
                .add(oldFactor.mul(accSevnPerFactorPerShare))
                .div(_ACC_TOKEN_PRECISION)
                .sub(user.rewardDebt);

            // Increase claimableSevn
            claimableSevn[pid][_user] = claimableSevn[pid][_user].add(pending);

            // Update users veSevnBalance
            uint256 newFactor = _getUserFactor(amount, _newVeSevnBalance);
            user.factor = newFactor;
            pool.totalFactor = pool.totalFactor.add(newFactor).sub(oldFactor);

            user.rewardDebt = amount.mul(accSevnPerShare).add(newFactor.mul(accSevnPerFactorPerShare)).div(
                _ACC_TOKEN_PRECISION
            );
        }
    }

    /// @notice Withdraw without caring about rewards (EMERGENCY ONLY)
    /// @param _pid The index of the pool. See `poolInfo`
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];

        pool.totalFactor = pool.totalFactor.sub(user.factor);
        pool.totalLpSupply = pool.totalLpSupply.sub(user.amount);
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.factor = 0;

        // Note: transfer can fail or succeed if `amount` is zero
        pool.lpToken.safeTransfer(_msgSender(), amount);
        emit EmergencyWithdraw(_msgSender(), _pid, amount);
    }

    /// @notice Calculates and returns the `amount` of SEVN per second
    /// @return amount The amount of SEVN emitted per second
    function sevnPerSec() public view returns (uint256 amount) {
        uint256 total = MASTER_CHEF_V2.percentDec();
        uint256 lpPercent = MASTER_CHEF_V2.farmPercent();
        uint256 lpShare = MASTER_CHEF_V2.sevnPerSec().mul(lpPercent).div(total);
        amount = lpShare.mul(MASTER_CHEF_V2.poolInfo(MASTER_PID).allocPoint).div(MASTER_CHEF_V2.totalAllocPoint());
    }

    /// @notice View function to see pending SEVN on frontend
    /// @param _pid The index of the pool. See `poolInfo`
    /// @param _user Address of user
    /// @return pendingSevn SEVN reward for a given user.
    function pendingTokens(uint256 _pid, address _user)
        external
        view
        returns (uint256 pendingSevn)
    {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = userInfo[_pid][_user];
        uint256 accSevnPerShare = pool.accSevnPerShare;
        uint256 accSevnPerFactorPerShare = pool.accSevnPerFactorPerShare;

        if (block.timestamp > pool.lastRewardTimestamp && pool.totalLpSupply != 0 && pool.allocPoint != 0) {
            uint256 secondsElapsed = block.timestamp - pool.lastRewardTimestamp;
            uint256 sevnReward = secondsElapsed.mul(sevnPerSec()).mul(pool.allocPoint).div(totalAllocPoint);
            accSevnPerShare = accSevnPerShare.add(
                sevnReward.mul(ACC_TOKEN_PRECISION).mul(10_000 - pool.veSevnShareBp).div(pool.totalLpSupply.mul(10_000))
            );
            if (pool.veSevnShareBp != 0 && pool.totalFactor != 0) {
                accSevnPerFactorPerShare = accSevnPerFactorPerShare.add(
                    sevnReward.mul(ACC_TOKEN_PRECISION).mul(pool.veSevnShareBp).div(pool.totalFactor.mul(10_000))
                );
            }
        }

        pendingSevn = (user.amount.mul(accSevnPerShare))
            .add(user.factor.mul(accSevnPerFactorPerShare))
            .div(ACC_TOKEN_PRECISION)
            .add(claimableSevn[_pid][_user])
            .sub(user.rewardDebt);
    }

    /// @notice Returns the number of BMCS pools.
    /// @return pools The amount of pools in this farm
    function poolLength() external view returns (uint256 pools) {
        pools = poolInfo.length;
    }

    /// @notice Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 len = poolInfo.length;
        for (uint256 i = 0; i < len; ++i) {
            updatePool(i);
        }
    }

    /// @notice Update reward variables of the given pool
    /// @param _pid The index of the pool. See `poolInfo`
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        uint256 lastRewardTimestamp = pool.lastRewardTimestamp;
        if (block.timestamp > lastRewardTimestamp) {
            uint256 lpSupply = pool.totalLpSupply;
            uint256 allocPoint = pool.allocPoint;
            // gas opt and prevent div by 0
            if (lpSupply != 0 && allocPoint != 0) {
                uint256 secondsElapsed = block.timestamp - lastRewardTimestamp;
                uint256 veSevnShareBp = pool.veSevnShareBp;
                uint256 totalFactor = pool.totalFactor;

                uint256 sevnReward = secondsElapsed.mul(sevnPerSec()).mul(allocPoint).div(totalAllocPoint);
                pool.accSevnPerShare = pool.accSevnPerShare.add(
                    sevnReward.mul(ACC_TOKEN_PRECISION).mul(10_000 - veSevnShareBp).div(lpSupply.mul(10_000))
                );
                // If veSevnShareBp is 0, then we don't need to update it
                if (veSevnShareBp != 0 && totalFactor != 0) {
                    pool.accSevnPerFactorPerShare = pool.accSevnPerFactorPerShare.add(
                        sevnReward.mul(ACC_TOKEN_PRECISION).mul(veSevnShareBp).div(totalFactor.mul(10_000))
                    );
                }
            }
            pool.lastRewardTimestamp = uint64(block.timestamp);
            emit UpdatePool(
                _pid,
                pool.lastRewardTimestamp,
                lpSupply,
                pool.accSevnPerShare,
                pool.accSevnPerFactorPerShare
            );
        }
    }

    /// @notice Harvests SEVN from `MASTER_CHEF_V2` MCSV2 and pool `MASTER_PID` to this BMCS contract
    function harvestFromMasterChef() public {
        MASTER_CHEF_V2.deposit(MASTER_PID, 0);
    }

    /// @notice Return an user's factor
    /// @param amount The user's amount of liquidity
    /// @param veSevnBalance The user's veSevn balance
    /// @return uint256 The user's factor
    function _getUserFactor(uint256 amount, uint256 veSevnBalance) private pure returns (uint256) {
        return Math.sqrt(amount * veSevnBalance);
    }

    /// @notice Updates user and pool infos
    /// @param _user The user that needs to be updated
    /// @param _pool The pool that needs to be updated
    /// @param _amount The amount that was deposited or withdrawn
    /// @param _isDeposit If the action of the user is a deposit
    function _updateUserAndPool(
        UserInfo storage _user,
        PoolInfo storage _pool,
        uint256 _amount,
        bool _isDeposit
    ) private {
        uint256 oldAmount = _user.amount;
        uint256 newAmount = _isDeposit ? oldAmount.add(_amount) : oldAmount.sub(_amount);

        if (_amount != 0) {
            _user.amount = newAmount;
            _pool.totalLpSupply = _isDeposit ? _pool.totalLpSupply.add(_amount) : _pool.totalLpSupply.sub(_amount);
        }

        uint256 oldFactor = _user.factor;
        uint256 newFactor = _getUserFactor(newAmount, VESEVN.balanceOf(_msgSender()));

        if (oldFactor != newFactor) {
            _user.factor = newFactor;
            _pool.totalFactor = _pool.totalFactor.add(newFactor).sub(oldFactor);
        }

        _user.rewardDebt = newAmount.mul(_pool.accSevnPerShare).add(newFactor.mul(_pool.accSevnPerFactorPerShare)).div(
            ACC_TOKEN_PRECISION
        );
    }

    /// @notice Harvests user's pending SEVN
    /// @dev WARNING this function doesn't update user's rewardDebt,
    /// it still needs to be updated in order for this contract to work properlly
    /// @param _user The user that will harvest its rewards
    /// @param _pool The pool where the user staked and want to harvest its SEVN
    /// @param _pid The pid of that pool
    function _harvestSevn(
        UserInfo storage _user,
        PoolInfo storage _pool,
        uint256 _pid
    ) private {
        uint256 pending = (_user.amount.mul(_pool.accSevnPerShare))
            .add(_user.factor.mul(_pool.accSevnPerFactorPerShare))
            .div(ACC_TOKEN_PRECISION)
            .add(claimableSevn[_pid][_msgSender()])
            .sub(_user.rewardDebt);
        claimableSevn[_pid][_msgSender()] = 0;
        if (pending != 0) {
            SEVN.safeTransfer(_msgSender(), pending);
            emit Harvest(_msgSender(), _pid, pending);
        }
    }

}
