// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestToken721 is ERC721 {
    constructor() ERC721("Afro Apes:", "AAO") {
        _mint(msg.sender, 0);
    }
}
