// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface ERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract OnChainMarketMaker {
    uint256 public totalEthQty;
    uint256 public totalTokenQty;
    // Constant set in `initiate` that's used to calculate
    // the amount of ether/tokens that are exchanged
    uint256 public invariant;
    ERC20 tokenAddress;
    address public owner;

    // Sets the on chain market maker with its owner, intial token quantity,
    // and initial ether quantity
    function initiate(address _tokenAddr, uint256 _tokenQuantity) external payable {
        require(invariant == 0, "Market maker already initiated");
        tokenAddress = ERC20(_tokenAddr);
        tokenAddress.transferFrom(msg.sender, address(this), _tokenQuantity);
        owner = msg.sender;
        totalTokenQty = _tokenQuantity;
        invariant = msg.value * _tokenQuantity;
        assert(invariant > 0);
    }

    // Sells ether to the contract in exchange for tokens (minus a fee)
    function ethToTokens() external payable {
        uint256 fee = msg.value / 500;
        uint256 ethInPurchase = msg.value - fee;
        uint256 newTotalEth = totalEthQty + ethInPurchase;
        uint256 newTotalTokens = invariant / newTotalEth;
        tokenAddress.transfer(msg.sender, totalTokenQty - newTotalTokens);
        totalEthQty = newTotalEth;
        totalTokenQty = newTotalTokens;
    }

    // Sells tokens to the contract in exchange for ether
    function tokensToEth(uint256 sellQuantity) external {
        tokenAddress.transferFrom(msg.sender, address(this), sellQuantity);
        uint256 newTotalTokens = totalTokenQty + sellQuantity;
        uint256 newTotalEth = invariant / newTotalTokens;
        uint256 ethToSend = totalEthQty - newTotalEth;

        (bool sent,) = msg.sender.call{value: ethToSend}("");
        require(sent, "Failed to send Ether");

        totalEthQty = newTotalEth;
        totalTokenQty = newTotalTokens;
    }

    // Owner can withdraw their funds and destroy the market maker
    function ownerWithdraw() external {
        require(msg.sender == owner, "Only owner can withdraw");
        tokenAddress.transfer(owner, totalTokenQty);
        selfdestruct(payable(owner));
    }
}
