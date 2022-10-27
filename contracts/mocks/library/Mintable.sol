// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract Mintable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _minters;

    /**
     * @dev Throws if called by any account other than the minter.
     */
    modifier onlyMinter() {
        require(isMinter(msg.sender), "caller is not the minter");
        _;
    }

    /**
     * @dev Returns the length minters.
     */
    function getMinterLength() public view returns (uint256) {
        return EnumerableSet.length(_minters);
    }

    /**
     * @dev Returns true if `account` is a minter.
     */
    function isMinter(address account) public view returns (bool) {
        return EnumerableSet.contains(_minters, account);
    }

    /**
     * @dev Returns minter by index.
     */
    function getMinter(uint256 _index) public view returns (address){
        require(_index <= getMinterLength() - 1, "Mintable: index out of bounds");
        return EnumerableSet.at(_minters, _index);
    }
    
    /**
     * @dev Adds an address to the list of minters.
     */
    function _addMinter(address addMinter) internal returns (bool) {
        return EnumerableSet.add(_minters, addMinter);
    }

    /**
     * @dev Removes an address from the list of minters.
     */
    function _delMinter(address delMinter) internal returns (bool) {
        return EnumerableSet.remove(_minters, delMinter);
    }

}