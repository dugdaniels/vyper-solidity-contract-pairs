// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract NameRegistry {
    mapping(bytes => address) public registry;

    function register(bytes memory name, address owner) external {
        require(registry[name] == address(0), "Name already registered");
        registry[name] = owner;
    }

    function lookup(bytes memory name) external view returns (address) {
        return registry[name];
    }
}
