// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;
import "forge-std/console.sol";

contract Counter {
    uint256 constant modulusBls = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001;
    uint256 constant ruBls = 0x564c0a11a0f704f4fc3e8acfe0f8245f0ad1347b378fbf96e206da11a5d36306;
    uint256 constant ruBn254 = 0x931d596de2fd10f01ddd073fd5a90a976f169c76f039bb91c4775720042d43a;
    uint256 constant modulusBn254 = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    uint256 constant fieldElementsPerBlob = 0x1000;

    function putBlob(uint256 blobIdx) public payable virtual {
        // forge haven't support mock blobhash cheatcodes 
        bytes32 dataHash = blobhash(blobIdx);
        console.log("dataHash:");
        console.logBytes32(dataHash);
    }

    function reverseBits(uint256 bits, uint256 input) internal pure returns (uint256) {
        assert(input < (1 << bits));
        uint256 n = input;
        uint256 r = 0;
        for (uint256 k = 0; k < bits; k++) {
            r = (r * 2) | (n % 2);
            n = n / 2;
        }
        return r;
    }

    function modExp(uint256 _b, uint256 _e, uint256 _m) internal view returns (uint256 result) {
        assembly {
            // Free memory pointer
            let pointer := mload(0x40)

            // Define length of base, exponent and modulus. 0x20 == 32 bytes
            mstore(pointer, 0x20)
            mstore(add(pointer, 0x20), 0x20)
            mstore(add(pointer, 0x40), 0x20)

            // Define variables base, exponent and modulus
            mstore(add(pointer, 0x60), _b)
            mstore(add(pointer, 0x80), _e)
            mstore(add(pointer, 0xa0), _m)

            // Call the precompiled contract 0x05 = bigModExp, reuse scratch to get the results
            if iszero(staticcall(not(0), 0x05, pointer, 0xc0, 0x0, 0x20)) {
                revert(0, 0)
            }

            result := mload(0x0)

            // Clear memory or exclude the memory
            mstore(0x40, add(pointer, 0xc0))
        }
    }

    function checkInclusive(bytes32 dataHash, uint256 claimIdx, uint256 claimData, bytes memory peInput)
        public
        view
        returns (bool)
    {
        if (dataHash == 0x0) {
            return claimData == 0;
        }
        // peInput includes an input point that comes from bit reversed sampleIdxInKv
        uint256 claimIdxRev = reverseBits(fieldElementsPerBlob, claimIdx);
        uint256 xBls = modExp(ruBls, claimIdxRev, modulusBls);
        (uint256 versionedHash, uint256 evalX, uint256 evalY) = pointEvaluation(peInput);
        if (evalX != xBls || bytes24(bytes32(versionedHash)) != dataHash) {
            return false;
        }

        return evalY == claimData;
    }

    function pointEvaluation(bytes memory input) internal view returns (uint256 versionedHash, uint256 x, uint256 y) {
        assembly {
            versionedHash := mload(add(input, 0x20))
            x := mload(add(input, 0x40))
            y := mload(add(input, 0x60))

            // Call the precompiled contract 0x0a = point evaluation, reuse scratch to get the results
            if iszero(staticcall(not(0), 0x0a, add(input, 0x20), 0xc0, 0x0, 0x40)) { revert(0, 0) }
            // Check the results
            if iszero(eq(mload(0x0), fieldElementsPerBlob)) { revert(0, 0) }
            if iszero(eq(mload(0x20), modulusBls)) { revert(0, 0) }
        }
    }
}
