// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SingleSidedAMM {
    // Token reserves
    uint256 public reserveA;
    uint256 public reserveB;

    // Tokens (For simplicity, we'll represent tokens as balances)
    mapping(address => uint256) public balanceA;
    mapping(address => uint256) public balanceB;

    struct Stream {
        uint256 totalAmount;
        uint256 amountSwapped;
        uint256 streamCount;
        uint256 nextChunkIndex;
        bool isTokenA; // true if swapping Token A for B
    }

    mapping(address => Stream) public streams;

    event SwapEntered(address indexed user, uint256 totalAmount, bool isTokenA);
    event StreamProcessed(address indexed user, uint256 chunkAmount, uint256 amountOut, bool isTokenA);

    // Scaling factor for streamCount calculation
    uint256 public constant scalingFactor = 1000;

    constructor(uint256 _reserveA, uint256 _reserveB) {
        reserveA = _reserveA;
        reserveB = _reserveB;
    }

    // User initiates a swap
    function enterSwap(uint256 amount, bool isTokenA) external {
        require(amount > 0, "Amount must be greater than zero");
        uint256 streamCount;
        if (isTokenA) {
            require(balanceA[msg.sender] >= amount, "Insufficient Token A balance");
            require(reserveB > 0, "Insufficient liquidity in reserve");
            balanceA[msg.sender] -= amount;
            reserveA += amount;
            streamCount = (amount * scalingFactor) / reserveB;
        } else {
            require(balanceB[msg.sender] >= amount, "Insufficient Token B balance");
            require(reserveA > 0, "Insufficient liquidity in reserve");
            balanceB[msg.sender] -= amount;
            reserveB += amount;
            streamCount = (amount * scalingFactor) / reserveA;
        }


        if (streamCount == 0) {
            streamCount = 1; // Ensure at least one stream
        }

        streams[msg.sender] = Stream({
            totalAmount: amount,
            amountSwapped: 0,
            streamCount: streamCount,
            nextChunkIndex: 0,
            isTokenA: isTokenA
        });

        emit SwapEntered(msg.sender, amount, isTokenA);
    }

    // Process streams
    function processStream(address user) public {
        require(streams[user].totalAmount > 0, "No active stream for user");
        _processStream(user);
    }

    function _processStream(address user) internal {
        Stream storage stream = streams[user];

        require(stream.nextChunkIndex < stream.streamCount, "All chunks processed");

        uint256 chunkAmount = stream.totalAmount / stream.streamCount;

        // Last chunk adjustment
        if (stream.nextChunkIndex == stream.streamCount - 1) {
            chunkAmount = stream.totalAmount - stream.amountSwapped;
        }

        uint256 amountOut;
        if (stream.isTokenA) {
            // Check for sufficient reserveB liquidity
            require(reserveB > 0, "Insufficient liquidity in reserve");

            // Swap Token A for B
            uint256 k = reserveA * reserveB;
            reserveA += chunkAmount;
            uint256 newReserveB = k / reserveA;
            amountOut = reserveB - newReserveB;
            reserveB = newReserveB;
            balanceB[user] += amountOut;
        } else {
            // Check for sufficient reserveA liquidity
            require(reserveA > 0, "Insufficient liquidity in reserve");

            // Swap Token B for A
            uint256 k = reserveA * reserveB;
            reserveB += chunkAmount;
            uint256 newReserveA = k / reserveB;
            amountOut = reserveA - newReserveA;
            reserveA = newReserveA;
            balanceA[user] += amountOut;
        }

        stream.amountSwapped += chunkAmount;
        stream.nextChunkIndex += 1;

        emit StreamProcessed(user, chunkAmount, amountOut, stream.isTokenA);

        // Clean up if stream is complete
        if (stream.nextChunkIndex == stream.streamCount) {
            delete streams[user];
        }
    }

    // Helper functions to simulate token deposits
    function depositTokenA(uint256 amount) external {
        balanceA[msg.sender] += amount;
    }

    function depositTokenB(uint256 amount) external {
        balanceB[msg.sender] += amount;
    }

    // View function to get user's stream details
    function getStream(address user) external view returns (Stream memory) {
        return streams[user];
    }
}
