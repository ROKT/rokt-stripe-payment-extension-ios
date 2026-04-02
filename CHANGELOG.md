<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-03-25

### Added

- `RoktStripePaymentExtension` implementing `PaymentExtension` protocol from RoktContracts
- Apple Pay support via Stripe's `STPApplePayContext`
- `ContactAddressMapping` for converting Apple Pay contact data to contract types
- Swift Package Manager and CocoaPods support
- GitHub Actions CI (trunk lint, unit tests, podspec lint)
- Dependabot for GitHub Actions dependency updates
