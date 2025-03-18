// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPriceOracle} from "namechain/src/registry/IPriceOracle.sol";

import "../ReferralProgram.sol";

/**
 * @title LoyaltyReferralProgram
 * @dev In this program, referrers earn increased commission rates based on the cumulative duration
 * their referrals have driven. For every 100 years of cumulative referral time, referrers receive
 * a 1% commission bonus, up to the maximum rate of 20%.
 */
contract LoyaltyReferralProgram is ReferralProgram {
    event ReferralWithCommission(string name, address referrer, uint256 commission);

    // Track cumulative referral duration for each referrer
    mapping(address => uint256) public referralDurations;

    // Constants for loyalty bonus calculation
    uint256 private constant YEARS_PER_BONUS = 100;
    uint256 private constant BONUS_RATE = 1_00; // 1% in bips
    uint256 private constant MAX_COMMISSION_PERCENT = 20_00; // 20% in bips

    constructor(IETHRegistrar _registrar) ReferralProgram(_registrar) {}

    /**
     * @dev Process referral by calculating and paying out commission with loyalty bonus
     */
    function _processReferral(
        string calldata name,
        uint64 duration,
        IPriceOracle.Price memory price,
        address referrer,
        bytes calldata
    ) internal override {
        // no-op if no referrer
        if (referrer == address(0)) return;

        // update referrer's cumulative duration
        // NOTE: placed before balance check so that referrers accrue loyalty despite availability
        //       of commission funds
        referralDurations[referrer] += duration;

        // no-op if no program balance
        uint256 balance = address(this).balance;
        if (balance == 0) return;

        // calculate commission percent (1% every 100 years)
        uint256 commissionPercent = (referralDurations[referrer] * BONUS_RATE) / (YEARS_PER_BONUS * 365 days);

        // ensure maximum commission percent: Math.max(commissionPercent, MAX_COMMISSION_PERCENT)
        commissionPercent = commissionPercent > MAX_COMMISSION_PERCENT ? MAX_COMMISSION_PERCENT : commissionPercent;

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
