// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data)
        external
        returns (bytes4);
}

contract ERC721 {
    event Transfer(address indexed sender, address indexed receiver, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    mapping(uint256 => address) private idToOwner;
    mapping(uint256 => address) private idToApprovals;
    mapping(address => uint256) private ownerToNFTokenCount;
    mapping(address => mapping(address => bool)) private ownerToOperators;

    address public minter;
    string public baseURL;

    constructor() {
        minter = msg.sender;
        baseURL = "https://api.babby.xyz/metadata/";
    }

    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        return _interfaceId == 0x01ffc9a7 || _interfaceId == 0x80ac58cd;
    }

    function balanceOf(address _owner) external view returns (uint256) {
        require(_owner != address(0));
        return ownerToNFTokenCount[_owner];
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        address owner = idToOwner[_tokenId];
        require(owner != address(0));
        return owner;
    }

    function getApproved(uint256 _tokenId) external view returns (address) {
        require(idToOwner[_tokenId] != address(0));
        return idToApprovals[_tokenId];
    }

    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return ownerToOperators[_owner][_operator];
    }

    function _isApprovedOrOwner(address _spender, uint256 _tokenId) private view returns (bool) {
        address owner = idToOwner[_tokenId];
        bool spenderIsOwner = owner == _spender;
        bool spenderIsApproved = _spender == idToApprovals[_tokenId];
        bool spenderIsApprovedForAll = (ownerToOperators[owner])[_spender];
        return (spenderIsOwner || spenderIsApproved) || spenderIsApprovedForAll;
    }

    function _addTokenTo(address _to, uint256 _tokenId) private {
        require(idToOwner[_tokenId] == address(0));
        idToOwner[_tokenId] = _to;
        ownerToNFTokenCount[_to] += 1;
    }

    function _removeTokenFrom(address _from, uint256 _tokenId) private {
        require(idToOwner[_tokenId] == _from);
        idToOwner[_tokenId] = address(0);
        ownerToNFTokenCount[_from] -= 1;
    }

    function _clearApproval(address _owner, uint256 _tokenId) private {
        require(idToOwner[_tokenId] == _owner);
        if (idToApprovals[_tokenId] != address(0)) {
            idToApprovals[_tokenId] = address(0);
        }
    }

    function _transferFrom(address _from, address _to, uint256 _tokenId, address _sender) private {
        require(_isApprovedOrOwner(_sender, _tokenId));
        require(_to != address(0));

        _clearApproval(_from, _tokenId);
        _removeTokenFrom(_from, _tokenId);
        _addTokenTo(_to, _tokenId);

        emit Transfer(_from, _to, _tokenId);
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        _transferFrom(_from, _to, _tokenId, msg.sender);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes memory _data) external {
        _transferFrom(_from, _to, _tokenId, msg.sender);
        if (_isContract(_to)) {
            bytes4 returnValue = ERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
            require(returnValue == ERC721Receiver.onERC721Received.selector);
        }
    }

    function approve(address _approved, uint256 _tokenId) external {
        address owner = idToOwner[_tokenId];
        require(owner != address(0));
        require(_approved != owner);

        bool senderIsOwner = idToOwner[_tokenId] == msg.sender;
        bool senderIsApprovedForAll = ownerToOperators[owner][msg.sender];
        require(senderIsOwner || senderIsApprovedForAll);

        idToApprovals[_tokenId] = _approved;
        emit Approval(owner, _approved, _tokenId);
    }

    function setApprovalForAll(address _operator, bool _approved) external {
        require(msg.sender != _operator);
        ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    function mint(address _to, uint256 _tokenId) external returns (bool) {
        require(msg.sender == minter);
        require(_to != address(0));
        _addTokenTo(_to, _tokenId);
        emit Transfer(address(0), _to, _tokenId);
        return true;
    }

    function burn(uint256 _tokenId) external {
        require(_isApprovedOrOwner(msg.sender, _tokenId));
        address owner = idToOwner[_tokenId];
        require(owner != address(0));
        _clearApproval(owner, _tokenId);
        _removeTokenFrom(owner, _tokenId);
        emit Transfer(owner, address(0), _tokenId);
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return string.concat(baseURL, _uint2str(tokenId));
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

    function _isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
