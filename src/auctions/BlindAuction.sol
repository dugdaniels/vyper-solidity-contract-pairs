// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract BlindAuction {
    struct Bid {
        bytes32 blindedBid;
        uint256 deposit;
    }

    // number of bids that can be placed by one address to 128 in this example
    uint256 constant MAX_BIDS = 128;

    // Event for logging that auction has ended
    event AuctionEnded(address highestBidder, uint256 highestBid);

    // Auction parameters
    address public beneficiary;
    uint256 public biddingEnd;
    uint256 public revealEnd;

    //  Set to true at the end of auction, disallowing any new bids
    bool public ended;

    //  Final auction state
    uint256 public highestBid;
    address public highestBidder;

    // State of the bids
    mapping(address => Bid[128]) public bids;
    mapping(address => uint256) public bidCounts;

    // Allowed withdrawals of previous bids
    mapping(address => uint256) public pendingReturns;

    // Create a blinded auction with `_biddingTime` seconds bidding time and
    // `_revealTime` seconds reveal time on behalf of the beneficiary address
    // `_beneficiary`.
    constructor(address _beneficiary, uint256 _biddingTime, uint256 _revealTime) {
        beneficiary = _beneficiary;
        biddingEnd = block.timestamp + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
    }

    // Place a blinded bid with:
    //
    // _blindedBid = keccak256(concat(
    //       convert(value, bytes32),
    //       convert(fake, bytes32),
    //       secret)
    // )
    //
    // The sent ether is only refunded if the bid is correctly revealed in the
    // revealing phase. The bid is valid if the ether sent together with the bid is
    // at least "value" and "fake" is not true. Setting "fake" to true and sending
    // not the exact amount are ways to hide the real bid but still make the
    // required deposit. The same address can place multiple bids.
    function bid(bytes32 _blindedBid) external payable {
        // Check if bidding period is still open
        require(block.timestamp < biddingEnd, "Bidding period has ended");

        // Check that payer hasn't already placed maximum number of bids
        uint256 numBids = bidCounts[msg.sender];
        require(numBids < MAX_BIDS, "Maximum number of bids reached");

        // Add bid to mapping of all bids
        bids[msg.sender][uint256(numBids)] = Bid({blindedBid: _blindedBid, deposit: msg.value});
        bidCounts[msg.sender]++;
    }

    // Returns a boolean value, `True` if bid placed successfully, `False` otherwise.
    function placeBid(address bidder, uint256 _value) internal returns (bool) {
        // If bid is less than highest bid, bid fails
        if (_value <= highestBid) {
            return false;
        }

        // Refund the previously highest bidder
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] += highestBid;
        }

        // Place bid successfully and update auction state
        highestBid = _value;
        highestBidder = bidder;

        return true;
    }

    // Reveal your blinded bids. You will get a refund for all correctly blinded
    // invalid bids and for all bids except for the totally highest.
    function reveal(
        uint128 _numBids,
        uint256[128] memory _values,
        bool[128] memory _fakes,
        bytes32[128] memory _secrets
    ) external {
        // Check that bidding period is over
        require(block.timestamp > biddingEnd, "Bidding period has not ended yet");

        // Check that reveal end has not passed
        require(block.timestamp < revealEnd, "Reveal period has ended");

        //Check that number of bids being revealed matches log for sender
        require(_numBids == bidCounts[msg.sender], "Number of bids does not match");

        // Calculate refund for sender
        uint256 refund = 0;
        for (uint128 i = 0; i < MAX_BIDS; i++) {
            // Note that loop may break sooner than 128 iterations if i >= _numBids
            if (i >= _numBids) {
                break;
            }

            // Get bid to check
            Bid memory bidToCheck = bids[msg.sender][i];

            // Check against encoded packet
            uint256 value = _values[i];
            bool fake = _fakes[i];
            bytes32 secret = _secrets[i];
            bytes32 blindedBid = keccak256(abi.encodePacked(value, fake, secret));

            // Bid was not actually revealed
            // Do not refund deposit
            require(blindedBid == bidToCheck.blindedBid, "Invalid blinded bid");

            // Add deposit to refund if bid was indeed revealed
            refund += bidToCheck.deposit;
            if (!fake && bidToCheck.deposit >= value) {
                if (placeBid(msg.sender, value)) {
                    refund -= value;
                }
            }

            // Make it impossible for the sender to re-claim the same deposit
            bidToCheck.blindedBid = bytes32(0);
        }

        // Send refund if non-zero
        if (refund > 0) {
            (bool sent,) = msg.sender.call{value: refund}("");
            require(sent, "Failed to send refund");
        }
    }

    // Withdraw a bid that was overbid.
    function withdraw() external {
        // Check that there is an allowed pending return.
        uint256 pendingAmount = pendingReturns[msg.sender];
        if (pendingAmount > 0) {
            // If so, set pending returns to zero to prevent recipient from calling
            // this function again as part of the receiving call before `transfer`
            // returns (see the remark above about conditions -> effects ->
            // interaction).
            pendingReturns[msg.sender] = 0;

            // Then send return
            (bool sent,) = msg.sender.call{value: pendingAmount}("");
            require(sent, "Failed to send refund");
        }
    }

    // End the auction and send the highest bid to the beneficiary.
    function auctionEnd() external {
        // Check that reveal end has passed
        require(block.timestamp > revealEnd, "Reveal period has not ended yet");

        // Check that auction has not already been marked as ended
        require(!ended, "Auction already ended");

        // Log auction ending and set flag
        emit AuctionEnded(highestBidder, highestBid);
        ended = true;

        // Transfer funds to beneficiary
        (bool sent,) = beneficiary.call{value: highestBid}("");
        require(sent, "Failed to send refund");
    }
}
