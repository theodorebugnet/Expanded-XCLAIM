const { expect } = require("chai");
const data = require("./fixtures");

describe("XCC", function() {
    let xcc;

    let addr0, addr1, addr2;

    before("Deploy contracts", async function() {
        //deploy mock exchange oracle
        const ExchangeOracle = await ethers.getContractFactory("ExchangeOracle");
        const oracle = await ExchangeOracle.deploy();
        //deploy mock relay
        const Relay = await ethers.getContractFactory("Relay");
        const mockRelay = await Relay.deploy();

        //create XCC contract (including auxilliary contracts)
        const Validator = await ethers.getContractFactory("Validator");
        const validator = await Validator.deploy();
        const XclaimCommit = await ethers.getContractFactory("XclaimCommit");
        xcc = await XclaimCommit.deploy(mockRelay.address, oracle.address, validator.address);
        await xcc.deployed();

        [addr0, addr1, addr2] = await ethers.getSigners();
    });

    it("Should fail to create a user with no vault", async function() {
        await expect(xcc.registerUser(data.alicePubkey, addr1._address, 4, [])).to.be.revertedWith("No such vault exists");
    });

    it("Should register a vault, emitting an event", async function() {
        await expect(xcc.connect(addr1).registerVault(data.vaultPubkey))
            .to.emit(xcc, 'VaultRegistration')
            .withArgs(addr1._address, data.vaultPubkey);
    });

    it("Should register a user, emitting an event and events for every hash", async function() {
        await expect(xcc.registerUser(data.alicePubkey, addr1._address, 4, [data.hashlocks[0], data.hashlocks[1]]))
            .to.emit(xcc, 'UserRegistration')
            .withArgs(addr0._address, addr1._address, data.alicePubkey)
            .to.emit(xcc, 'UserHashlock')
            .withArgs(addr0._address, 0, data.hashlocks[0])
            .to.emit(xcc, 'UserHashlock')
            .withArgs(addr0._address, 1, data.hashlocks[1]);
        expect(await xcc.getNextHash(addr0._address)).to.equal(data.hashlocks[0]);
        expect(await xcc.getHashAt(addr0._address, 1)).to.equal(data.hashlocks[1]);
        expect(await xcc.getFrequencyOf(addr0._address)).to.equal(4);
    });

    it("Should update the user's hashlist, emitting events", async function() {
        await expect(xcc.updateHashlist([data.hashlocks[2], data.hashlocks[2]], [1, 2]))
            .to.emit(xcc, 'UserHashlock')
            .withArgs(addr0._address, 1, data.hashlocks[2])
            .to.emit(xcc, 'UserHashlock')
            .withArgs(addr0._address, 2, data.hashlocks[2]);
        expect(await xcc.getHashAt(addr0._address, 1)).to.equal(data.hashlocks[2]);
        expect(await xcc.getHashAt(addr0._address, 2)).to.equal(data.hashlocks[2]);
    });

    it("Should add collateral to a vault", async function() {
        await xcc.connect(addr1).topUpCollateralPool({ value: ethers.utils.parseEther('1.0') });
        expect(await xcc.checkCollateralPoolOf(addr1._address)).to.equal(ethers.utils.parseEther('1.0'));
    });

    it("Should update a user's frequency", async function() {
        await expect(xcc.updateFrequency(6))
            .to.emit(xcc, 'UserFrequencyChange')
            .withArgs(addr0._address, 6);
        expect(await xcc.getFrequencyOf(addr0._address)).to.equal(6);
    });

    it("Should issue tokens", async function() {
        await expect(xcc.issueTokens(
            data.issue.tx,
            data.issue.witnessScript,
            data.issue.outputIndex,
            data.issue.blockHeight,
            data.issue.blockIndex, 
            data.issue.blockHeader,
            data.issue.proof))
        .to.emit(xcc, "Issue")
        .withArgs(addr0._address, 2499000000);
        expect(await xcc.balanceOf(addr0._address)).to.be.equal(2499000000);
    });

    it("Should collateralise a user", async function() {
        await expect(xcc.connect(addr1).lockCollateral(addr0._address, ethers.utils.parseEther('1.0')))
            .to.emit(xcc, "UserCollateralised")
            .withArgs(addr0._address, 2499000000 * data.mockExchangeRate);
        expect(await xcc.getCollateralisationOf(addr0._address)).to.equal(2499000000 * data.mockExchangeRate);
    });
     
    it("Should reveal a user's hashlock and validate", async function() {
        await expect(xcc.validateHashlockPreimage(addr0._address, data.preimages[0]))
            .to.emit(xcc, "HashlockReveal")
            .withArgs(addr0._address, 0, data.preimages[0]);
        expect(await xcc.getRevealedPreimageOf(addr0._address)).to.equal(data.preimages[0]);
    });
     
    it("Should transfer funds to a second user", async function() {
        await xcc.connect(addr2).registerUser(data.alicePubkey, addr1._address, 4, []);
        //    function transfer(address recipient, uint amount)
        await expect(xcc.transfer(addr2._address, 1000000000))
            .to.emit(xcc, "Transfer")
            .withArgs(addr0._address, addr2._address, 1000000000);
        expect(await xcc.balanceOf(addr0._address)).to.equal(1499000000 );
        expect(await xcc.balanceOf(addr2._address)).to.equal(1000000000);
    });

    it("TODO: Should validate a checkpoint", async function() {
        // TODO
        // validate: released vault collateral, reset preimage, reset recovery signature, update prev checkpoint id, reset increment checkpoint index
    });
     
    it("TODO: Should burn tokens", async function() {
    });

    it("TODO: Should validate a redeem transaction", async function() {
        // collateralise
        // redeem
        // check collateral is released
    });
});
