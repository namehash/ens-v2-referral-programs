// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {IRegistry} from "namechain/src/registry/IRegistry.sol";

/**
 * @dev Interface for an ENSv2 Referral Program that supports both registration & renewals.
 */
interface IReferralCycle {
    /**
     * @dev Emitted when a registration/renewal is referred. Implementations MAY choose to emit
     *   further events specifying information like calculated comission.
     * @param name The name that was registered/renewed.
     * @param referrer The address of the referrer.
     */
    event Referral(string name, address referrer);

    /**
     * @dev Register a name with referral information. Mirror's IETHRegistry#register, plus
     *  `referrer` and `referralData` params.
     * @param name The name to register.
     * @param owner The owner of the name.
     * @param secret The secret of the name.
     * @param subregistry The subregistry to register the name in.
     * @param resolver The resolver to use for the registration.
     * @param flags The flags to set on the name.
     * @param duration The duration of the registration.
     * @param referrer The address of the referrer.
     * @param referralData Additional data for the referral.
     * @return tokenId The token ID of the registered name.
     */
    function register(
        string calldata name,
        address owner,
        bytes32 secret,
        IRegistry subregistry,
        address resolver,
        uint96 flags,
        uint64 duration,
        address referrer,
        bytes calldata referralData
    ) external payable returns (uint256 tokenId);

    /**
     * @dev Renew a name with referral information.
     * @param name The name to renew.
     * @param duration The duration of the renewal.
     * @param referrer The address of the referrer.
     * @param referralData Additional data for the referral.
     */
    function renew(string calldata name, uint64 duration, address referrer, bytes calldata referralData)
        external
        payable;
}
