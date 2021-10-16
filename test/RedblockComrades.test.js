const { toBN } = require("./helpers/utils");

const { assert } = require("chai");
const truffleAssert = require("truffle-assertions");

const RedblockComrades = artifacts.require("RedblockComradesMock");
RedblockComrades.numberFormat = "BigNumber";

describe("RedblockComrades", async () => {
  let accounts;
  let redblockComrades;

  before("setup", async () => {
    accounts = await web3.eth.getAccounts();
  });

  describe("mint ETH", async () => {
    let MAIN;

    beforeEach("setup", async () => {
      MAIN = accounts[0];
      redblockComrades = await RedblockComrades.new(9921);
      await redblockComrades.triggerSale(true);
    });

    it("should successfully mint 5 tokens", async () => {
      assert.equal(await redblockComrades.currentlyMinted(), 0);
      assert.equal(await redblockComrades.balanceOf(MAIN), 0);

      let mintPrice = await redblockComrades.getMintPriceETH(5);

      let res = await redblockComrades.mintForETH(5, { value: mintPrice.times(1000) });

      assert.equal(await redblockComrades.currentlyMinted(), 5);
      assert.equal(await redblockComrades.balanceOf(MAIN), 5);

      assert.equal(await web3.eth.getBalance(redblockComrades.address), mintPrice);

      assert.equal(res.logs.length, 10);
    });

    it("should not allow mintage of more than 5 NFTs for the same address", async () => {
      let mintPrice = await redblockComrades.getMintPriceETH(5);

      await redblockComrades.mintForETH(5, { value: mintPrice });
      await truffleAssert.reverts(
        redblockComrades.mintForETH(1, { value: mintPrice }),
        "RedblockComrades: can't mint that amount"
      );
    });

    it("should revert if value is less than mint amount", async () => {
      let mintPrice = await redblockComrades.getMintPriceETH(5);

      await truffleAssert.reverts(
        redblockComrades.mintForETH(5, { value: mintPrice.idiv(2) }),
        "RedblockComrades: not enough ether supplied"
      );
    });

    it("should mint NTFs twice", async () => {
      let mintPrice = await redblockComrades.getMintPriceETH(3);

      await redblockComrades.mintForETH(3, { value: mintPrice });

      assert.equal(await redblockComrades.balanceOf(MAIN), 3);
      assert.equal(await redblockComrades.currentlyMinted(), 3);

      await redblockComrades.mintForETH(3, { value: mintPrice });

      assert.equal(await redblockComrades.balanceOf(MAIN), 5);
      assert.equal(await redblockComrades.currentlyMinted(), 5);
    });
  });

  describe("pushy mint ETH", async () => {
    let MAIN;

    beforeEach("setup", async () => {
      MAIN = accounts[0];
      redblockComrades = await RedblockComrades.new(4);
      await redblockComrades.triggerSale(true);
    });

    it("should not mint more than supply", async () => {
      let mintPrice = await redblockComrades.getMintPriceETH(5);

      await redblockComrades.mintForETH(5, { value: mintPrice });

      assert.equal(await redblockComrades.balanceOf(MAIN), 4);
      assert.equal(await redblockComrades.currentlyMinted(), 4);

      assert.equal(await web3.eth.getBalance(redblockComrades.address), mintPrice.minus(web3.utils.toWei("0.05")));
    });
  });

  describe("withdraw", async () => {
    let MAIN;
    let SECOND;

    beforeEach("setup", async () => {
      MAIN = accounts[0];
      SECOND = accounts[1];

      redblockComrades = await RedblockComrades.new(9921);
      await redblockComrades.triggerSale(true);
    });

    it("should withdraw ETH", async () => {
      let mintPrice = await redblockComrades.getMintPriceETH(5);

      await redblockComrades.mintForETH(5, { from: SECOND, value: mintPrice });

      let balance = await web3.eth.getBalance(MAIN);

      await redblockComrades.withdrawETH();

      assert.isTrue(toBN(await web3.eth.getBalance(MAIN)).gt(balance));
    });
  });
});
