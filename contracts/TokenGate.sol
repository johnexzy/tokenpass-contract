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

    /** =====SUPPORTED ROLES======= **/
    /** The Deployer is inherits the admin role */
    bytes32 public constant ADMIN_ROLE = 0x00;

    /** FEE */
    uint256 public feePercent = 2;
    uint256 public feeGeneratedFromCharges = 0;
    /** EVENTS **/
    event Initialized(address indexed initializer);

    event Subscribed(
        address indexed susbscriber,
        address indexed locker,
        address indexed contractAddress,
        uint256 dateOfSubscription,
        uint256 dateOfExpiration
    );

    event WithdrawBalancePaidForToken(
        address indexed tokenAdress,
        uint256 indexed amount,
        address indexed caller
    );
    /**
     * The schema used in initislizing Access Tokens
     *
     */
    struct AccessToken {
        address contractAddress; // contract address of the access token (ERC20, ERC721 or ERC1155)
        address locker; // address of the locker.
        bytes32 typeOfToken; // "ERC20" or "ERC721" or "ERC1155" in bytes32
        int256 specifyId; // -1 if not needed. required for ERC1155 and optional for ERC721
        Subscription subscription; // set price and duration for subscription
        uint256 amount; //required
    }

    struct Subscription {
        bool isSubscribable;
        uint256 price;
        uint256 duration;
    }

    struct Subscriber {
        address subscriberAddress;
        uint256 dateOfSubscription;
        uint256 dateOfExpiration;
    }

    /**
     * maps address of locker => address of contract => user address => subscriber details
     **/
    mapping(address => mapping(address => mapping(address => Subscriber)))
        public allSubscribers;

    /**
     *  maps address of locker => address of token => balance
     */
    mapping(address => mapping(address => uint256)) public ethBalanceForToken;

    /**
     * Constructor. sets Role to DEFAULT_ADMIN_ROLE
     */
    function initialize() public initializer {
        _setupRole(ADMIN_ROLE, msg.sender);

        emit Initialized(msg.sender);
    }

    /**
     * @dev checkAccess: checks if an address meets the requirement for access set by an accessToken moderator.
     * first checks if the address has an active subscription for the accessToken,
     * else, checks if the address has the accessToken (Fungible or Non-Fungible)
     * @param _accessToken: accessToken that the function wants to check user's access in.
     * address must be initialized before using
     * @param _userAddress: the address that the function wants to validate
     */
    function checkAccess(AccessToken memory _accessToken, address _userAddress)
        public
        view
        returns (bool)
    {
        if (_accessToken.contractAddress != address(0)) {
            if (checkIfSubscribed(_accessToken, _userAddress)) return true;
            if (
                _accessToken.typeOfToken == ERC_721 &&
                handleERC721Access(_accessToken, _userAddress)
            ) return true;
            else if (
                _accessToken.typeOfToken == ERC_1155 &&
                handleERC1155Access(_accessToken, _userAddress)
            ) return true;
            else if (
                _accessToken.typeOfToken == ERC_20 &&
                handleERC20Access(_accessToken, _userAddress)
            ) return true;
        }
        return false;
    }

    /**
     * @dev checkIfSubscribed(): checks if an address has an actibe subscription in an accessToken.
     * the address doesn't need to have that accessToken (Fungible or Non-Fungible)
     * @param _accessToken: the accessToken to check
     * @param _userAddress: the address to validate
     */
    function checkIfSubscribed(
        AccessToken memory _accessToken,
        address _userAddress
    ) public view returns (bool) {
        if (
            allSubscribers[_accessToken.locker][_accessToken.contractAddress][
                _userAddress
            ].subscriberAddress != address(0)
        )
            if (
                allSubscribers[_accessToken.locker][
                    _accessToken.contractAddress
                ][_userAddress].dateOfExpiration > block.timestamp
            ) return true;
            else return false;
        return false;
    }

    /**
     * @dev handleERC721Access(): handles the call to the  main logic of validating an address' access in an accessToken.
     * See checkAccess() function for usage
     * @param _accessToken: the address of the accessToken
     * @param _userAddress: the address to be validated
     **/
    function handleERC721Access(
        AccessToken memory _accessToken,
        address _userAddress
    ) internal view returns (bool) {
        if (_accessToken.specifyId == -1)
            return balanceOf(_accessToken, _userAddress);
        if (_accessToken.specifyId != -1)
            return
                ownerOf(
                    _accessToken.contractAddress,
                    _accessToken.specifyId,
                    _userAddress
                );
        return false;
    }

    /**
     * @dev handleERC1155Access(): handles the call to the  main logic of validating an address' access in an accessToken.
     * See checkAccess() function for usage
     * @param _accessToken: the address of the accessToken
     * @param _userAddress: the address to be validated
     **/
    function handleERC1155Access(
        AccessToken memory _accessToken,
        address _userAddress
    ) internal view returns (bool) {
        return balanceOf(_accessToken, _userAddress);
    }

    /**
     * @dev handleERC20Access(): handles the call to the main logic of validating an address' access in an accessToken.
     * See checkAccess() function for usage
     * @param _accessToken: the address of the accessToken
     * @param _userAddress: the address to be validated
     **/
    function handleERC20Access(
        AccessToken memory _accessToken,
        address _userAddress
    ) internal view returns (bool) {
        return balanceOf(_accessToken, _userAddress);
    }

    /**
     * @dev balanceOf(): handles the main logic of validating an address' access in an accessToken.
     *
     * For each of ERC721, ERC1155 and ERC20, this function creates an instance of the standard using the accessToken's address
     * the .typeOfToken attribute is used to determine which ERC standard the accessToken belongs to.
     *
     * the balanceOf() functions in each of the ERC token standards callled on their instantiation differ in design and functionality.
     * check out this Openzeppelin docs to understand more https://docs.openzeppelin.com/contracts/3.x/tokens#standards
     *
     * See handleERC20Access() / handleERC1155Access() / handleERC721Access() functions for usage
     *
     * @param _accessToken: the address of the accessToken
     * @param _userAddress: the address to be validated
     **/
    function balanceOf(AccessToken memory _accessToken, address _userAddress)
        public
        view
        returns (bool)
    {
        /** ERC721 Token */
        if (_accessToken.typeOfToken == ERC_721)
            return
                IERC721(_accessToken.contractAddress).balanceOf(_userAddress) >=
                    _accessToken.amount
                    ? true
                    : false;
        /** ERC1155 Token */
        else if (_accessToken.typeOfToken == ERC_1155)
            return
                IERC1155(_accessToken.contractAddress).balanceOf(
                    _userAddress,
                    uint256(_accessToken.specifyId)
                ) >= _accessToken.amount
                    ? true
                    : false;
        /** ERC20 Token */
        else if (_accessToken.typeOfToken == ERC_20)
            return
                IERC20(_accessToken.contractAddress).balanceOf(_userAddress) >=
                    _accessToken.amount
                    ? true
                    : false;
        return false;
    }

    /**
     * @dev ownerOf(): calls ERC721 ownerOf() function which returns the address that owns a token,
     * this function then compares the address returned to the _userAddress and returns true if matched, else returns false.
     *
     * @param _contractAddress: address of the ERC721 accessToken
     * @param _id: ID of the NFT to get the owner of
     * @param _userAddress: the address to compare
     **/
    function ownerOf(
        address _contractAddress,
        int256 _id,
        address _userAddress
    ) public view returns (bool) {
        return IERC721(_contractAddress).ownerOf(uint256(_id)) == _userAddress;
    }

    /**
     * @dev subscribe(): subscribes an address to an accessToken for a duration specified by the acccessToken's moderator,
     * subscribed accounts will have all access to the accessTokens services as an account that has the accessToken (Fungible or Non-Fungible)
     *
     * @param _accessToken: the accessToken's object
     **/
    function subscribe(AccessToken memory _accessToken) external payable {
        require(
            _accessToken.subscription.isSubscribable,
            "Subscription to this Access Token is Deactivated"
        );
        require(
            msg.value == _accessToken.subscription.price,
            "Ether value sent is not correct"
        );

        allSubscribers[_accessToken.locker][_accessToken.contractAddress][
            msg.sender
        ] = Subscriber({
            subscriberAddress: msg.sender,
            dateOfSubscription: block.timestamp,
            dateOfExpiration: block.timestamp +
                _accessToken.subscription.duration
        });

        ethBalanceForToken[_accessToken.locker][
            _accessToken.contractAddress
        ] += msg.value;

        emit Subscribed(
            msg.sender,
            _accessToken.locker,
            _accessToken.contractAddress,
            allSubscribers[_accessToken.locker][_accessToken.contractAddress][
                msg.sender
            ].dateOfSubscription,
            allSubscribers[_accessToken.locker][_accessToken.contractAddress][
                msg.sender
            ].dateOfExpiration
        );
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

    function setFeePercent(uint256 _fee) public {
        feePercent = _fee;
    }

    function ethBalancePaidForTokenAccess(address _contractAddress)
        public
        view
        returns (uint256)
    {
        return ethBalanceForToken[msg.sender][_contractAddress];
    }

    function withdrawBalancePaidForToken(address _contractAddress) external {
        require(
            ethBalancePaidForTokenAccess(_contractAddress) > 0,
            "Value too low"
        );
        uint256 ethBalance = ethBalancePaidForTokenAccess(_contractAddress);
        uint256 charges = ethBalance * (feePercent / 100);
        uint256 chargesApplied = ethBalance - charges;
        feeGeneratedFromCharges += charges;
        ethBalanceForToken[msg.sender][_contractAddress] = 0;
        AddressUpgradeable.sendValue(payable(msg.sender), chargesApplied);
        emit WithdrawBalancePaidForToken(
            _contractAddress,
            ethBalance,
            msg.sender
        );
    }

    function withdrawProceedsFromAccruedCharges()
        external
        onlyRole(ADMIN_ROLE)
    {
        AddressUpgradeable.sendValue(
            payable(msg.sender),
            feeGeneratedFromCharges
        );
        feeGeneratedFromCharges = 0;
    }

    function emergencyWithdraw() external onlyRole(ADMIN_ROLE) {
        AddressUpgradeable.sendValue(
            payable(msg.sender),
            address(this).balance
        );
    }
}
