// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {IETHRegistrar} from "namechain/src/registry/IETHRegistrar.sol";
import {IPriceOracle} from "namechain/src/registry/IPriceOracle.sol";

import {ReferralProgram} from "../ReferralProgram.sol";

/**
 * @title PercentReferralProgram
 * @dev Implements a simple referral system with a % commission for referrers.
 */
contract PercentReferralProgram is ReferralProgram {
    event ReferralWithCommission(string name, address referrer, uint256 commission);

    // Commission percentage in basis points (1/100 of a percent)
    // 100 bips = 1%, 10000 bips = 100%, etc
    uint16 public immutable commissionPercent;

    constructor(IETHRegistrar _registrar, uint16 _commissionPercent) ReferralProgram(_registrar) {
        commissionPercent = _commissionPercent;

        // NOTE: could implement sanity check for commissionPercent value
        // if (_commissionPercent > MAX_COMMISSION_PERCENT) {
        //     revert CommissionExceedsLimit(_commissionPercent, MAX_COMMISSION_PERCENT);
        // }
    }

    /**
     * @dev Process referral by calculating and paying out commission
     */
    function _processReferral(
        string calldata name,
        uint64,
        IPriceOracle.Price memory price,
        address referrer,
        bytes calldata
    ) internal virtual override {
        // no-op if no referrer
        if (referrer == address(0)) return;

        // no-op if no program balance
        uint256 balance = address(this).balance;
        if (balance == 0) return;

        // calculate commission amount (bips)
        uint256 totalPrice = price.base + price.premium;
        uint256 commission = (totalPrice * commissionPercent) / 10_000;

        // ensure we can't spend more than program balance: Math.min(commission, balance)
        // NOTE: also ensures that entire balance can be used, with no dust wei left behind
        commission = commission > balance ? balance : commission;

        // pay referrer their commission
        payable(referrer).transfer(commission);

        // emit referral event w/ commission info
        emit ReferralWithCommission(name, referrer, commission);
    }
}
