const { toBN } = require("./helpers/utils");

const { assert } = require("chai");
const truffleAssert = require("truffle-assertions");

const RedblockSale = artifacts.require("RedblockSaleMock");
RedblockSale.numberFormat = "BigNumber";

describe("RedblockSale", async () => {
  let accounts;
  let redblockSale;

  before("setup", async () => {
    accounts = await web3.eth.getAccounts();
  });

  describe("normal mint", async () => {
    let MAIN;

    beforeEach("setup", async () => {
      MAIN = accounts[0];
      redblockSale = await RedblockSale.new(9921);
    });

    it("should successfully mint 5 tokens", async () => {
      assert.equal(await redblockSale.currentlyMinted(), 0);
      assert.equal(await redblockSale.balanceOf(MAIN), 0);

      let mintPrice = await redblockSale.getMintPrice(5);

      let res = await redblockSale.mint(5, { value: mintPrice.times(1000) });

      assert.equal(await redblockSale.currentlyMinted(), 5);
      assert.equal(await redblockSale.balanceOf(MAIN), 5);

      assert.equal(await web3.eth.getBalance(redblockSale.address), mintPrice);

      assert.equal(res.logs.length, 10);
    });

    it("should not allow mintage of more than 5 NFTs for the same address", async () => {
      let mintPrice = await redblockSale.getMintPrice(5);

      await redblockSale.mint(5, { value: mintPrice });
      await truffleAssert.reverts(redblockSale.mint(1, { value: mintPrice }), "RedblockSale: minter is too greedy");
    });

    it("should revert if value is less than mint amount", async () => {
      let mintPrice = await redblockSale.getMintPrice(5);

      await truffleAssert.reverts(
        redblockSale.mint(5, { value: mintPrice.idiv(2) }),
        "RedblockSale: not enough ether supplied"
      );
    });

    it("should mint NTFs twice", async () => {
      let mintPrice = await redblockSale.getMintPrice(3);

      await redblockSale.mint(3, { value: mintPrice });

      assert.equal(await redblockSale.balanceOf(MAIN), 3);
      assert.equal(await redblockSale.currentlyMinted(), 3);

      await redblockSale.mint(3, { value: mintPrice });

      assert.equal(await redblockSale.balanceOf(MAIN), 5);
      assert.equal(await redblockSale.currentlyMinted(), 5);
    });
  });

  describe("pushy mint", async () => {
    let MAIN;

    beforeEach("setup", async () => {
      MAIN = accounts[0];
      redblockSale = await RedblockSale.new(4);
    });

    it("should not mint more than supply", async () => {
      let mintPrice = await redblockSale.getMintPrice(5);

      await redblockSale.mint(5, { value: mintPrice });

      assert.equal(await redblockSale.balanceOf(MAIN), 4);
      assert.equal(await redblockSale.currentlyMinted(), 4);

      assert.equal(await web3.eth.getBalance(redblockSale.address), mintPrice.minus(web3.utils.toWei("0.05")));
    });
  });

  describe("withdraw", async () => {
    let MAIN;
    let SECOND;

    beforeEach("setup", async () => {
      MAIN = accounts[0];
      SECOND = accounts[1];

      redblockSale = await RedblockSale.new(9921);
    });

    it("should withdraw ETH", async () => {
      let mintPrice = await redblockSale.getMintPrice(5);

      await redblockSale.mint(5, { from: SECOND, value: mintPrice });

      let balance = await web3.eth.getBalance(MAIN);

      await redblockSale.withdraw();

      assert.isTrue(toBN(await web3.eth.getBalance(MAIN)).gt(balance));
    });
  });
});
