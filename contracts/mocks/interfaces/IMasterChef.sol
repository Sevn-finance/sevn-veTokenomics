// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMigratorChef {
    function migrate(IERC20 token) external returns (IERC20);
}
