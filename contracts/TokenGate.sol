// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenGate is AccessControl, Initializable {
    /** ====SUPPORTED TOKEN TYPES======== **/
    bytes32 public constant ERC_721 = "ERC721";
    bytes32 public constant ERC_1155 = "ERC1155";
    bytes32 public constant ERC_20 = "ERC20";

    /** =====SUPPORTED SUBSCRIPTION TYPES===== **/
    bytes32 public constant SubscriptionTypeMonthly = "MONTHLY";

    /** =====SUPPORTED ROLES======= **/
    /** The Deployer is inherits the admin role */
    bytes32 public constant ADMIN_ROLE = 0x00;
    bytes32 public constant TOKEN_MODERATORS = "TOKEN_MODERATORS";

    /** EVENTS **/
    event Initialized(address indexed initializer);
    event AddedAccessToken(
        address indexed contractAddress,
        bytes32 indexed typeOfToken,
        int256 indexed id,
        uint256 amount,
        uint256 price,
        uint256 duration
    );
    event SetFee(
        address contractAddress,
        uint256 indexed price,
        uint256 indexed duration
    );
    event Subscribed(
        address indexed susbscriber,
        address indexed contractAddress,
        uint256 indexed dateOfSubscription,
        uint256 dateOfExpiration
    );
    event DisableTokenAccess(address indexed contractAddress);
    event WithdrawBalance(uint256 amount, address indexed caller);
    /**
     * The schema used in initislizing Access Tokens
     * `lifetime`
     */
    struct AccessToken {
        address contractAddress; // contract address of the access token (ERC20, ERC721 or ERC1155)
        bytes32 typeOfToken; // "ERC20" or "ERC721" or "ERC1155" in bytes32
        int256 specifyId; // -1 if not needed. required for ERC1155 and optional for ERC721
        Subscription subscription; // set price and duration for subscription
        uint256 amount; //required
    }

    struct Subscription {
        uint256 price;
        uint256 duration;
    }

    struct Subscriber {
        address subscriberAddress;
        uint256 dateOfSubscription;
        uint256 dateOfExpiration;
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

    // Subscriber[] public allSubscribers;
    mapping(address => mapping(address => Subscriber)) public allSubscribers;
    mapping(address => AccessToken) private allAccessTokens;
    mapping(address => address) public tokenAdmins;

    // MODIFIER
    modifier onlyTokenAdmin(address contractAddress) {
        tokenAdmins[contractAddress] = msg.sender;
        _;
    }

    /**
     * Constructor. sets Role to DEFAULT_ADMIN_ROLE
     */
    function initialize() public initializer {
        _setupRole(ADMIN_ROLE, msg.sender);
        _grantRole(TOKEN_MODERATORS, msg.sender);

        emit Initialized(msg.sender);
    }

    /**
    * @dev initializeAccessToken: to suplly the contract with the info about the token contract to be used for gating access
    * @param _accessToken: of datatype AccessToken to be passed as an array of values.
    * the third value of the argument array: typeOfToken ("ERC20" or "ERC721" or "ERC1155" ) must be a byte value of the string, 
    * the utility function stringToBytes32() can be used to convert to bytes
    */
    function initializeAccessToken(AccessToken memory _accessToken)
        public
        onlyRole(TOKEN_MODERATORS)
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
        allAccessTokens[_accessToken.contractAddress] = _accessToken;
        tokenAdmins[_accessToken.contractAddress] = msg.sender;
        emit AddedAccessToken(
            _accessToken.contractAddress,
            _accessToken.typeOfToken,
            _accessToken.specifyId,
            _accessToken.amount,
            _accessToken.subscription.price,
            _accessToken.subscription.duration
        );
    }

    /**
    * @dev checkAccess: checks if an address meets the requirement for access set by an accessToken moderator.
    * first checks if the address has an active subscription for the accessToken, else, checks if the address has the accessToken (Fungible or Non-Fungible)
    * @param _contractAddress: the address of the accessToken that the function wants to check user's access in
    * @param userAddress: the address that the function wants to validate 
    */
    function checkAccess(address _contractAddress, address userAddress)
        public
        view
        returns (bool)
    {
        if (checkIfSubscribed(_contractAddress, userAddress)) return true;
        if (allAccessTokens[_contractAddress].contractAddress != address(0))
            if (
                allAccessTokens[_contractAddress].typeOfToken == ERC_721 &&
                handleERC721Access(
                    allAccessTokens[_contractAddress],
                    userAddress
                )
            ) return true;
            else if (
                allAccessTokens[_contractAddress].typeOfToken == ERC_1155 &&
                handleERC1155Access(
                    allAccessTokens[_contractAddress],
                    userAddress
                )
            ) return true;
            else if (
                allAccessTokens[_contractAddress].typeOfToken == ERC_20 &&
                handleERC20Access(
                    allAccessTokens[_contractAddress],
                    userAddress
                )
            ) return true;

        return false;
    }

    /**
    * @dev checkIfSubscribed(): checks if an address has an actibe subscription in an accessToken.
    * the address doesn't need to have that accessToken (Fungible or Non-Fungible)
    * @param _contractAddress: the accessToken to check
    * @param userAddress: the address to validate
    */
    function checkIfSubscribed(address _contractAddress, address userAddress)
        public
        view
        returns (bool)
    {
        if (
            allSubscribers[_contractAddress][userAddress].subscriberAddress !=
            address(0)
        )
            if (
                allSubscribers[_contractAddress][userAddress].dateOfExpiration >
                block.timestamp
            ) return true;
            else return false;
        return false;
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
                IERC721(_contractObj.contractAddress).balanceOf(userAddress) >=
                    _contractObj.amount
                    ? true
                    : false;
        /** ERC1155 Token */
        else if (_contractObj.typeOfToken == ERC_1155)
            return
                IERC1155(_contractObj.contractAddress).balanceOf(
                    userAddress,
                    uint256(_contractObj.specifyId)
                ) >= _contractObj.amount
                    ? true
                    : false;
        /** ERC20 Token */
        else if (_contractObj.typeOfToken == ERC_20)
            return
                IERC20(_contractObj.contractAddress).balanceOf(userAddress) >=
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

    function setFee(
        address contractAddress,
        uint256 _price,
        uint256 numOfDays
    ) public onlyTokenAdmin(contractAddress) {
        allAccessTokens[contractAddress].subscription = Subscription({
            price: _price,
            duration: numOfDays * 1 days
        });
        emit SetFee(contractAddress, _price, numOfDays * 1 days);
    }

    function subscribe(address _contractAddress) external payable {
        require(
            msg.value >=
                allAccessTokens[_contractAddress].subscription.price,
            "Ether value sent is not correct"
        );

        allSubscribers[_contractAddress][msg.sender] = Subscriber({
            subscriberAddress: msg.sender,
            dateOfSubscription: block.timestamp,
            dateOfExpiration: block.timestamp +
                allAccessTokens[_contractAddress].subscription.duration
        });

        emit Subscribed(
            msg.sender,
            _contractAddress,
            allSubscribers[_contractAddress][msg.sender].dateOfSubscription,
            allSubscribers[_contractAddress][msg.sender].dateOfExpiration
        );
    }

    function getFeeForTokenAccess(address _contractAddress)
        public
        view
        returns (uint256 price, uint256 duration)
    {
        (price, duration) = (
            allAccessTokens[_contractAddress].subscription.price,
            allAccessTokens[_contractAddress].subscription.duration
        );
    }

    function disableTokenAccess(address _contractAddress)
        public
        onlyRole(ADMIN_ROLE)
    {
        require(
            allAccessTokens[_contractAddress].contractAddress != address(0),
            "Token does not exist"
        );
        delete allAccessTokens[_contractAddress];
        emit DisableTokenAccess(_contractAddress);
    }

    /** UTILITY FUNCTION **/
    function stringToBytes32(string memory source)
        public
        pure
        returns (bytes32 result)
    {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    function withrawETH() public onlyRole(ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        AddressUpgradeable.sendValue(payable(msg.sender), balance);
        emit WithdrawBalance(balance, msg.sender);
    }
}
