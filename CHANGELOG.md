## [1.1.0] - 2025-07-02
Major improvements to configuration and deployment verification
### Added
- Environment variable support via .env file
  - PROD_OWNER: Production owner address
  - MAINNET_CHAIN_IDS: Comma-separated list of mainnet chain IDs
  - FORCE_DEPLOY: Force deployment when verification JSON differs
- FORCE_DEPLOY flag to override verification checks during development
- Timestamped verification JSON files when FORCE_DEPLOY is used
### Changed
- Removed redundant productionOwner and isProductionChain mapping
- Improved folder structure - removed unused verification folder
- Standard JSON inputs now saved directly in deployments/{project}/standard-json-inputs/
### Fixed
- JSON verification now happens before transaction broadcast, allowing safe abort

## [1.0.1] - 2025-06-23
A lot of minor improvements
### Added
- CHANGELOG.md
- Versioning
### Changed
- Improved function naming. Now all internal functions start with _
- Introduced remapping to avoid "hardlinking"
- Directly copyied CreateX files into ./script for easier setup
- Removed example code. Please refer to [deploy-helper-starter](https://github.com/EthSign/deploy-helper-starter)
### Fixed

## [1.0.0] - 2025-06-22
First draft of the package
### Added
### Changed
### Fixed
