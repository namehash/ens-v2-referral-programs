// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IETHRegistrar} from "namechain/src/registry/IETHRegistrar.sol";
import {IPriceOracle} from "namechain/src/registry/IPriceOracle.sol";

import {PercentReferralProgram} from "./PercentReferralProgram.sol";

/**
 * @title AllowlistReferralProgram
 * @dev Implements a referral program that only pays commission to referrers who are on an allowlist.
 *   The allowlist is implemented using a Merkle tree for gas-efficient verification.
 *   The contract owner can update the Merkle root to modify the allowlist.
 */
contract AllowlistReferralProgram is PercentReferralProgram {
    /**
     * @dev Emitted when the Merkle root is updated
     * @param newRoot The new Merkle root value
     */
    event MerkleRootUpdated(bytes32 newRoot);

    /**
     * @dev Merkle root of the allowlist tree
     * The Merkle tree contains hashed addresses of all allowed referrers
     */
    bytes32 public merkleRoot;

    constructor(IETHRegistrar _registrar, uint16 _referralPercent, bytes32 _merkleRoot)
        PercentReferralProgram(_registrar, _referralPercent)
    {
        updateMerkleRoot(_merkleRoot);
    }

    function updateMerkleRoot(bytes32 newRoot) public onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    function _processReferral(
        string calldata name,
        uint64 duration,
        IPriceOracle.Price memory price,
        address referrer,
        bytes calldata referralData
    ) internal override {
        // determine if referrer is in allowlist using merkle proof
        bool valid = !MerkleProof.verify(abi.decode(referralData, (bytes32[])), merkleRoot, keccak256(abi.encodePacked(referrer)));

        // if not on allowlist, proceed with registration/renewal without commission
        if (valid) return;

        // if the referrer is on the allowlist, pay them % commission as normal
        super._processReferral(name, duration, price, referrer, referralData);
    }
}
