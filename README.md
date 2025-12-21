# Nab0y's Home Assistant Add-ons

![Project Stage][project-stage-shield]
[![License][license-shield]](LICENSE)

Custom Home Assistant add-ons developed with AI assistance. Functional, tested, and ready to use!

## ⚠️ Important Notice

**AI-Assisted Development**: These add-ons are created with modern AI tools and collaborative development approach. They are fully functional and tested, though may not follow all traditional development conventions.

**Bug Reports Welcome**: If you encounter issues, please report them! Contributions and improvements are always appreciated.

## Add-ons

### [HA Joplin Bridge](ha-joplin-bridge/)

![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)
![Supports aarch64 Architecture](https://img.shields.io/badge/aarch64-yes-green.svg)
![Supports amd64 Architecture](https://img.shields.io/badge/amd64-yes-green.svg)
![AI Assisted](https://img.shields.io/badge/AI%20assisted-🤖-purple.svg)

Bridge between Home Assistant and Joplin with Web Clipper API support.

**Key Features:**
- 👥 **Multi-Tenant** - Multiple users, each with their own Joplin account
- 🌐 **Web Clipper API** - Full Joplin REST API for notes and notebooks
- 🔄 **Multi-Service Sync** - Joplin Server, Nextcloud, S3
- 🔧 **Management API** - Sync control, status monitoring, system info  
- 📝 **HA Integration** - Perfect for automations and event logging
- 🔒 **Encryption** - Optional end-to-end encryption support
- 🚀 **Multi-Platform** - Supports aarch64 and amd64 architectures

[📖 Documentation](ha-joplin-bridge/MULTI_TENANT.md) | [📋 Changelog](ha-joplin-bridge/CHANGELOG.md)

---

## Installation

### Method 1: Add Repository (Recommended)

1. Navigate to **Supervisor** → **Add-on Store** in Home Assistant
2. Click the **⋮** (three dots) in the top right corner
3. Select **Repositories**
4. Add this repository URL:
   ```
   https://github.com/Nab0y/hassio-addons
   ```
5. Click **Add** and wait for the repository to load
6. Find the desired add-on in the store and click **Install**

### Method 2: Manual Installation

For advanced users who want to install add-ons manually, copy the add-on folder to your Home Assistant add-ons directory.

**Note**: Manual installation is not recommended for these AI-assisted add-ons unless you're comfortable debugging potential issues.

## Support & Troubleshooting

### Getting Help

If you encounter issues:

1. **Check the documentation** - detailed docs available for each add-on
2. **Review logs** - Home Assistant → Settings → Add-ons → [Add-on] → Logs  
3. **Check GitHub Issues** - search for similar problems and solutions
4. **Be specific** - include HA version, add-on version, error messages, and reproduction steps

### Community Support

- **Bug reports** with detailed information
- **Feature requests** and improvement suggestions  
- **Code contributions** and reviews are welcome
- **Documentation improvements** and examples

## Contributing

### Ways to Contribute
- 🐛 **Bug Reports** - detailed issue descriptions with logs
- 💡 **Feature Requests** - suggest improvements and new functionality
- 🔧 **Pull Requests** - code fixes, enhancements, and optimizations
- 📖 **Documentation** - improve guides, examples, and explanations
- ⭐ **Star the repo** - show appreciation for the project

### Development Guidelines
- Follow existing code style and conventions
- Test changes thoroughly before submitting
- Update documentation for new features
- Use clear commit messages and PR descriptions

## Roadmap

Future add-ons in planning:
- 📊 **Analytics Dashboard** - Custom metrics and visualization
- 🔐 **Security Monitor** - Enhanced security monitoring  
- 🏠 **Smart Home Hub** - Advanced device management
- 📱 **Mobile Notifications** - Extended notification system

*Suggestions and feature requests welcome!*

## License

MIT License - see [LICENSE](LICENSE) file for details.

**Translation**: You can use this code, improve it, learn from it, but don't blame us if your smart home becomes sentient! 🤖

---

**Made with ❤️ and 🤖 AI assistance for the Home Assistant community**

[project-stage-shield]: https://img.shields.io/badge/project%20stage-experimental%20AI--assisted-orange.svg
[maintenance-shield]: https://img.shields.io/maintenance/yes/2024.svg
[license-shield]: https://img.shields.io/github/license/Nab0y/hassio-addons.svg