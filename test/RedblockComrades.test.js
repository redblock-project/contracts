const { toBN, accounts } = require("./helpers/utils");
const { mine } = require("./helpers/hardhatTimeTraveller.js");

const { assert } = require("chai");
const truffleAssert = require("truffle-assertions");

const RedblockWhitelist = artifacts.require("RedblockWhitelist");
const NFTMock = artifacts.require("NFTMock");
const ERC20Mock = artifacts.require("ERC20Mock");
const RedblockComrades = artifacts.require("RedblockComradesMock");

RedblockWhitelist.numberFormat = "BigNumber";
NFTMock.numberFormat = "BigNumber";
ERC20Mock.numberFormat = "BigNumber";
RedblockComrades.numberFormat = "BigNumber";

describe("RedblockComrades", async () => {
  let OWNER;
  let SECOND;

  let redblockComrades;

  let nct;
  let dust;
  let whale;

  let artblocks;
  let nftBoxes;

  let punks;

  before("setup", async () => {
    OWNER = await accounts(0);
    SECOND = await accounts(1);
  });

  beforeEach("setup", async () => {
    punks = await NFTMock.new();
    nftBoxes = await NFTMock.new();
    artblocks = await NFTMock.new();

    nct = await ERC20Mock.new("NCT", "NCT", 18);
    dust = await ERC20Mock.new("DUST", "DUST", 18);
    whale = await ERC20Mock.new("WHALE", "WHALE", 4);

    redblockWhitelist = await RedblockWhitelist.new(punks.address, punks.address, punks.address);
  });

  describe("mint ETH", async () => {
    beforeEach("setup", async () => {
      redblockComrades = await RedblockComrades.new(
        redblockWhitelist.address,
        nct.address,
        dust.address,
        whale.address,
        nftBoxes.address,
        artblocks.address,
        9921
      );

      await redblockWhitelist.setWhitelistInfo(toBN(await web3.eth.getBlockNumber()), 100);
      await punks.mint(OWNER, 1);
      await redblockWhitelist.whitelist();

      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()).plus(100));
      await redblockComrades.triggerSale(true);
    });

    it("should successfully mint 5 tokens", async () => {
      assert.equal(await redblockComrades.currentlyMinted(), 0);
      assert.equal(await redblockComrades.balanceOf(OWNER), 0);

      let mintPrice = await redblockComrades.getMintPriceETH(5);

      let res = await redblockComrades.mintForETH(5, { value: mintPrice.times(1000) });

      assert.equal(await redblockComrades.currentlyMinted(), 5);
      assert.equal(await redblockComrades.balanceOf(OWNER), 5);

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

      assert.equal(await redblockComrades.balanceOf(OWNER), 3);
      assert.equal(await redblockComrades.currentlyMinted(), 3);

      await redblockComrades.mintForETH(3, { value: mintPrice });

      assert.equal(await redblockComrades.balanceOf(OWNER), 5);
      assert.equal(await redblockComrades.currentlyMinted(), 5);
    });
  });

  describe("pushy mint ETH", async () => {
    beforeEach("setup", async () => {
      redblockComrades = await RedblockComrades.new(
        redblockWhitelist.address,
        nct.address,
        dust.address,
        whale.address,
        nftBoxes.address,
        artblocks.address,
        4
      );

      await redblockWhitelist.setWhitelistInfo(toBN(await web3.eth.getBlockNumber()), 100);

      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()).plus(100));
      await redblockComrades.triggerSale(true);

      await mine(100);
    });

    it("should not mint more than supply", async () => {
      let mintPrice = await redblockComrades.getMintPriceETH(5);

      await redblockComrades.mintForETH(5, { value: mintPrice });

      assert.equal(await redblockComrades.balanceOf(OWNER), 4);
      assert.equal(await redblockComrades.currentlyMinted(), 4);

      assert.equal(await web3.eth.getBalance(redblockComrades.address), mintPrice.minus(web3.utils.toWei("0.05")));
    });
  });

  describe("withdraw", async () => {
    beforeEach("setup", async () => {
      redblockComrades = await RedblockComrades.new(
        redblockWhitelist.address,
        nct.address,
        dust.address,
        whale.address,
        nftBoxes.address,
        artblocks.address,
        9921
      );

      await redblockWhitelist.setWhitelistInfo(toBN(await web3.eth.getBlockNumber()), 100);

      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()).plus(100));
      await redblockComrades.triggerSale(true);

      await mine(100);
    });

    it("should withdraw ETH", async () => {
      let mintPrice = await redblockComrades.getMintPriceETH(5);

      await redblockComrades.mintForETH(5, { from: SECOND, value: mintPrice });

      let balance = await web3.eth.getBalance(OWNER);

      await redblockComrades.withdrawETH();

      assert.isTrue(toBN(await web3.eth.getBalance(OWNER)).gt(balance));
    });
  });
});
