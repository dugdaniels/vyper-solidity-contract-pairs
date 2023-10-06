// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface Factory {
    function register() external;
}

contract Exchange {
    ERC20 public token;
    Factory public factory;

    constructor(ERC20 _token, Factory _factory) {
        token = _token;
        factory = _factory;
    }

    function initialize() external {
        // Anyone can safely call this function because of EXTCODEHASH
        factory.register();
    }

    // NOTE: This contract restricts trading to only be done by the factory.
    //       A practical implementation would probably want counter-pairs
    //       and liquidity management features for each exchange pool.

    function receiveToken(address _from, uint256 _amt) external {
        require(msg.sender == address(factory), "Must be called by the factory");
        bool success = token.transferFrom(_from, address(this), _amt);
        require(success, "TransferFrom failed");
    }

    function transferToken(address _to, uint256 _amt) external {
        require(msg.sender == address(factory), "Must be called by the factory");
        bool success = token.transfer(_to, _amt);
        require(success, "Transfer failed");
    }
}
