// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract TestToken1155 is ERC1155 {
    constructor() ERC1155("") {
        _mint(msg.sender, 0, 100, "");
    }
}
