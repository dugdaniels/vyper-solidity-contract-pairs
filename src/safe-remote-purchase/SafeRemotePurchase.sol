// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SafeRemotePurchase {
    uint256 public value;
    address public seller;
    address public buyer;
    bool public unlocked;
    bool public ended;

    constructor() payable {
        // The seller initializes the contract by
        // posting a safety deposit of 2*value of the item up for sale.
        require(msg.value % 2 == 0, "Deposit must be even");
        value = msg.value / 2;
        seller = msg.sender;
        unlocked = true;
    }

    function abort() external {
        // Is the contract still refundable?
        require(unlocked, "Contract is not refundable");

        // Only the seller can refund
        // his deposit before any buyer purchases the item.
        require(msg.sender == seller, "Only seller can abort");

        // Refunds the seller and deletes the contract.
        selfdestruct(payable(seller));
    }

    function purchase() external payable {
        // Is the contract still open (is the item still up
        // for sale)?
        require(unlocked, "Contract is not open for purchase");

        // Is the deposit the correct value?
        require(msg.value == 2 * value, "Incorrect deposit value");
        buyer = msg.sender;
        unlocked = false;
    }

    function received() external {
        // Is the item already purchased and pending
        // confirmation from the buyer?
        require(!unlocked, "Item not yet purchased");
        require(msg.sender == buyer, "Only buyer can confirm receipt");
        require(!ended, "Transaction already ended");

        ended = true;

        // Return the buyer's deposit (=value) to the buyer.
        (bool sent,) = buyer.call{value: value}("");
        require(sent, "Failed to send Ether");

        // Return the seller's deposit (=2*value) and the
        // purchase price (=value) to the seller.
        selfdestruct(payable(seller));
    }
}
