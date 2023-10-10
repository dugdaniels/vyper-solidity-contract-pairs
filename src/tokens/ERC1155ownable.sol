// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IERC1155Receiver {
    function onERC1155Received(address operator, address sender, uint256 id, uint256 amount, bytes calldata data)
        external
        returns (bytes4);
    function onERC1155BatchReceived(
        address operator,
        address sender,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external returns (bytes4);
}

interface IERC1155MetadataURI {
    function uri(uint256 id) external view returns (string memory);
}

contract ERC1155ownable {
    bool dynamicUri;

    address public owner;

    bool public paused;

    string baseuri;
    string public contractURI;

    string public name;
    string public symbol;

    bytes4 constant ERC165_INTERFACE_ID = 0x01ffc9a7;
    bytes4 constant ERC1155_INTERFACE_ID = 0xd9b67a26;
    bytes4 constant ERC1155_INTERFACE_ID_METADATA = 0x0e89341c;

    mapping(address => mapping(uint256 => uint256)) public balanceOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    event Paused(address account);
    event Unpaused(address account);
    event OwnershipTransferred(address previousOwner, address newOwner);
    event TransferSingle(address operator, address fromAddress, address to, uint256 id, uint256 value);
    event TransferBatch(address operator, address fromAddress, address to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address account, address operator, bool approved);
    event URI(string value, uint256 indexed id);

    constructor(string memory _name, string memory _symbol, string memory _uri, string memory _contractUri) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        baseuri = _uri;
        contractURI = _contractUri;
    }

    function pause() external {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        require(!paused, "the contract is already paused");
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        require(paused, "the contract is not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }

    function transferOwnership(address _newOwner) external {
        require(!paused, "The contract has been paused");
        require(msg.sender == owner, "Ownable: caller is not the owner");
        require(_newOwner != owner, "This account already owns the contract");
        require(_newOwner != address(0), "Transfer to the zero address not allowed. Use renounceOwnership() instead.");
        address oldOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(oldOwner, _newOwner);
    }

    function renounceOwnership() external {
        require(!paused, "The contract has been paused");
        require(msg.sender == owner, "Ownable: caller is not the owner");
        address oldOwner = owner;
        owner = address(0);
        emit OwnershipTransferred(oldOwner, address(0));
    }

    function balanceOfBatch(address[] memory _accounts, uint256[] memory _ids)
        external
        view
        returns (uint256[] memory)
    {
        require(_accounts.length == _ids.length, "ERC1155: accounts and ids length mismatch");
        uint256[] memory batchBalances = new uint256[](_accounts.length);
        uint256 j;
        for (uint256 i; i < _ids.length; i++) {
            batchBalances[i] = balanceOf[_accounts[j]][i];
            j += 1;
        }
        return batchBalances;
    }

    function mint(address _receiver, uint256 _id, uint256 _amount) external {
        require(!paused, "The contract has been paused");
        require(msg.sender == owner, "Only the contract owner can mint");
        require(_receiver != address(0), "Can not mint to ZERO ADDRESS");
        address operator = msg.sender;
        balanceOf[_receiver][_id] += _amount;
        emit TransferSingle(operator, address(0), _receiver, _id, _amount);
    }

    function mintBatch(address _receiver, uint256[] memory _ids, uint256[] memory _amounts) external {
        require(!paused, "The contract has been paused");
        require(msg.sender == owner, "Only the contract owner can mint");
        require(_receiver != address(0), "Can not mint to ZERO ADDRESS");
        require(_ids.length == _amounts.length, "ERC1155: ids and amounts length mismatch");
        address operator = msg.sender;

        for (uint256 i; i < _ids.length; i++) {
            balanceOf[_receiver][_ids[i]] += _amounts[i];
        }
        emit TransferBatch(operator, address(0), _receiver, _ids, _amounts);
    }

    function burn(uint256 _id, uint256 _amount) external {
        require(!paused, "The contract has been paused");
        require(balanceOf[msg.sender][_id] > 0, "caller does not own this ID");
        balanceOf[msg.sender][_id] -= _amount;
        emit TransferSingle(msg.sender, msg.sender, address(0), _id, _amount);
    }

    function burnBatch(uint256[] memory _ids, uint256[] memory _amounts) external {
        require(!paused, "The contract has been paused");
        require(_ids.length == _amounts.length, "ERC1155: ids and amounts length mismatch");
        address operator = msg.sender;

        for (uint256 i; i < _ids.length; i++) {
            balanceOf[msg.sender][_ids[i]] -= _amounts[i];
        }
        emit TransferBatch(msg.sender, msg.sender, address(0), _ids, _amounts);
    }

    function setApprovalForAll(address _owner, address _operator, bool _approved) external {
        require(msg.sender != _owner, "You can only set operators for your own account");
        require(!paused, "The contract has been paused");
        require(_owner != _operator, "ERC1155: setting approval status for self");
        isApprovedForAll[_owner][_operator] = _approved;
        emit ApprovalForAll(_owner, _operator, _approved);
    }

    function safeTransferFrom(address _sender, address _receiver, uint256 _id, uint256 _amount, bytes32 _bytes)
        external
    {
        require(!paused, "The contract has been paused");
        require(_receiver != address(0), "ERC1155: transfer to the zero address");
        require(_sender != _receiver);
        require(
            _sender == msg.sender || isApprovedForAll[_sender][msg.sender],
            "Caller is neither owner nor approved operator for this ID"
        );
        require(balanceOf[_sender][_id] > 0, "caller does not own this ID or ZERO balance");
        address operator = msg.sender;
        balanceOf[_sender][_id] -= _amount;
        balanceOf[_receiver][_id] += _amount;
        emit TransferSingle(operator, _sender, _receiver, _id, _amount);
    }

    function safeBatchTransferFrom(
        address _sender,
        address _receiver,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes32 _bytes
    ) external {
        require(!paused, "The contract has been paused");
        require(_receiver != address(0), "ERC1155: transfer to the zero address");
        require(_sender != _receiver);
        require(
            _sender == msg.sender || isApprovedForAll[_sender][msg.sender],
            "Caller is neither owner nor approved operator for this ID"
        );
        require(_ids.length == _amounts.length, "ERC1155: ids and amounts length mismatch");
        address operator = msg.sender;

        for (uint256 i; i < _ids.length; i++) {
            uint256 id = _ids[i];
            uint256 amount = _amounts[i];
            balanceOf[_sender][id] -= amount;
            balanceOf[_receiver][id] += amount;
        }
        emit TransferBatch(operator, _sender, _receiver, _ids, _amounts);
    }

    function setURI(string memory _uri) external {
        require(!paused, "The contract has been paused");
        require(_equal(baseuri, _uri), "new and current URI are identical");
        require(msg.sender == owner, "Only the contract owner can update the URI");
        baseuri = _uri;
        emit URI(_uri, 0);
    }

    function toggleDynUri(bool _status) external {
        require(msg.sender == owner);
        require(_status != dynamicUri, "already in desired state");
        dynamicUri = _status;
    }

    function uri(uint256 _id) external view returns (string memory) {
        if (dynamicUri) {
            return string.concat(baseuri, _uint2str(_id), ".json");
        } else {
            return baseuri;
        }
    }

    function setContractURI(string memory _contractUri) external {
        require(!paused, "The contract has been paused");
        require(_equal(contractURI, _contractUri), "new and current URI are identical");
        require(msg.sender == owner, "Only the contract owner can update the URI");
        contractURI = _contractUri;
        emit URI(_contractUri, 0);
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == ERC165_INTERFACE_ID || interfaceId == ERC1155_INTERFACE_ID
            || interfaceId == ERC1155_INTERFACE_ID_METADATA;
    }

    function _uint2str(uint256 _value) internal pure returns (string memory) {
        unchecked {
            uint256 length = _log10(_value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(_value, 10), "0123456789abcdef"))
                }
                _value /= 10;
                if (_value == 0) break;
            }
            return buffer;
        }
    }

    function _log10(uint256 _value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (_value >= 10 ** 64) {
                _value /= 10 ** 64;
                result += 64;
            }
            if (_value >= 10 ** 32) {
                _value /= 10 ** 32;
                result += 32;
            }
            if (_value >= 10 ** 16) {
                _value /= 10 ** 16;
                result += 16;
            }
            if (_value >= 10 ** 8) {
                _value /= 10 ** 8;
                result += 8;
            }
            if (_value >= 10 ** 4) {
                _value /= 10 ** 4;
                result += 4;
            }
            if (_value >= 10 ** 2) {
                _value /= 10 ** 2;
                result += 2;
            }
            if (_value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    function _equal(string memory a, string memory b) internal pure returns (bool) {
        return bytes(a).length == bytes(b).length && keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
