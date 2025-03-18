// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {IETHRegistrar} from "namechain/src/registry/IETHRegistrar.sol";
import {IPriceOracle} from "namechain/src/registry/IPriceOracle.sol";

import {BaseReferralCycle} from "../BaseReferralCycle.sol";

/**
 * @title PercentReferralCycle
 * @dev Implements a simple referral system with a % commission for referrers.
 */
contract PercentReferralCycle is BaseReferralCycle {
    event ReferralWithCommission(string name, address referrer, uint256 commission);

    // Commission percentage in basis points (1/100 of a percent)
    // 100 bips = 1%, 10000 bips = 100%, etc
    uint16 public immutable commissionPercent;

    constructor(IETHRegistrar _registrar, uint16 _commissionPercent) BaseReferralCycle(_registrar) {
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

        // no-op if no commission treasury
        uint256 balance = address(this).balance;
        if (balance == 0) return;

        // calculate commission amount (bips)
        uint256 totalPrice = price.base + price.premium;
        uint256 commission = (totalPrice * commissionPercent) / 10_000;

        // Math.min(commission, balance)
        commission = commission > balance ? balance : commission;

        // pay referrer
        payable(referrer).transfer(commission);

        // emit referral event
        emit ReferralWithCommission(name, referrer, commission);
    }
}
