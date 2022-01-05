# Changelog

Changelog for FAExport API, should include entries for these types of changes:

- Added for new features.
- Changed for changes in existing functionality.
- Deprecated for soon-to-be removed features.
- Removed for now removed features.
- Fixed for any bug fixes
- Security in case of vulnerabilities.

Format inspired by https://keepachangelog.com/en/1.0.0/

## [v2022.01.1] - 2022-01-05

### Added

- Added prometheus metrics for current number of users online, `faexport_fa_users_online_total`

## [v2021.10.4] - 2021-10-25

### Fixed

- Fixing prometheus metrics for gallery/scraps/favs endpoints, which were previously recorded as endpoint=""

## [v2021.10.3] - 2021-10-25

### Added

- Added prometheus metrics at /metrics (which can be optionally secured with basic auth using `PROMETHEUS_PASS` env
  variable)

## [v2021.10.2] - 2021-10-10

### Fixed

- Fixing journal RSS feed title
- Fix to docker publish github flow

## [v2021.10.1] - 2021-10-09

### Changed

- Improving RSS feed titles
- Updating dependencies

## [v2021.04.1] - 2021-04-01

### Fixed

- Handling notes from deleted users more gracefully, rather than letting them break the `/notes/{folder}`
  and `/note/{id}` endpoints.
- Adding `user_deleted` parameter to representations of notes in the `/notes/{folder}` and `/note/{id}` endpoints.

## [v2021.03.2] - 2021-03-05

### Fixed

- Fixing cloudflare error message

## [v2021.03.1] - 2021-03-05

### Added

- Added a 503 error and some more clarity when FA is under cloudflare protection

## [v2021.02.3] - 2021-02-24

### Added

- System tests which deploy a docker image and run tests against it

### Fixed

- Changes to regression tests due to removal of "Age" from artist information

### Security

- Updating dependencies

## [v2021.02.2] - 2021-02-13
### Added
- Adding `deleted` attribute to notifications

## [v2021.02.1] - 2021-02-08
### Changed
- Moved from Travis to github actions
### Fixed
- Fixed bug in thumbnail link for SFW images

## [v2020.05.2] - 2020-05-10
### Fixed
- Switched from startup with `rackup` to using `thin`, as the former crashes after a few days

## [v2020.05.1] - 2020-05-02
### Added
- Added access log and debug log. These are in the `logs/` directory by default, but directory can be overridden with the `LOG_DIR` environment variable. The docker compose file has a volume mount and environment variable to get the logs out of the container and into the local `logs` directory.


## [v2020.03.1] - 2020-03-15
### Fixed
- Improving css selector in journal creation, and fixing it
- Fixed decision on whether to use SSL

## [v2020.02.2] - 2020-02-27
### Changed
- Improved handling of empty search results
- Improvements to publish process
- Passing APP_ENV environment variable through docker compose

## [v2020.02.1] - 2020-02-25
### Added
- Makefile, entrypoint script, and docker compose configs
- Added an error message when FA is set to the wrong style
- Added ability to specify a proxy URL for FA
- Added version number to docs

### Changed
- Improved docs css
- Hide docs links until an id or username is entered
- Allow cookies to be entered in either order
- Clarifying error message when cookie is not set

### Fixed
- Updating error message parsing and handling

## [v2020.02.0] - 2020-02-04
First release since forking repo from boothale's original.
Switch to calver versioning scheme, as FA is an external service and therefore changes there are time dependent.
The scheme being used is YYYY.0M.MICRO. Year, then zero-padded month, then micro number which will increment with changes through the month.

Added lots of fixes and new endpoints.

## [v1.1.0] - 2015-05-29
Added ability to pass login cookies, rather than username and password.
Lots of other changes

## [v1.0.0] - 2015-04-28
Initial release by boothale
