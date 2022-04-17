// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract Access {
    /**
     * Register all access tokens
     * deactivate access token by setting it's address to 'false'
     */
    mapping(address => bool) private allAccessTokens;


    string public constant ERC_721 = "ERC721";
    string public constant ERC_1155 = "ERC1155";

    /**
     * The schema used in initislizing Access Tokens
     * `lifetime` 
     */
    struct AccessToken {
        address contractAddress;
        string typeOf;
        int256 specifyId; //
        bool lifetime;
    }
    AccessToken[] public accessTokens;

    // function intialize(address theOrigin, address collectibles) public {
    //     Origin = IERC721(theOrigin);
    //     Collectibles = IERC1155(collectibles);
    // }

    function initializeAccessTokens(AccessToken[] memory _accessTokens) public {
        for (uint256 i = 0; i < _accessTokens.length; i++) {
            allAccessTokens[_accessTokens[i].contractAddress] = true;
            accessTokens.push(_accessTokens[i]);
        }
    }

    function isSubscribed() public view returns (bool) {
        bool subscribed = false;
        for (uint256 i = 0; i < accessTokens.length; i++) {
            AccessToken memory contractObj = accessTokens[i];
            if (allAccessTokens[contractObj.contractAddress]) {
                if (
                    keccak256(bytes(contractObj.typeOf)) ==
                    keccak256(bytes(ERC_721))
                ) {
                    if (
                        contractObj.specifyId == -1 &&
                        balanceOf(contractObj.contractAddress)
                    ) {
                        subscribed = true;
                    }
                    if (
                        contractObj.specifyId != -1 &&
                        balanceOf(contractObj.contractAddress)
                    ) {
                        subscribed = ownerOf(contractObj.contractAddress, contractObj.specifyId);
                    }
                }
            }
        }
        return subscribed;
    }

    function balanceOf(address _contractAddress) public view returns (bool) {
        return
            IERC721(_contractAddress).balanceOf(msg.sender) > 0 ? true : false;
    }

    function ownerOf(address _contractAddress, int256 id)
        public
        view
        returns (bool)
    {
        return IERC721(_contractAddress).ownerOf(uint(id)) == msg.sender;
    }
}
