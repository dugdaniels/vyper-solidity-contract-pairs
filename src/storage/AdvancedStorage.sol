// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract DataStorage {
    event DataChange(address indexed setter, int128 value);

    int128 public storedData;

    constructor(int128 _x) {
        storedData = _x;
    }

    function set(int128 _x) external {
        require(_x >= 0, "No negative values");
        require(storedData < 100, "Storage is locked when 100 or more is stored");

        storedData = _x;
        emit DataChange(msg.sender, _x);
    }

    function reset() external {
        storedData = 0;
    }
}
