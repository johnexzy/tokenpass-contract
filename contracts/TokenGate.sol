// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenGate is AccessControl, Initializable {
    mapping(address => bool) private allAccessTokens;

    bytes32 public constant ERC_721 = "ERC721";
    bytes32 public constant ERC_1155 = "ERC1155";
    bytes32 public constant ERC_20 = "ERC20";

    /**
     * The schema used in initislizing Access Tokens
     * `lifetime`
     */
    struct AccessToken {
        address contractAddress; // contract address of the access token (ERC20, ERC721 or ERC1155)
        bytes32 typeOfToken; // "ERC20" or "ERC721" or "ERC1155" in bytes32
        int256 specifyId; // -1 if not needed. required for ERC1155 and optional for ERC721
        bool lifetime; //true
        uint256 amount; //required for ERC1155, ERC20 optional for ERC721
    }

    /**
     * array of access tokens.
     *
     * deleting element from the accessTokens will incur high gas fees
     *
     * as a result to disable tokens from having lifetime access,
     *
     * set the contract address in `allAccessToken` to `false`
     *
     * by calling the `disableTokenAccess()`
     */
    AccessToken[] public accessTokens;

    /**
     * Constructor. sets Role to DEFAULT_AMIN_ROLE
     */
    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initializeAccessToken(AccessToken memory _accessToken)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _accessToken.typeOfToken == ERC_1155 ||
                _accessToken.typeOfToken == ERC_721 ||
                _accessToken.typeOfToken == ERC_20,
            "Unsupported token type"
        ); // checks for supported token types

        if (_accessToken.typeOfToken == ERC_1155) {
            require(
                _accessToken.specifyId >= 0,
                "No tokenId for ERC1155 token"
            );
        } else if (_accessToken.typeOfToken == ERC_20) {
            require(_accessToken.amount > 0, "No amount for ERC20 token");
        }
        allAccessTokens[_accessToken.contractAddress] = true;
        accessTokens.push(_accessToken);
    }

    function checkAccess(address userAddress) public view returns (bool) {
        bool subscribed = false;
        for (uint256 i = 0; i < accessTokens.length; i++) {
            if (allAccessTokens[accessTokens[i].contractAddress])
                if (
                    accessTokens[i].typeOfToken == ERC_721 &&
                    handleERC721Access(accessTokens[i], userAddress)
                ) subscribed = true;
                else if (
                    accessTokens[i].typeOfToken == ERC_1155 &&
                    handleERC1155Access(accessTokens[i], userAddress)
                ) subscribed = true;
                else if (
                    accessTokens[i].typeOfToken == ERC_20 &&
                    handleERC20Access(accessTokens[i], userAddress)
                ) subscribed = true;

            if (subscribed) break;
        }
        return subscribed;
    }

    function handleERC721Access(
        AccessToken memory contractObj,
        address userAddress
    ) internal view returns (bool) {
        if (contractObj.specifyId == -1)
            return balanceOf(contractObj, userAddress);
        if (contractObj.specifyId != -1)
            return
                ownerOf(
                    contractObj.contractAddress,
                    contractObj.specifyId,
                    userAddress
                );
        return false;
    }

    function handleERC1155Access(
        AccessToken memory contractObj,
        address userAddress
    ) internal view returns (bool) {
        return balanceOf(contractObj, userAddress);
    }

    function handleERC20Access(
        AccessToken memory contractObj,
        address userAddress
    ) internal view returns (bool) {
        return balanceOf(contractObj, userAddress);
    }

    function balanceOf(AccessToken memory _contractObj, address userAddress)
        public
        view
        returns (bool)
    {
        /** ERC721 Token */
        if (_contractObj.typeOfToken == ERC_721)
            return
                IERC721(_contractObj.contractAddress).balanceOf(userAddress) > 0
                    ? true
                    : false;
        /** ERC1155 Token */
        else if (_contractObj.typeOfToken == ERC_1155)
            return
                IERC1155(_contractObj.contractAddress).balanceOf(
                    userAddress,
                    uint256(_contractObj.specifyId)
                ) > _contractObj.amount
                    ? true
                    : false;
        /** ERC20 Token */
        else if (_contractObj.typeOfToken == ERC_20)
            return
                IERC20(_contractObj.contractAddress).balanceOf(userAddress) >
                    _contractObj.amount
                    ? true
                    : false;
        return false;
    }

    function ownerOf(
        address _contractAddress,
        int256 id,
        address userAddress
    ) public view returns (bool) {
        return IERC721(_contractAddress).ownerOf(uint256(id)) == userAddress;
    }

    function disableTokenAccess(address _contractAddress)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(allAccessTokens[_contractAddress], "Token does not exist");
        allAccessTokens[_contractAddress] = false;
    }
}
