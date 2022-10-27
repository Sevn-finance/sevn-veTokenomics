// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./library/Mintable.sol";

contract Sevn is ERC20, Ownable, Mintable{

    uint256 public constant preMineSupply = 45350000 * 1e18; // 45 350 000
    uint256 public constant maxSupply = 350000000 * 1e18; // 350 000 000

    constructor(string memory name, string memory symbol) ERC20(name, symbol){
        _addMinter(msg.sender);
        _mint(msg.sender, preMineSupply);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply. 
     *
     * Requirements:
     *
     * - `_to` cannot be the zero address.
     * - `totalSupply` can not > `maxSupply`
     */
    function mint(address _to, uint256 _amount) external onlyMinter returns(bool) {
        _mint(_to, _amount);
        require(totalSupply() <= maxSupply, "SEVN: totalSupply can not > maxSupply");
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply. 
     *
     * Requirements:
     *
     * - `account` must have at least `amount` tokens.
     */
    function burn(uint256 _amount) external onlyOwner {
        _burn(msg.sender, _amount);
    }

    /**
     * @dev Adds an address to the list of minters.
     * 
     *  Requirements:
     *  - `_minter` cannot be zero.
     */
    function addMinter(address _minter) external onlyOwner returns (bool) {
        require(_minter != address(0), "SEVN: _minter is the zero address");
        return _addMinter(_minter);
    }

    /**
     * @dev Removes an address from the list of minters.
     * 
     *  Requirements:
     *  - address cannot be zero.
     */
    function delMinter(address _minter) external onlyOwner returns (bool) {
        require(_minter != address(0), "SEVN: _minter is the zero address");
        return _delMinter(_minter);
    }
}   