// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Company {
    event Transfer(address indexed sender, address indexed receiver, uint256 value);
    event Buy(address indexed buyer, uint256 buyOrder);
    event Sell(address indexed seller, uint256 sellOrder);
    event Pay(address indexed vendor, uint256 amount);

    // Initiate the variables for the company and it's own shares.
    address public company;
    uint256 public totalShares;
    uint256 public price;

    // Store a ledger of stockholder holdings.
    mapping(address => uint256) public holdings;

    // Set up the company.
    constructor(address _company, uint256 _totalShares, uint256 _initialPrice) {
        require(_totalShares > 0, "Total shares must be greater than 0");
        require(_initialPrice > 0, "Initial price must be greater than 0");

        company = _company;
        totalShares = _totalShares;
        price = _initialPrice;

        // The company holds all the shares at first, but can sell them all.
        holdings[company] = _totalShares;
    }

    // Public function to allow external access to _stockAvailable
    function stockAvailable() external view returns (uint256) {
        return _stockAvailable();
    }

    // Give some value to the company and get stock in return.
    function buyStock() external payable {
        // Note: full amount is given to company (no fractional shares),
        //       so be sure to send exact amount to buy shares
        uint256 buyOrder = msg.value / price; // rounds down

        // Check that there are enough shares to buy.
        require(_stockAvailable() >= buyOrder, "Not enough stock available");

        // Take the shares off the market and give them to the stockholder.
        holdings[company] -= buyOrder;
        holdings[msg.sender] += buyOrder;

        // Log the buy event.
        emit Buy(msg.sender, buyOrder);
    }

    // Public function to allow external access to _getHolding
    function getHolding(address _stockholder) external view returns (uint256) {
        return _getHolding(_stockholder);
    }

    // Return the amount the company has on hand in cash.
    function cash() external view returns (uint256) {
        return address(this).balance;
    }

    // Give stock back to the company and get money back as ETH.
    function sellStock(uint256 sellOrder) external {
        require(sellOrder > 0, "Invalid sell order");
        // Otherwise, this would fail at call() below,
        // due to an OOG error (there would be zero value available for gas).

        // You can only sell as much stock as you own.
        require(_getHolding(msg.sender) >= sellOrder, "Not enough stock to sell");

        // Check that the company can pay you.
        require(address(this).balance >= sellOrder * price, "Not enough balance to pay");

        // Sell the stock, send the proceeds to the user
        // and put the stock back on the market.
        holdings[msg.sender] -= sellOrder;
        holdings[company] += sellOrder;

        (bool sent,) = msg.sender.call{value: sellOrder * price}("");
        require(sent, "Failed to send Ether");

        // Log the sell event.
        emit Sell(msg.sender, sellOrder);
    }

    // Transfer stock from one stockholder to another. (Assume that the
    // receiver is given some compensation, but this is not enforced.)
    function transferStock(address receiver, uint256 transferOrder) external {
        // This is similar to sellStock above.
        require(transferOrder > 0, "Invalid transfer order");
        // Similarly, you can only trade as much stock as you own.
        require(_getHolding(msg.sender) >= transferOrder, "Not enough stock to transfer");

        // Debit the sender's stock and add to the receiver's address.
        holdings[msg.sender] -= transferOrder;
        holdings[receiver] += transferOrder;

        // Log the transfer event.
        emit Transfer(msg.sender, receiver, transferOrder);
    }

    // Allow the company to pay someone for services rendered.
    function payBill(address vendor, uint256 amount) external {
        // Only the company can pay people.
        require(msg.sender == company, "Only the company can pay bills");
        // Also, it can pay only if there's enough to pay them with.
        require(address(this).balance >= amount, "Not enough balance to pay the bill");

        // Pay the bill!
        (bool sent,) = vendor.call{value: amount}("");
        require(sent, "Failed to send Ether");

        // Log the payment event.
        emit Pay(vendor, amount);
    }

    // Public function to allow external access to _debt
    function debt() external view returns (uint256) {
        return _debt();
    }

    // Return the cash holdings minus the debt of the company.
    // The share debt or liability only is included here,
    // but of course all other liabilities can be included.
    function worth() external view returns (uint256) {
        return address(this).balance - _debt();
    }

    // Return the amount in wei that a company has raised in stock offerings.
    function _debt() internal view returns (uint256) {
        return (totalShares - _stockAvailable()) * price;
    }

    // Find out how much stock the company holds
    function _stockAvailable() internal view returns (uint256) {
        return holdings[company];
    }

    // Find out how much stock any address (that's owned by someone) has.
    function _getHolding(address _stockholder) internal view returns (uint256) {
        return holdings[_stockholder];
    }
}
