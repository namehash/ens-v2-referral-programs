// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {IETHRegistrar} from "namechain/src/registry/IETHRegistrar.sol";
import {IPriceOracle} from "namechain/src/registry/IPriceOracle.sol";

import {PercentReferralProgram} from "./PercentReferralProgram.sol";

/**
 * @title DurationReferralProgram
 * @dev Implements a referral program that pays % commission for registrations/renewals with a
 *   duration over some threshold (ex. >= 1 year).
 */
contract DurationReferralProgram is PercentReferralProgram {
    // minimum duration threshold of 1 year (in seconds)
    uint64 private constant MIN_DURATION = 365 days;

    constructor(IETHRegistrar _registrar, uint16 _commissionPercent)
        PercentReferralProgram(_registrar, _commissionPercent)
    {}

    /**
     * @dev Process referral by calculating and paying out commission if duration >= MIN_DURATION
     */
    function _processReferral(
        string calldata name,
        uint64 duration,
        IPriceOracle.Price memory price,
        address referrer,
        bytes calldata data
    ) internal virtual override {
        // ignore referrals under 1 year
        if (duration < MIN_DURATION) return;

        // otherwise, percent commission as normal
        super._processReferral(name, duration, price, referrer, data);
    }
}
