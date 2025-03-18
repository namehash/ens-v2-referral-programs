# ENSv2 Referral Programs

This repo showcases a **permissionless ENSv2 Referral Program for name registrations and name renewals** and provides implementation contracts. These referral programs are permissionless to _create_ **and** (by default) are permissionless to _participate_ in. Many different referral programs may exist, each with their own reward logic and isolated commission treasury.

These contracts are designed to work with Namechain's **ETHRegistrar** but can be extended/modified to work with any ENSv2 Registry that supports registrations and renewals.

## Goals

The goals of the referral program proposed here are to enable enable _opt-in_ usage and maximize flexibility and rapid iteration. The deployment and usage of these referral programs are permissionless: ecosystem participants can decide whether to deploy one or not, and clients can choose whether to use one or not. The contracts do not modify core ENSv2 contracts, nor do they require any special behavior from the core ENSv2 contracts.

Because each program's logic and funds are isolated from the other's, rapid iteration with different referral program schemes and reward amounts is trivial. Many referral programs can be active at any one time, each with different terms and a different commission treasury. For illustration, this repo implements:

1. `PercentReferralProgram` — rewards referrers with a constant commission `%` based on the total value of the registration/renewal as calculated by the ETHRegistry
2. `DurationReferralProgram` — only rewards referrers that refer a registration/renewal with a duration greater than 1 year
3. `LoyaltyReferralProgram` — demonstrates rewarding a referrer an additional 1% of registration/renewal value for every 100 years of duration they've facilitated payment for over all of their referrals
4. `AllowlistReferralProgram` — demonstrates the usage of `referrerData` to support arbitrary logic & program-specific data, specifically the requirement that a given referrer be on an owner-provided merkletree-based allowlist.

## How it Works (TL;DR Version)

1. Anyone can deploy a `ReferralProgram` contract with their own terms & funds
  - for example, the ENS DAO may opt to sponsor one or many different `ReferralProgram`s, each with different terms & commission treasury
2. ENS apps can direct their users to use a specific `ReferralProgram#register` or `ReferralProgram#renew` to register/renew names, including the additional `address referrer` and `bytes referrerData` arguments.
3. The `ReferralProgram` forwards the request to the `ETHRegistrar` as normal, registering or renewing the relevant name
4. The `ReferralProgram` can calculate the referrer's commission (if any), and optionally credit the referrer in the same transaction.
  - arbitrary logic can be specified for how a `ReferralProgram` rewards referrers

## How it Works (~~Taylor's~~ Full Version)

Namechain's `ETHRegistry` allows any address to register or renew a name on behalf of an `owner`, as long as the `msg.sender` pays for the registration or renewal (for registration, the caller must also, of course, know the `secret` used to commit to the name's registration). This flexible behavior allows for a host of UX improvements in ENSv2, one of which is this permissionless Referral Program implementation.

First, observe the `IReferralProgram` interface specification and how it defines an event (helpful for indexers), and two functions, `register` and `renew`. These functions mirror their `ETHRegistrar` counterparts, with the sole addition of the `referrer` and `referrerData` parameters.

[**./src/IReferralProgram.sol**](./src/IReferralProgram.sol) — see full file for comments

```diff solidity
interface IReferralProgram {
    event Referral(string name, address referrer);

    function register(
        string calldata name,
        address owner,
        bytes32 secret,
        IRegistry subregistry,
        address resolver,
        uint96 flags,
        uint64 duration,
+        address referrer,
+        bytes calldata referralData
    ) external payable returns (uint256 tokenId);

    function renew(
      string calldata name,
      uint64 duration,
+      address referrer,
+      bytes calldata referralData
    ) external payable;
}

```

## License

Licensed under the MIT License, Copyright © 2025-present [NameHash Labs](https://namehashlabs.org).

See [LICENSE](./LICENSE) for more information.
