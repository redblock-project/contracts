const { MerkleTree } = require("merkletreejs");
const { toBN, accounts } = require("./helpers/utils");
const { mine } = require("./helpers/hardhatTimeTraveller.js");

const { assert } = require("chai");
const truffleAssert = require("truffle-assertions");

const NFTMock = artifacts.require("NFTMock");
const ERC20Mock = artifacts.require("ERC20Mock");
const RedblockComrades = artifacts.require("RedblockComradesMock");

NFTMock.numberFormat = "BigNumber";
ERC20Mock.numberFormat = "BigNumber";
RedblockComrades.numberFormat = "BigNumber";

function constructWhitelist(whitelistedAddresses, whitelistedAmounts) {
  const whitelist = {};

  for (let i = 0; i < whitelistedAddresses.length; i++) {
    whitelist[whitelistedAddresses[i]] = whitelistedAmounts[i];
  }

  return whitelist;
}

function constructLeavesAndTree(whitelist) {
  const leaves = {};

  Object.keys(whitelist).forEach((el) => {
    leaves[el] = web3.utils.soliditySha3(el, whitelist[el]);
  });

  const tree = new MerkleTree(
    Object.values(leaves),
    (el) => Buffer.from(web3.utils.soliditySha3(el).replace("0x", ""), "hex"),
    {
      sortPairs: true,
    }
  );

  return [leaves, tree];
}

function getLeafAndProof(leaves, tree, user) {
  if (user in leaves) {
    const leaf = leaves[user];
    const proof = tree.getProof(leaf).map((el) => "0x" + el.data.toString("hex"));

    return [leaf, proof];
  }

  return ["", []];
}

describe("RedblockComrades", () => {
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
  });

  describe("mint ETH", () => {
    beforeEach("setup", async () => {
      redblockComrades = await RedblockComrades.new(
        [punks.address, punks.address, punks.address],
        [nct.address, dust.address, whale.address],
        [nftBoxes.address, artblocks.address],
        9917
      );

      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()));
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

    it("should successfully mint 3 tokens", async () => {
      await punks.mint(OWNER, 1);

      let mintPrice = await redblockComrades.getMintPriceETH(3);

      await redblockComrades.mintForETH(3, { value: mintPrice });

      assert.equal(await redblockComrades.currentlyMinted(), 3);
      assert.equal(await redblockComrades.balanceOf(OWNER), 3);

      assert.equal(await web3.eth.getBalance(redblockComrades.address), mintPrice);
    });

    it("should successfully mint 4 tokens", async () => {
      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()).plus(100));

      const whitelistedAddresses = [OWNER, SECOND, await accounts(2), await accounts(3)];
      const whitelistedAmounts = [4, 3, 5, 4];

      const whitelist = constructWhitelist(whitelistedAddresses, whitelistedAmounts);
      const [leaves, tree] = constructLeavesAndTree(whitelist);
      const [leaf, proof] = getLeafAndProof(leaves, tree, SECOND);

      const root = "0x" + tree.getRoot().toString("hex");
      await redblockComrades.setWhitelistRoot(root);

      let mintPrice = await redblockComrades.getMintPriceETH(3);

      await redblockComrades.mintForETHWhitelist(2, whitelist[SECOND], leaf, proof, { value: mintPrice, from: SECOND });

      mintPrice = await redblockComrades.getMintPriceETH(1);

      await redblockComrades.mintForETHWhitelist(1, whitelist[SECOND], leaf, proof, { value: mintPrice, from: SECOND });
    });
  });

  describe("pushy mint ETH", () => {
    beforeEach("setup", async () => {
      redblockComrades = await RedblockComrades.new(
        [punks.address, punks.address, punks.address],
        [nct.address, dust.address, whale.address],
        [nftBoxes.address, artblocks.address],
        4
      );

      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()));
      await redblockComrades.triggerSale(true);

      await mine(100);
    });

    it("should not mint more than supply", async () => {
      let mintPrice = await redblockComrades.getMintPriceETH(5);

      await redblockComrades.mintForETH(5, { value: mintPrice });

      assert.equal(await redblockComrades.balanceOf(OWNER), 4);
      assert.equal(await redblockComrades.currentlyMinted(), 4);

      assert.equal(await web3.eth.getBalance(redblockComrades.address), mintPrice.minus(web3.utils.toWei("0.0711")));
    });
  });

  describe("mint ERC20", () => {
    beforeEach("setup", async () => {
      redblockComrades = await RedblockComrades.new(
        [punks.address, punks.address, punks.address],
        [nct.address, dust.address, whale.address],
        [nftBoxes.address, artblocks.address],
        9917
      );

      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()));
      await redblockComrades.triggerSale(true);
    });

    it("should mint via ERC20", async () => {
      await nct.mint(SECOND, web3.utils.toWei("1000000"));

      let mintPrice = await redblockComrades.getMintPriceNCT(4);

      await nct.approve(redblockComrades.address, mintPrice, { from: SECOND });
      await redblockComrades.mintForNCT(4, { from: SECOND });

      assert.equal(await redblockComrades.balanceOf(SECOND), 4);
      assert.equal(await redblockComrades.currentlyMinted(), 4);

      assert.equal((await nct.balanceOf(OWNER)).toFixed(), mintPrice.toFixed());
    });

    it("should mint via ERC20 whitelisted", async () => {
      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()).plus(100));

      let FOURTH = await accounts(3);

      const whitelistedAddresses = [OWNER, SECOND, await accounts(2), FOURTH];
      const whitelistedAmounts = [3, 5, 1, 2];

      const whitelist = constructWhitelist(whitelistedAddresses, whitelistedAmounts);
      const [leaves, tree] = constructLeavesAndTree(whitelist);
      const [leaf, proof] = getLeafAndProof(leaves, tree, FOURTH);

      const root = "0x" + tree.getRoot().toString("hex");
      await redblockComrades.setWhitelistRoot(root);

      await dust.mint(FOURTH, web3.utils.toWei("1000000"));

      let mintPrice = await redblockComrades.getMintPriceDUST(2);

      await dust.approve(redblockComrades.address, mintPrice, { from: FOURTH });
      await redblockComrades.mintForDUSTWhitelist(2, whitelist[FOURTH], leaf, proof, {
        from: FOURTH,
      });

      assert.equal(await redblockComrades.balanceOf(FOURTH), 2);
      assert.equal(await redblockComrades.currentlyMinted(), 2);

      assert.equal((await dust.balanceOf(OWNER)).toFixed(), mintPrice.toFixed());
    });

    it("should not mint for not whitelisted address", async () => {
      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()).plus(100));

      let FOURTH = await accounts(3);

      const whitelistedAddresses = [OWNER, SECOND, await accounts(2)];
      const whitelistedAmounts = [3, 5, 1];

      const whitelist = constructWhitelist(whitelistedAddresses, whitelistedAmounts);
      const [leaves, tree] = constructLeavesAndTree(whitelist);
      const [_, proof] = getLeafAndProof(leaves, tree, OWNER);

      const fakeLeaf = web3.utils.soliditySha3(FOURTH, 5);

      const root = "0x" + tree.getRoot().toString("hex");
      await redblockComrades.setWhitelistRoot(root);

      await dust.mint(FOURTH, web3.utils.toWei("1000000"));

      let mintPrice = await redblockComrades.getMintPriceDUST(2);

      await dust.approve(redblockComrades.address, mintPrice, { from: FOURTH });

      await truffleAssert.reverts(
        redblockComrades.mintForDUSTWhitelist(2, 5, fakeLeaf, proof, {
          from: FOURTH,
        }),
        "RedblockComrades: not whitelisted"
      );
    });
  });

  describe("mint via ERC721", () => {
    beforeEach("setup", async () => {
      redblockComrades = await RedblockComrades.new(
        [punks.address, punks.address, punks.address],
        [nct.address, dust.address, whale.address],
        [nftBoxes.address, artblocks.address],
        9917
      );

      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()));
      await redblockComrades.triggerSale(true);
    });

    it("should mint via ERC721", async () => {
      await artblocks.mint(SECOND, 2);

      await artblocks.setApprovalForAll(redblockComrades.address, true, { from: SECOND });
      await redblockComrades.mintForArtblocks([1, 2], { from: SECOND });

      assert.equal((await redblockComrades.balanceOf(SECOND)).toFixed(), 5);
      assert.equal((await redblockComrades.currentlyMinted()).toFixed(), 5);

      assert.equal((await artblocks.balanceOf(OWNER)).toFixed(), "2");
    });

    it("should mint via ERC721", async () => {
      await nftBoxes.mint(SECOND, 3);

      await nftBoxes.setApprovalForAll(redblockComrades.address, true, { from: SECOND });
      await redblockComrades.mintForNFTBoxes([1, 2, 3], { from: SECOND });

      assert.equal((await redblockComrades.balanceOf(SECOND)).toFixed(), 3);
      assert.equal((await redblockComrades.currentlyMinted()).toFixed(), 3);

      assert.equal((await nftBoxes.balanceOf(OWNER)).toFixed(), "3");
    });

    it("should mint via ERC721 whitelisted", async () => {
      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()).plus(100));

      let FOURTH = await accounts(3);

      const whitelistedAddresses = [OWNER, SECOND, await accounts(2), FOURTH];
      const whitelistedAmounts = [4, 1, 2, 2];

      const whitelist = constructWhitelist(whitelistedAddresses, whitelistedAmounts);
      const [leaves, tree] = constructLeavesAndTree(whitelist);
      const [leaf, proof] = getLeafAndProof(leaves, tree, FOURTH);

      const root = "0x" + tree.getRoot().toString("hex");
      await redblockComrades.setWhitelistRoot(root);

      await artblocks.mint(FOURTH, 1);

      await artblocks.setApprovalForAll(redblockComrades.address, true, { from: FOURTH });

      await redblockComrades.mintForArtblocksWhitelist([1], whitelist[FOURTH], leaf, proof, { from: FOURTH });

      assert.equal(await redblockComrades.balanceOf(FOURTH), 2);
      assert.equal(await redblockComrades.currentlyMinted(), 2);

      assert.equal((await artblocks.balanceOf(OWNER)).toFixed(), "1");
    });

    it("should mint via ERC721 whitelisted 2", async () => {
      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()).plus(100));

      let FOURTH = await accounts(3);

      const whitelistedAddresses = [OWNER, SECOND, await accounts(2), FOURTH];
      const whitelistedAmounts = [4, 1, 2, 3];

      const whitelist = constructWhitelist(whitelistedAddresses, whitelistedAmounts);
      const [leaves, tree] = constructLeavesAndTree(whitelist);
      const [leaf, proof] = getLeafAndProof(leaves, tree, FOURTH);

      const root = "0x" + tree.getRoot().toString("hex");
      await redblockComrades.setWhitelistRoot(root);

      await nftBoxes.mint(FOURTH, 1);
      await artblocks.mint(FOURTH, 1);

      await nftBoxes.setApprovalForAll(redblockComrades.address, true, { from: FOURTH });
      await artblocks.setApprovalForAll(redblockComrades.address, true, { from: FOURTH });

      await redblockComrades.mintForNFTBoxesWhitelist([1], whitelist[FOURTH], leaf, proof, { from: FOURTH });
      await redblockComrades.mintForArtblocksWhitelist([1], whitelist[FOURTH], leaf, proof, { from: FOURTH });

      assert.equal((await redblockComrades.balanceOf(FOURTH)).toFixed(), 3);
      assert.equal((await redblockComrades.currentlyMinted()).toFixed(), 3);

      assert.equal((await nftBoxes.balanceOf(OWNER)).toFixed(), "1");
      assert.equal((await artblocks.balanceOf(OWNER)).toFixed(), "1");
    });
  });

  describe("withdraw", () => {
    beforeEach("setup", async () => {
      redblockComrades = await RedblockComrades.new(
        [punks.address, punks.address, punks.address],
        [nct.address, dust.address, whale.address],
        [nftBoxes.address, artblocks.address],
        9917
      );

      await redblockComrades.setWhitelistEndBlock(toBN(await web3.eth.getBlockNumber()));
      await redblockComrades.triggerSale(true);

      await mine(100);
    });

    it("should mint owner NFTs", async () => {
      await redblockComrades.mintOwner();
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
