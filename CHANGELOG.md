# Changelog

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
