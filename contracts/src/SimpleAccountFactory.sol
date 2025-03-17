// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "openzeppelin-contracts/contracts/utils/Create2.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/EIP712.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "src/SimpleAccount.sol";

struct User {
    uint256 id;
    bytes32[2] publicKey;
    address account;
}

/**
 * A sample factory contract for SimpleAccount with meta transaction support
 */
contract SimpleAccountFactory is EIP712 {
    using ECDSA for bytes32;

    SimpleAccount public immutable accountImplem;
    IEntryPoint public immutable entryPoint;
    bytes32 public constant SALT = keccak256("hocuspocusxyz");

    mapping(uint256 id => User user) public users;
    mapping(address => uint256) public nonces;

    // EIP-712 type hash for meta transaction
    bytes32 private constant SAVE_USER_TYPEHASH = 
        keccak256("SaveUser(uint256 id,bytes32[2] publicKey,uint256 nonce)");

    constructor(IEntryPoint _entryPoint) EIP712("SimpleAccountFactory", "1") {
        entryPoint = _entryPoint;
        accountImplem = new SimpleAccount(_entryPoint);
    }

    /**
     * Meta transaction for saving user with signature verification
     * @param id User ID
     * @param publicKey User's public key
     * @param signature Signature by the sender
     */
    function saveUserWithMetaTx(
        uint256 id, 
        bytes32[2] memory publicKey, 
        bytes memory signature
    ) external {
        // Verify the signature
        bytes32 structHash = keccak256(
            abi.encode(
                SAVE_USER_TYPEHASH,
                id,
                publicKey[0],
                publicKey[1],
                nonces[msg.sender]++
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.toECDSASignerAddress(signature);
        
        require(signer == msg.sender, "Invalid signature");

        users[id] = User(id, publicKey, this.getAddress(publicKey));
    }

    /**
     * Original saveUser method for direct transactions
     */
    function saveUser(uint256 id, bytes32[2] memory publicKey) external {
        users[id] = User(id, publicKey, this.getAddress(publicKey));
    }

    function getUser(uint256 id) external view returns (User memory) {
        return users[id];
    }

    /**
     * Create an account, and return its address.
     * Returns the address even if the account is already deployed.
     * Note that during UserOperation execution, this method is called only if the account is not deployed.
     * This method returns an existing account address so that entryPoint.getSenderAddress() would work even after account creation.
     */
    function createAccount(
        bytes32[2] memory publicKey
    ) external payable returns (SimpleAccount) {
        address addr = getAddress(publicKey);

        // Prefund the account with msg.value
        if (msg.value > 0) {
            entryPoint.depositTo{value: msg.value}(addr);
        }

        // Otherwise, no-op if the account is already deployed
        uint codeSize = addr.code.length;
        if (codeSize > 0) {
            return SimpleAccount(payable(addr));
        }

        return
            SimpleAccount(
                payable(
                    new ERC1967Proxy{salt: SALT}(
                        address(accountImplem),
                        abi.encodeCall(SimpleAccount.initialize, (publicKey))
                    )
                )
            );
    }

    /**
     * Meta transaction for creating account with signature verification
     */
    function createAccountWithMetaTx(
        bytes32[2] memory publicKey,
        bytes memory signature
    ) external payable returns (SimpleAccount) {
        // Verify the signature
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("CreateAccount(bytes32[2] publicKey,uint256 nonce)"),
                publicKey[0],
                publicKey[1],
                nonces[msg.sender]++
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = hash.toECDSASignerAddress(signature);
        
        require(signer == msg.sender, "Invalid signature");

        return createAccount(publicKey);
    }

    /**
     * Calculate the counterfactual address of this account as it would be returned by createAccount()
     */
    function getAddress(
        bytes32[2] memory publicKey
    ) public view returns (address) {
        return
            Create2.computeAddress(
                SALT,
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            address(accountImplem),
                            abi.encodeCall(
                                SimpleAccount.initialize,
                                (publicKey)
                            )
                        )
                    )
                )
            );
    }

    function getpubkey(uint256 id) public view returns (bytes32[2] memory) {
        return users[id].publicKey;
    }
}