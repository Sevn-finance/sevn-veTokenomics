// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBoostedMasterChefSevn.sol";
import "./VeERC20.sol";


/// @title Vote Escrow Sevn Token - veSEVN
/// @author Sevn.finance
/// @notice Infinite supply, used to receive extra farming yields and voting power
contract VeSevn is VeERC20, Ownable {
    /// @notice the BoostedMasterChefSevn contract
    IBoostedMasterChefSevn public boostedMasterChef;

    event UpdateBoostedMasterChefSevn(address indexed user, address boostedMasterChef);

    constructor() VeERC20("VeSevn", "veSEVN"){}

    /// @dev Creates `_amount` token to `_to`. Must only be called by the owner (VeSevnStaking)
    /// @param _to The address that will receive the mint
    /// @param _amount The amount to be minted
    function mint(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    /// @dev Destroys `_amount` tokens from `_from`. Callable only by the owner (VeSevnStaking)
    /// @param _from The address that will burn tokens
    /// @param _amount The amount to be burned
    function burnFrom(address _from, uint256 _amount) external onlyOwner {
        _burn(_from, _amount);
    }

    /// @dev Sets the address of the master chef contract this updates
    /// @param _boostedMasterChef the address of BoostedMasterChefSevn
    function setBoostedMasterChefSevn(address _boostedMasterChef) external onlyOwner {
        // We allow 0 address here if we want to disable the callback operations
        boostedMasterChef = IBoostedMasterChefSevn(_boostedMasterChef);
        emit UpdateBoostedMasterChefSevn(_msgSender(), _boostedMasterChef);
    }

    function _afterTokenOperation(address _account, uint256 _newBalance) internal override {
        if (address(boostedMasterChef) != address(0)) {
            boostedMasterChef.updateFactor(_account, _newBalance);
        }
    }

    function renounceOwnership() public override onlyOwner {
        revert("VeSevnToken: Cannot renounce, can only transfer ownership");
    }
}