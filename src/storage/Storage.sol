// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Storage {
    int128 public storedData;

    constructor(int128 _x) {
        storedData = _x;
    }

    function set(int128 _x) external {
        storedData = _x;
    }
}
