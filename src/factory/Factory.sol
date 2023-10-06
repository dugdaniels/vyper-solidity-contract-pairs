// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface Exchange {
    function token() external view returns (ERC20);
    function receiveToken(address from, uint256 amount) external;
    function transferToken(address to, uint256 amount) external;
}

contract Factory {
    bytes32 public exchangeCodehash;

    // Maps token addresses to exchange addresses
    mapping(address => Exchange) public exchanges;

    constructor(bytes32 _exchangeCodehash) {
        // Register the exchange code hash during deployment of the factory
        exchangeCodehash = _exchangeCodehash;
    }

    // NOTE: Could implement fancier upgrade logic around exchangeCodehash
    //       For example, allowing the deployer of this contract to change this
    //       value allows them to use a new contract if the old one has an issue.
    //       This would trigger a cascade effect across all exchanges that would
    //       need to be handled appropiately.

    function register() external {
        // Verify code hash is the exchange's code hash
        require(msg.sender.codehash == exchangeCodehash, "Invalid exchange codehash");

        // Save a lookup for the exchange
        // NOTE: Use exchange's token address because it should be globally unique
        // NOTE: Should do checks that it hasn't already been set,
        //       which has to be rectified with any upgrade strategy.
        Exchange exchange = Exchange(msg.sender);
        exchanges[address(exchange.token())] = exchange;
    }

    function trade(ERC20 _token1, ERC20 _token2, uint256 _amount) external {
        // Perform a straight exchange of token1 to token 2 (1:1 price)
        // NOTE: Any practical implementation would need to solve the price oracle problem
        exchanges[address(_token1)].receiveToken(msg.sender, _amount);
        exchanges[address(_token2)].transferToken(msg.sender, _amount);
    }
}
