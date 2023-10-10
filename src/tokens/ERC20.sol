// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract ERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply;
    address minter;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _supply) {
        uint256 initSupply = _supply * 10 ** uint256(_decimals);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        balanceOf[msg.sender] = initSupply;
        totalSupply = initSupply;
        minter = msg.sender;
        emit Transfer(address(0), msg.sender, initSupply);
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function mint(address _to, uint256 _value) external {
        require(msg.sender == minter);
        require(_to != address(0));
        totalSupply += _value;
        balanceOf[_to] += _value;
        emit Transfer(address(0), _to, _value);
    }

    function _burn(address _to, uint256 _value) internal {
        require(_to != address(0));
        totalSupply -= _value;
        balanceOf[_to] -= _value;
        emit Transfer(_to, address(0), _value);
    }

    function burn(uint256 _value) external {
        _burn(msg.sender, _value);
    }

    function burnFrom(address _to, uint256 _value) external {
        allowance[_to][msg.sender] -= _value;
        _burn(_to, _value);
    }
}
