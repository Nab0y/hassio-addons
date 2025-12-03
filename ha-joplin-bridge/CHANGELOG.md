# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2024-12-04

### Changed
- Password fields (`encryption_password` and `sync_password`) now use secure password input type in UI
- Passwords are now properly masked in Home Assistant configuration interface

### Security
- Improved password handling in configuration UI

## [1.0.9] - 2024-12-27

### Changed
- **BREAKING**: Removed FileSystem sync (target 2) - not practical in HA containerized environment
- Refined supported sync targets to only practical options: 0 (None), 5 (Nextcloud), 8 (S3), 9 (Joplin Server)
- Updated documentation with clear explanations of why certain sync targets are excluded
- Improved sync service recommendations for Home Assistant users

### Removed
- FileSystem sync configuration and examples
- References to impractical sync methods in containerized environment

## [1.0.8] - 2024-12-27

### Added
- Comprehensive documentation with API examples
- Advanced automation templates for Home Assistant
- Weekly reporting automation examples
- Enhanced security event logging
- Improved error handling and diagnostics
- Full S3 compatible storage support (sync target 8)

### Changed
- **BREAKING**: Removed unsupported and impractical sync targets  
- Supported sync targets now: 0 (None), 5 (Nextcloud), 8 (S3), 9 (Joplin Server)
- Removed OAuth targets: OneDrive (3), Dropbox (7), Joplin Cloud (10)
- Removed FileSystem (2) - not practical in HA containerized environment
- Updated documentation to clearly indicate containerized compatibility

### Fixed
- Version consistency across all files
- Documentation organization and clarity
- API response formatting

### Security
- Enhanced input validation for Joplin CLI commands
- Improved subprocess security with controlled input

## [1.0.0] - 2024-01-01

### Added
- Initial release of HA Joplin Bridge for Home Assistant
- Web Clipper API on ports 41184 and 41185  
- Management API on port 41186
- Support for all Joplin sync types
- Automatic sync configuration from add-on settings
- Real-time sync status monitoring
- Support for modern 64-bit architectures (aarch64, amd64)
- English localization by default
- End-to-end encryption support (optional)
- Documentation and automation examples