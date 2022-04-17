// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
contract TokenGate is AccessControl, Initializable {
    /**
     * Register all access tokens
     * deactivate access token by setting it's address to 'false'
     */
    mapping(address => bool) private allAccessTokens;

    bytes32 public constant ERC_721 = "ERC721";
    bytes32 public constant ERC_1155 = "ERC1155";

    /**
     * The schema used in initislizing Access Tokens
     * `lifetime`
     */
    struct AccessToken {
        address contractAddress;
        bytes32 typeOfToken;
        int256 specifyId; //
        bool lifetime;
    }

    /**
     * array of access tokens.
     * deleting element from the accessTokens will incur high gas fees
     * as a result to disable tokens from having lifetime access
     * set the contract address in `allAccessToken` to `false`
     * by calling the `disableTokenAccess()`
     */
    AccessToken[] public accessTokens;

    function initialize() public initializer{
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initializeAccessTokens(AccessToken[] memory _accessTokens) public onlyRole(DEFAULT_ADMIN_ROLE) {
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
                if (contractObj.typeOfToken == ERC_721) {
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
                        subscribed = ownerOf(
                            contractObj.contractAddress,
                            contractObj.specifyId
                        );
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
        return IERC721(_contractAddress).ownerOf(uint256(id)) == msg.sender;
    }

    function disableTokenAccess(address _contractAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(allAccessTokens[_contractAddress], "Token does not exist");
        allAccessTokens[_contractAddress] = false;
    }
}
