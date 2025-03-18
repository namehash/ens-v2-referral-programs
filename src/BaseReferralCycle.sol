// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IETHRegistrar} from "namechain/src/registry/IETHRegistrar.sol";
import {IRegistry} from "namechain/src/registry/IRegistry.sol";
import {IPriceOracle} from "namechain/src/registry/IPriceOracle.sol";

import {IReferralCycle} from "./IReferralCycle.sol";

/**
 * @title BaseReferralCycle
 * @dev Base implementation for referral program. Inheriting contracts must implement _processReferral.
 */
abstract contract BaseReferralCycle is IReferralCycle, Ownable {
    IETHRegistrar public immutable registrar;

    constructor(IETHRegistrar _registrar) Ownable(msg.sender) {
        registrar = _registrar;
    }

    /**
     * @dev Register a name with referral information, forwarding registration to registrar.
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
    ) external payable override returns (uint256 tokenId) {
        // calculate totalPrice
        IPriceOracle.Price memory price = registrar.rentPrice(name, duration);
        uint256 totalPrice = price.base + price.premium;

        // forward registration, including the exact value of the registration to avoid refunds
        // NOTE: if registrar.register reverts, so will the whole transaction
        tokenId = registrar.register{value: totalPrice}(name, owner, secret, subregistry, resolver, flags, duration);

        // refund sender any leftover change
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        // process referral
        _processReferral(name, duration, price, referrer, referralData);

        return tokenId;
    }

    /**
     * @dev Renew a name with referral information, forwarding renewal to registrar.
     */
    function renew(string calldata name, uint64 duration, address referrer, bytes calldata referralData)
        external
        payable
        override
    {
        // calculate totalPrice
        IPriceOracle.Price memory price = registrar.rentPrice(name, duration);
        uint256 totalPrice = price.base + price.premium;

        // forward renewal, including the exact value of the renewal to avoid refunds
        registrar.renew{value: totalPrice}(name, duration);

        // refund sender any leftover change
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        // process referral
        _processReferral(name, duration, price, referrer, referralData);

        // emit standard Referral event
        emit Referral(name, referrer);
    }

    /**
     * @dev Process referral. Must be implemented by derived contracts.
     *  If no ability to credit referral, MAY revert but SHOULD no-op instead.
     * @param name The name up for registration/renewal
     * @param duration The duration of the registration/renewal
     * @param price The Price info for the registration/renewal
     * @param referrer The address of the referrer
     * @param referralData Additional data for the referral
     */
    function _processReferral(
        string calldata name,
        uint64 duration,
        IPriceOracle.Price memory price,
        address referrer,
        bytes calldata referralData
    ) internal virtual;

    /**
     * @dev Allows owner to close the referral cycle by withdrawing funds
     *   NOTE: optional, left for illustrative purposes
     * @param to funds destination address
     */
    function closeCycle(address to) external onlyOwner {
        payable(to).transfer(address(this).balance);
    }

    // anyone can top off this referral cycle's commission treasury
    // NOTE: optional, left for illustrative purposes
    receive() external payable {}
}
