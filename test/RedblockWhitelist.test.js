const { toBN, accounts } = require("./helpers/utils");

const { assert } = require("chai");
const truffleAssert = require("truffle-assertions");

const RedblockWhitelist = artifacts.require("RedblockWhitelist");
const NFTMock = artifacts.require("NFTMock");

RedblockWhitelist.numberFormat = "BigNumber";
NFTMock.numberFormat = "BigNumber";

describe("RedblockWhitelist", () => {
  let OWNER;

  let redblockWhitelist;
  let punks;
  let meebits;
  let veeFriends;

  before("setup", async () => {
    OWNER = await accounts(0);
  });

  beforeEach("setup", async () => {
    punks = await NFTMock.new();
    meebits = await NFTMock.new();
    veeFriends = await NFTMock.new();

    redblockWhitelist = await RedblockWhitelist.new(punks.address, meebits.address, veeFriends.address);
  });

  describe("whitelisting", () => {
    it("shouldn't whitelist", async () => {
      await truffleAssert.reverts(redblockWhitelist.whitelist(), "Whitelist: whitelist ended");
    });

    it("shouldn't whitelist", async () => {
      await redblockWhitelist.setWhitelistInfo(toBN(await web3.eth.getBlockNumber()), 100);

      await truffleAssert.reverts(redblockWhitelist.whitelist(), "Whitelist: not eligible for whitelisting");
    });

    it("should whitelist 1", async () => {
      await redblockWhitelist.setWhitelistInfo(toBN(await web3.eth.getBlockNumber()), 100);
      await punks.mint(OWNER, 1);

      await truffleAssert.passes(redblockWhitelist.whitelist(), "Whitelisted");

      assert.isTrue(await redblockWhitelist.isWhitelisted(OWNER));
    });

    it("should whitelist 2", async () => {
      await redblockWhitelist.setWhitelistInfo(toBN(await web3.eth.getBlockNumber()), 100);
      await meebits.mint(OWNER, 1);

      await truffleAssert.passes(redblockWhitelist.whitelist(), "Whitelisted");

      assert.isTrue(await redblockWhitelist.isWhitelisted(OWNER));
    });

    it("should whitelist 3", async () => {
      await redblockWhitelist.setWhitelistInfo(toBN(await web3.eth.getBlockNumber()), 100);
      await veeFriends.mint(OWNER, 1);

      await truffleAssert.passes(redblockWhitelist.whitelist(), "Whitelisted");

      assert.isTrue(await redblockWhitelist.isWhitelisted(OWNER));
    });

    it("shouldn't whitelist", async () => {
      await redblockWhitelist.setWhitelistInfo(toBN(await web3.eth.getBlockNumber()), 1);

      await veeFriends.mint(OWNER, 1);

      await truffleAssert.reverts(redblockWhitelist.whitelist(), "Whitelist: whitelist ended");

      assert.isFalse(await redblockWhitelist.isWhitelisted(OWNER));
    });
  });
});
