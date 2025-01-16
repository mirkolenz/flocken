# Changelog

## [2.4.2](https://github.com/mirkolenz/flocken/compare/v2.4.1...v2.4.2) (2025-01-16)

### Bug Fixes

* prefer custom branch over GitHub value ([#85](https://github.com/mirkolenz/flocken/issues/85)) ([062cc1b](https://github.com/mirkolenz/flocken/commit/062cc1bfc7c4563b02bb167384e668b270fdebc6))

## [2.4.1](https://github.com/mirkolenz/flocken/compare/v2.4.0...v2.4.1) (2024-12-21)

### Bug Fixes

* **manifest:** add parentheses around github api call ([ca89390](https://github.com/mirkolenz/flocken/commit/ca8939016dfb65aa0786b2c77bacaafce0045b2a))

## [2.4.0](https://github.com/mirkolenz/flocken/compare/v2.3.7...v2.4.0) (2024-12-11)

### Features

* **docker-manifest:** switch from buildah to podman ([5b3bfad](https://github.com/mirkolenz/flocken/commit/5b3bfad9940bf7609a5b5965c14ee5d9b794b2d4))

## [2.3.7](https://github.com/mirkolenz/flocken/compare/v2.3.6...v2.3.7) (2024-11-19)

### Bug Fixes

* **manifest:** separate annotation from creation, enforce exit on error ([140acea](https://github.com/mirkolenz/flocken/commit/140acea35614d339a312399786e9957ed83ab9fb))

## [2.3.6](https://github.com/mirkolenz/flocken/compare/v2.3.5...v2.3.6) (2024-11-19)

### Bug Fixes

* **manifest:** replace some strings in annotations ([ae35d50](https://github.com/mirkolenz/flocken/commit/ae35d50ce87e17f221ccbae4762f3b42cb6bc359))

## [2.3.5](https://github.com/mirkolenz/flocken/compare/v2.3.4...v2.3.5) (2024-11-19)

### Bug Fixes

* **manifest:** escape annotations ([70c4688](https://github.com/mirkolenz/flocken/commit/70c4688575493608abaedf896e14c08761752331))

## [2.3.4](https://github.com/mirkolenz/flocken/compare/v2.3.3...v2.3.4) (2024-11-19)

### Bug Fixes

* **manifest:** only escape annotation values and not keys ([3f21d54](https://github.com/mirkolenz/flocken/commit/3f21d5462077a526af20fbcc25982b6888e2ec4c))

## [2.3.3](https://github.com/mirkolenz/flocken/compare/v2.3.2...v2.3.3) (2024-11-19)

### Bug Fixes

* **docker-manifest:** compute datetime in default annotation ([8c6b1af](https://github.com/mirkolenz/flocken/commit/8c6b1af319bbd08a7457ac90152002306cb92812))
* **manifest:** properly escape annotation values ([860c3fa](https://github.com/mirkolenz/flocken/commit/860c3faa582ca0974d1588152b85f7f327ae2eb3))

## [2.3.2](https://github.com/mirkolenz/flocken/compare/v2.3.1...v2.3.2) (2024-11-19)

### Bug Fixes

* **docker-manifest:** add cleanup trap to remove tmpdir and log out of registries ([10652c7](https://github.com/mirkolenz/flocken/commit/10652c74e9b0ac46af5666dfc4519cb1b9f06a91))
* **docker-manifest:** properly annotate the manifest index ([4c6d41c](https://github.com/mirkolenz/flocken/commit/4c6d41c6bf2a40b10c2dea28f841b925bde1ea3f))

## [2.3.1](https://github.com/mirkolenz/flocken/compare/v2.3.0...v2.3.1) (2024-11-18)

### Bug Fixes

* **docker-manifest:** persist image streams to temporary directory, exit if buildah fails to push ([72388a0](https://github.com/mirkolenz/flocken/commit/72388a092c9fe712edaa5f4fb087d4603302cbad))

## [2.3.0](https://github.com/mirkolenz/flocken/compare/v2.2.0...v2.3.0) (2024-10-22)


### Features

* **docker:** add support for image streams ([35902c3](https://github.com/mirkolenz/flocken/commit/35902c3e49a94194ff8aa9fa66e954928f7d2687))

## [2.2.0](https://github.com/mirkolenz/flocken/compare/v2.1.2...v2.2.0) (2024-07-09)


### Features

* **docker-manifest:** apply additional image tags with crane ([#51](https://github.com/mirkolenz/flocken/issues/51)) ([e5d4bca](https://github.com/mirkolenz/flocken/commit/e5d4bcace2dd5d571f6e7f02c458081980022190))

## [2.1.2](https://github.com/mirkolenz/flocken/compare/v2.1.1...v2.1.2) (2024-01-01)


### Bug Fixes

* **lib:** properly construct module paths ([f5da985](https://github.com/mirkolenz/flocken/commit/f5da9851accccf6bea2e8366f6cc5699d42252ed))

## [2.1.1](https://github.com/mirkolenz/flocken/compare/v2.1.0...v2.1.1) (2023-12-31)


### Bug Fixes

* **lib:** do not import dirs without default.nix ([37aa080](https://github.com/mirkolenz/flocken/commit/37aa080f303903062fe5d509d28a3a231c0d7536))

## [2.1.0](https://github.com/mirkolenz/flocken/compare/v2.0.4...v2.1.0) (2023-12-18)


### Features

* expose custom lib via attribute and overlay ([bef593a](https://github.com/mirkolenz/flocken/commit/bef593a69f1baf851f98aa478beb574d7793456e))


### Bug Fixes

* properly use lib in docker-manifest ([f07517c](https://github.com/mirkolenz/flocken/commit/f07517c6cec605dc56074927167124def06b881f))

## [2.0.4](https://github.com/mirkolenz/flocken/compare/v2.0.3...v2.0.4) (2023-12-17)


### Bug Fixes

* remove getExe' backport after 23.11 release ([53317fd](https://github.com/mirkolenz/flocken/commit/53317fd26cd50c6347101fc3c0d3370438496745))

## [2.0.3](https://github.com/mirkolenz/flocken/compare/v2.0.2...v2.0.3) (2023-10-23)


### Bug Fixes

* backport getExe' from unstable ([316eb99](https://github.com/mirkolenz/flocken/commit/316eb99ba285596f439c2196e66a5eacc9591bd1))

## [2.0.2](https://github.com/mirkolenz/flocken/compare/v2.0.1...v2.0.2) (2023-10-23)


### Bug Fixes

* use the same timestamp for all digests ([04a72f6](https://github.com/mirkolenz/flocken/commit/04a72f60b22f0390806f3166a5a6c065ec6c1069))

## [2.0.1](https://github.com/mirkolenz/flocken/compare/v2.0.0...v2.0.1) (2023-10-23)


### Bug Fixes

* properly handle buildah login with mask ([c084b08](https://github.com/mirkolenz/flocken/commit/c084b08bc3ba3badddf5c6eee96d462d4188532f))

## [2.0.0](https://github.com/mirkolenz/flocken/compare/v1.1.5...v2.0.0) (2023-10-23)


### ⚠ BREAKING CHANGES

* The arguments and the inner logic of `mkDockerManifest` have been rewritten from scratch. The function now also handles the login to the Docker registries. Instead of providing the name (or names) of an image, you now define them for each registry individually. You can now opt out of all automatically assigned tags. There is a new GitHub integration that fetches most information automatically when run in a GitHub action. Please refer to the documentation for more details about the new arguments.

* feat!(mkDockerManifest): rewrite logic and args ([4c07c14](https://github.com/mirkolenz/flocken/commit/4c07c142ef98f129ced4838d7325991dce468268))


### Bug Fixes

* **manifest:** add tags parameter ([9554789](https://github.com/mirkolenz/flocken/commit/9554789b3420b168efccb82d454a6d0f0cc85848))
* **manifest:** output result for easier debugging ([a63e594](https://github.com/mirkolenz/flocken/commit/a63e5942fc2b1f711dfca7634bd5e482b50145cb))
* use correct variable naming again ([39d96e6](https://github.com/mirkolenz/flocken/commit/39d96e6d179b50e76f74dcc6dfc15ee4dde59dd8))
* use oci as default manifest format ([69a3e12](https://github.com/mirkolenz/flocken/commit/69a3e12442e8c3e1262a7d81b8573fb829e523cc))

## [1.1.5](https://github.com/mirkolenz/flocken/compare/v1.1.4...v1.1.5) (2023-10-09)


### Bug Fixes

* correctly import majorMinor from lib ([fb7d8dd](https://github.com/mirkolenz/flocken/commit/fb7d8dd71bd8699f9ae4f7d79f92ce0e6130ed2f))

## [1.1.4](https://github.com/mirkolenz/flocken/compare/v1.1.3...v1.1.4) (2023-10-02)


### Bug Fixes

* improve version handling ([da53417](https://github.com/mirkolenz/flocken/commit/da5341702daa7c267ad6b9d3b684f2bfefe6427c))

## [1.1.3](https://github.com/mirkolenz/flocken/compare/v1.1.2...v1.1.3) (2023-06-19)


### Bug Fixes

* add assertions ([f1c5e4d](https://github.com/mirkolenz/flocken/commit/f1c5e4dc313fa96607f206ff027284add451a6e0))

## [1.1.2](https://github.com/mirkolenz/flocken/compare/v1.1.1...v1.1.2) (2023-06-19)


### Bug Fixes

* add missing docker-manifest name ([dc27545](https://github.com/mirkolenz/flocken/commit/dc27545de7973509245cd94646845104aba68998))

## [1.1.1](https://github.com/mirkolenz/flocken/compare/v1.1.0...v1.1.1) (2023-06-19)


### Bug Fixes

* handle shellcheck SC2043 error ([d02ccd7](https://github.com/mirkolenz/flocken/commit/d02ccd7082e668708a0d1704509e89801f935b00))

## [1.1.0](https://github.com/mirkolenz/flocken/compare/v1.0.0...v1.1.0) (2023-06-18)


### Features

* specify multiple names for the manifest ([dd4ed43](https://github.com/mirkolenz/flocken/commit/dd4ed435f029c213710e7501399651aeaba66485))

## 1.0.0 (2023-06-13)


### Features

* initial version ([0e9a7ab](https://github.com/mirkolenz/flocken/commit/0e9a7abfe7fe9475d8885f0ae765bbc03f939b1f))
