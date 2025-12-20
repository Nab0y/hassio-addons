# Changelog

All notable changes to this project will be documented in this file.

## [2.1.1] - 2025-12-21

### Fixed
- Added verbose logging to API server startup for better debugging
- Added startup health checks for API servers with error reporting
- Improved error messages in configuration loading

### Technical
- Redirected stderr to stdout for Python processes
- Added traceback output for configuration loading errors
- Added process health checks after API server startup

## [2.1.0] - 2025-12-21

### Breaking Changes
- **Removed legacy single-user mode** - multi-tenant mode is now the only supported configuration
- Configuration now requires `users` array - empty configuration will cause addon to fail
- Simplified codebase by removing backward compatibility layer

### Changed
- All users now use profile-based storage in `/data/joplin/profiles/<username>`
- Configuration schema simplified - removed deprecated single-user options
- API endpoints simplified - no mode switching logic

### Migration from v2.0.x
If you were using single-user mode, update your configuration:
```yaml
# Old (v2.0.x)
sync_target: 9
sync_server_url: "https://..."
# ... other options

# New (v2.1.0+)
users:
  - name: "default"
    sync_target: 9
    sync_server_url: "https://..."
    # ... other options
```

## [2.0.2] - 2025-12-21

### Fixed
- Port conflict in single-user mode: Data API Proxy no longer starts when socat is handling port 41185
- Improved process monitoring to skip Data API Proxy checks in single-user mode

## [2.0.1] - 2025-12-21

### Fixed
- Shell quoting issues in run.sh causing addon startup crashes
- Function parameter passing using proper shell variables instead of JSON strings
- Heredoc variable expansion in configure_joplin_profile function

### Technical
- Improved shell script reliability with proper variable escaping
- Fixed compatibility with older bash versions

## [2.0.0] - 2025-12-20

### 🎉 Major Release: Multi-Tenant Support

#### Added
- **Multi-Tenant Mode** - Support for multiple users, each with their own Joplin account
- Smart Token Routing - Automatic routing of API requests based on user token
- Individual user profiles with isolated data storage
- Per-user synchronization control and status monitoring
- Dynamic Joplin CLI instance management (one per user)
- Comprehensive multi-tenant documentation with examples
- Token mapping system for automatic profile detection
- Support for up to 10 concurrent users

#### Changed
- API server now runs two instances:
  - Management API (port 41186) - unchanged
  - Smart Proxy (port 41185) - new intelligent routing layer
- Configuration schema extended with `users` array
- Token endpoint now returns all user tokens in multi-tenant mode
- Info endpoint shows mode and user list
- Enhanced sync endpoints with profile parameter support

#### Technical
- Added `requests` library for internal proxy communication
- Multiple Joplin CLI instances on sequential ports (41184, 41185, etc.)
- Profile-based data isolation in `/data/joplin/profiles/`
- Backward compatible with single-user (legacy) mode
- Smart token-to-profile mapping with caching

#### Documentation
- New MULTI_TENANT.md with complete setup guide
- Multi-user automation examples
- Voice notes per user examples
- Family event logging examples
- Migration guide from v1.x to v2.0
- Lovelace dashboard examples

### Backward Compatibility
- Fully backward compatible with v1.x configuration
- Legacy single-user mode still supported when `users` array is empty
- Existing automations continue to work without changes

## [1.2.0] - 2025-12-20

### Changed
- Replaced Flask development server with Waitress production WSGI server
- Improved API server stability and performance
- Added multi-threaded request handling (4 threads)

### Technical
- Added `py3-waitress` dependency to Dockerfile
- Updated API server startup to use production-ready WSGI server
- Removed Flask development server warning

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