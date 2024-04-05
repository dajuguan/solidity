// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "hardhat/console.sol";

contract Lock {
    uint256 constant modulusBls = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001;
    uint256 constant ruBls = 0x564c0a11a0f704f4fc3e8acfe0f8245f0ad1347b378fbf96e206da11a5d36306;
    uint256 constant ruBn254 = 0x931d596de2fd10f01ddd073fd5a90a976f169c76f039bb91c4775720042d43a;
    uint256 constant modulusBn254 = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;
    uint256 constant fieldElementsPerBlob = 0x1000;

    error EVAL_FAILED_1();
    error EVAL_FAILED_2();
    error POINT_X_TOO_LARGE();
    error POINT_Y_TOO_LARGE();

    function putBlob(uint256 blobIdx) public payable virtual {
        // forge haven't support mock blobhash cheatcode, hardhat doesn't support blobhash
        bytes32 dataHash = blockhash(blobIdx);
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
            if iszero(staticcall(not(0), 0x05, pointer, 0xc0, 0x0, 0x20)) { revert(0, 0) }

            result := mload(0x0)

            // Clear memory or exclude the memory
            mstore(0x40, add(pointer, 0xc0))
        }
    }

    function evaluationPointAtIdx(uint256 claimIdx) public view returns (uint256) {
        uint256 claimIdxRev = reverseBits(12, claimIdx); // 2^12 = 4096
        uint256 xBls = modExp(ruBls, claimIdxRev, modulusBls);
        return xBls;
    }

    function checkInclusive(
        uint256 claimIdx,
        uint256 claimData,
        bytes32 _blobHash,
        bytes memory _commitment,
        bytes memory _pointProof
    ) public view {
        // peInput includes an input point that comes from bit reversed sampleIdxInKv
        uint256 claimIdxRev = reverseBits(12, claimIdx);
        uint256 _x = modExp(ruBls, claimIdxRev, modulusBls);
        console.log("===========================", _x);
        // pointEvaluation(_blobHash, _x, claimData, _commitment, _pointProof);
        bytes memory pointEvaluationCalldata = abi.encodePacked(
            _blobHash,
            _x,
            claimData,
            _commitment,
            _pointProof
        );
        (uint256 versionedHash, uint256 x, uint256 y) = pointEvaluationAsm(pointEvaluationCalldata);
        console.log("versionedHash", versionedHash, x, y);
    }

    /// @notice Evaluates the 4844 point using the precompile.
    /// @param _blobHash The versioned hash
    /// @param _x The evaluation point
    /// @param _y The expected output
    /// @param _commitment The input kzg point
    /// @param _pointProof The quotient kzg
    function pointEvaluation(
        bytes32 _blobHash,
        uint256 _x,
        uint256 _y,
        bytes memory _commitment,
        bytes memory _pointProof
    ) internal view {
        require(_commitment.length == 48, "Commitment must be 48 bytes");
        require(_pointProof.length == 48, "Proof must be 48 bytes");
        _x = 0;
        _y = 100;
        bytes memory pointEvaluationCalldata = abi.encodePacked(
            _blobHash,
            _x,
            _y,
            _commitment,
            _pointProof
        );
        (bool ok, bytes memory ret) = 0x000000000000000000000000000000000000000A.staticcall(pointEvaluationCalldata);
        console.log("_blobHash", ok, _x, _y);
        console.logBytes32(_blobHash);
        
        if (!ok) revert EVAL_FAILED_1();
        console.log("res len:", ret.length);
        if (ret.length != 64) revert EVAL_FAILED_2();

        bytes32 first;
        bytes32 second;
        assembly {
            first := mload(add(ret, 32))
            second := mload(add(ret, 64))
        }
        if (uint256(first) != fieldElementsPerBlob || uint256(second) != modulusBls) {
            revert EVAL_FAILED_2();
        }
    }

    function pointEvaluationAsm(bytes memory input) internal view returns (uint256 versionedHash, uint256 x, uint256 y) {
        assembly {
            versionedHash := mload(add(input, 0x20))
            x := mload(add(input, 0x40))
            y := mload(add(input, 0x60))

            // Call the precompiled contract 0x0a = point evaluation, reuse scratch to get the results
            if iszero(staticcall(not(0), 0x0a, add(input, 0x20), 0xc0, 0x0, 0x40)) { revert(0, 0) }
            // Check the results
            // if iszero(eq(mload(0x0), fieldElementsPerBlob)) { revert(0, 0) }
            // if iszero(eq(mload(0x20), modulusBls)) { revert(0, 0) }
        }
    }
}
