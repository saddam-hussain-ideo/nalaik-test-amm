const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("SingleSidedAMM", function () {
    let amm;
    let user;

    beforeEach(async function () {
        [user, _] = await ethers.getSigners();

        const AMM = await ethers.getContractFactory("SingleSidedAMM");
        amm = await AMM.deploy(1000000, 1000000);
        await amm.waitForDeployment();

        // Users deposit tokens
        await amm.connect(user).depositTokenA(100000);
        await amm.connect(user).depositTokenB(100000);
    });

    it("Should create a stream and process swap a->b correctly", async function () {
        // user initiates a swap of 10000 Token A
        await amm.connect(user).enterSwap(10000, true);

        let stream = await amm.getStream(user.address);

        // Access properties by index
        let totalAmount = stream[0];
        let amountSwapped = stream[1];
        let streamCount = stream[2];
        let nextChunkIndex = stream[3];

        expect(totalAmount).to.equal(BigInt(10000));
        expect(amountSwapped).to.equal(BigInt(0));
        expect(nextChunkIndex).to.equal(BigInt(0));
        expect(streamCount).to.equal(BigInt(10));

        // Process remaining streams
        do {
            await amm.connect(user).processStream(user.address);
            stream = await amm.getStream(user.address);

            amountSwapped = stream[1];
            nextChunkIndex = stream[3];
            // Check if the stream still exists
            if (stream[0] === BigInt(0)) {
                // Stream has been deleted
                break;
            }
        } while (nextChunkIndex < streamCount) ;

        // Stream should be deleted after completion
        stream = await amm.getStream(user.address);
        totalAmount = stream[0];
        expect(totalAmount).to.equal(BigInt(0));
    });
    it("Should create a stream and process swap b->a correctly", async function () {
        // user initiates a swap of 10000 Token A
        await amm.connect(user).enterSwap(10000, true);

        let stream = await amm.getStream(user.address);

        // Access properties by index
        let totalAmount = stream[0];
        let amountSwapped = stream[1];
        let streamCount = stream[2];
        let nextChunkIndex = stream[3];

        expect(totalAmount).to.equal(BigInt(10000));
        expect(amountSwapped).to.equal(BigInt(0));
        expect(nextChunkIndex).to.equal(BigInt(0));
        expect(streamCount).to.equal(BigInt(10));

        // Process remaining streams
        do {
            await amm.connect(user).processStream(user.address);
            stream = await amm.getStream(user.address);

            amountSwapped = stream[1];
            nextChunkIndex = stream[3];
            // Check if the stream still exists
            if (stream[0] === BigInt(0)) {
                // Stream has been deleted
                break;
            }
        } while (nextChunkIndex < streamCount) ;

        // Stream should be deleted after completion
        stream = await amm.getStream(user.address);
        totalAmount = stream[0];
        expect(totalAmount).to.equal(BigInt(0));
    });

    it("Should revert when processing stream due to insufficient liquidity", async function () {
        // Deploy the contract with reserveA = 1,000,000 and reserveB = 0
        const AMM = await ethers.getContractFactory("SingleSidedAMM");
        const ammInsufficient = await AMM.deploy(1000000, 0);
        await ammInsufficient.waitForDeployment();

        // user deposits 10,000 Token A
        await ammInsufficient.connect(user).depositTokenA(10000);

        // user attempts to enter a swap of 10,000 Token A for Token B
        await expect(
            ammInsufficient.connect(user).enterSwap(10000, true)
        ).to.be.revertedWith("Insufficient liquidity in reserve");
    });

    it("Should handle zero input", async function () {
        await expect(amm.connect(user).enterSwap(0, true)).to.be.revertedWith(
            "Amount must be greater than zero"
        );
    });
});
