# ENSv2 Referral Programs

This repo showcases a **permissionless ENSv2 Referral Program for name registrations and name renewals** and provides implementation contracts. These referral programs are permissionless to _create_ **and** (by default) are permissionless to _participate_ in. Many different referral programs may exist, each with their own reward logic and isolated commission treasury.

These contracts are designed to work with Namechain's **ETHRegistrar** but can be extended/modified to work with any ENSv2 Registry that supports registrations and renewals.

## Goals

The goals of the referral program here are to enable enable _opt-in_ usage and maximize flexibility and rapid iteration. The deployment and usage of these referral programs are permissionless: ecosystem participants can decide whether or not to deploy a program, and clients can choose whether or not to use one. The contracts do _not_ modify core ENSv2 contracts, nor do they require any special behavior from the core ENSv2 contracts.

Because each program's logic and funds are isolated from the other's, rapid iteration with different referral program schemes and reward amounts is trivial. Many referral programs can be active at any one time, each with different terms and a different commission treasury. For illustration, this repo implements:

1. [`PercentReferralProgram`](./src/examples/PercentReferralProgram.sol)
    - rewards referrers with a constant commission `%` based on the total value of the registration/renewal as calculated by the ETHRegistry
2. [`DurationReferralProgram`](./src/examples/DurationReferralProgram.sol)
    - only rewards referrers that refer a registration/renewal with a duration greater than 1 year
3. [`LoyaltyReferralProgram`](./src/examples/LoyaltyReferralProgram.sol)
    - rewards referrers an additional 1% of registration/renewal value for every 100 years of duration they've facilitated
4. [`AllowlistReferralProgram`](./src/examples/AllowlistReferralProgram.sol)
    - uses `referrerData` to implement an allowlist of referrers, demonstrating arbitrary program-specific argument data & conditions

## How it Works (TL;DR Version)

1. Anyone can deploy a `ReferralProgram` contract with their own terms & funds
    - for example, the ENS DAO may opt to sponsor one or many different `ReferralProgram`s, each with different terms & commission treasury
2. ENS apps can direct their users to use a specific `ReferralProgram#register` or `ReferralProgram#renew` to register/renew names, including the additional `address referrer` and `bytes referrerData` arguments.
3. The `ReferralProgram` forwards the request to the `ETHRegistrar` as normal, registering or renewing the relevant name
4. The `ReferralProgram` can calculate the referrer's commission (if any), and optionally credit the referrer in the same transaction.
    - arbitrary logic can be specified for how a `ReferralProgram` rewards referrers
5. That's it! Many different `ReferralProgram` contracts can be created and deployed over time to experiment with different referral systems.

## How it Works (~~Taylor's~~ Full Version)

Namechain's `ETHRegistry` allows any address to register or renew a name on behalf of an `owner`, as long as the `msg.sender` pays for the registration or renewal. This flexible behavior allows for a host of UX benefits in ENSv2, one of which is this permissionless Referral Program implementation.

First, observe the `IReferralProgram` interface specification and how it defines an event and two functions, `register` and `renew`. These functions mirror their `ETHRegistrar` counterparts, with the sole addition of the `referrer` and `referrerData` parameters.

[**IReferralProgram.sol**](./src/IReferralProgram.sol)

```solidity
interface IReferralProgram {
    // ... exerpt ...

    event Referral(string name, address referrer); // here

    function register(
        string calldata name,
        address owner,
        bytes32 secret,
        IRegistry subregistry,
        address resolver,
        uint96 flags,
        uint64 duration,
        address referrer,            // here
        bytes calldata referralData  // here
    ) external payable returns (uint256 tokenId);

    function renew(
      string calldata name,
      uint64 duration,
      address referrer,              // here
      bytes calldata referralData    // here
    ) external payable;
}
```

The core logic of this interface is implemented by `ReferralProgram`. The `ReferralProgram` is constructed with an immutable reference to the `ETHRegistry` and seeded with its own commission treasury. Its fallback handler is payable, allowing anyone to contribute more funds to the referral program in the event it should be extended. The `ReferralProgram` is `Ownable` and its owner (the deployer) can optionally close the program and withdraw any un-rewarded funds.

Important functions, `register` and `renew` are highlighted in this exerpt. They each calculate the totalPrice to register or renew the relevant name, forward the request to the `ETHRegistrar`, and defer handling of referrals to an internal `_processReferral` function that individual referral program contracts must implement.

[**ReferralProgram.sol**](./src/ReferralProgram.sol)

```solidity
abstract contract ReferralProgram is IReferralProgram, Ownable {
    // ... exerpt ...

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
}
```

For example, here is the `PercentReferralProgram`, which rewards referrers with a deployer-specified percentage on top of the `totalPrice` spent to register/renew the name.

[**examples/PercentReferralProgram.sol**](./src/examples/PercentReferralProgram.sol)

```solidity
contract PercentReferralProgram is ReferralProgram {

    // ... exerpt ...

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
```

With this small implementation of `_processReferral`, anyone can reward users who facilitate the registration or renewals of domains in the ETHRegistry in ENSv2.

To demonstrate more complex referral program logic, we can look to the `LoyaltyReferralProgram`, which rewards referrers based on how much value they've referred to ENS in the past. For every 100 years of name registration or renewal facilitated by this referrer, the contract rewards them an additional 1% on top of the totalPrice as calculated but the ETHRegistrar, up to a maximim of 20%.

[**examples/LoyaltyReferralProgram.sol**](./src/examples/LoyaltyReferralProgram.sol)

```solidity
contract LoyaltyReferralProgram is ReferralProgram {
    // ... exerpt ...

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
```

Additional custom logic is possible as well, supported by the `referralData` parameter that has yet to be used. To demonstrate its use, we look to the `AllowlistReferralProgram` which only rewards referrers on a deployer-specified allowlist. The `referrerData` parameter allows a merkle proof to be provided, efficiently proving that the given referrer is allowed by the deployer.

[**examples/AllowlistReferralProgram.sol**](./src/examples/AllowlistReferralProgram.sol)

```solidity
contract AllowlistReferralProgram is PercentReferralProgram {
    // ... exerpt ...

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
```

### Note on Rejecting Referrals

In `_processReferral` contracts that don't reward a given referrer will likely wish to simple no-op and `return`—as we've demonstrated in these example implementations—allowing the client and user to continue registering or renewing their name without interruption. This behavior also allows apps to direct users to a specific referral program contract and if/when it runs out of funds, there is no interruption in the registrations or renewals.


## License

Licensed under the MIT License, Copyright © 2025-present [NameHash Labs](https://namehashlabs.org).

See [LICENSE](./LICENSE) for more information.
