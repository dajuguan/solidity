const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { Buffer } = require('node:buffer');

const { blobToKzgCommitment, computeKzgProof, loadTrustedSetup, verifyKzgProof} = require('c-kzg');
const path = require('path');
const { ethers } = require("hardhat");
// const { ethers } = require("hardhat");

function toHex(buffer) {
  return Array.prototype.map.call(buffer, x => ('00' + x.toString(16)).slice(-2)).join('');
}

function toBytes1Array(arr) {
  let res = [];
  arr.map(x => res.push(ethers.toBeHex(x, 1)));
  return res;
}

function kzgToVersionedHash(commitment) {
  const VERSIONED_HASH_VERSION_KZG = "01"
  return ethers.getBytes("0x" + VERSIONED_HASH_VERSION_KZG + ethers.sha256(commitment).slice(4));
}

describe("Lock", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployContract() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const Lock = await ethers.getContractFactory("Lock");
    const lock = await Lock.deploy();

    return { lock, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { lock } = await loadFixture(deployContract);
      await lock.putBlob(0);
    });

    it("e2e", async function () {
      const { lock } = await loadFixture(deployContract);
      const FIELD_ELEMENTS_PER_BLOB = 4096;
      const CLAIM_IDX = 1
      let elements = new Array(FIELD_ELEMENTS_PER_BLOB);
      for (let i = 0; i < FIELD_ELEMENTS_PER_BLOB; i++) {
        elements[i] = ethers.toBeHex(i, 32)
      }

      let blob = ethers.concat(elements);
      console.log("blob hex:", blob.slice(0, 256));
      let blobArray = ethers.getBytes(blob);
      expect(blobArray.length).to.equal(FIELD_ELEMENTS_PER_BLOB * 32);

      loadTrustedSetup(path.resolve("../python/trusted_setup.txt"));
      const commitment = blobToKzgCommitment(blobArray);
      console.log("commitment hex:", toHex(commitment));
      const versioned_hash = kzgToVersionedHash(commitment);
      console.log("versioned hash:", ethers.hexlify(versioned_hash));
      const z_int = await lock.evaluationPointAtIdx(CLAIM_IDX);
      console.log("z_int:", z_int);
      console.log("z bytes32:", ethers.toBeHex(z_int, 32));
      const z = ethers.toBeArray(z_int);
      const [_proof, y] = computeKzgProof(blobArray, z);
      console.log("proof is:", toHex(_proof));
      console.log("evaluation is:", y);

      let proof = _proof;
      expect(verifyKzgProof(commitment, z, y, proof)).to.equal(true);

      /** The data is encoded as follows:
            versioned_hash = input[:32]
            z = input[32:64]
            y = input[64:96]
            commitment = input[96:144]
            proof = input[144:192]
      */
      let peInput_hex = ethers.concat([versioned_hash, z, y, commitment, proof]);
      let peInput = ethers.getBytes(peInput_hex);
      expect(peInput.length).to.equal(192);
      console.log("peInput len:", peInput.length);

      proof[0] = 9;  // fake proof
      // await lock.checkInclusive(CLAIM_IDX, CLAIM_IDX, ethers.encodeBytes32String(versioned_hash),ethers.getBytes(commitment), ethers.getBytes(proof));
      await lock.checkInclusive(CLAIM_IDX, CLAIM_IDX, versioned_hash, commitment, proof);

    });
  });
});
