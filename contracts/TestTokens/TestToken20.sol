// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken20 is ERC20 {
    constructor() ERC20("Access Token", "AA") {
        _mint(msg.sender, 100);
    }
}
