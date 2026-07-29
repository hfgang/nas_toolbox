# NAS Toolbox (NAS Toolbox)

A powerful NAS system management toolbox providing various practical features to optimize and maintain your network storage system.

## 📋 Table of Contents

- [Project Introduction](#project-introduction)
- [Features](#features)
- [System Requirements](#system-requirements)
- [Installation & Deployment](#installation-deployment)
- [Usage](#usage)
- [Feature Descriptions](#feature-descriptions)
- [Contributing](#contributing)
- [License](#license)

## Project Introduction

NAS Toolbox is a shell script-based system management tool designed specifically for NAS devices. It provides features such as system checking and log optimization to help users better manage and maintain their network storage systems.

## Features

- **System Check Tool**: Provides EMMC storage check functionality
- **Log Optimization**: Intelligently cleans and optimizes system logs
- **Root Permission Check**: Ensures safety for critical operations
- **Colored Terminal Output**: Intuitive command-line interaction experience

## System Requirements

- Linux System (Recommended NAS devices like Synology, QNAP, etc.)
- Bash shell 4.0+
- Root access permissions (required for some features)
- Basic knowledge of command-line operations

## Installation & Deployment

### Method 1: Direct Download and Use

```bash
# Clone repository
git clone https://gitee.com/hfgang/nas_toolbox.git

# Enter directory
cd nas_toolbox

# Set execution permission
chmod +x nas_toolbox.sh
```

### Method 2: Run Script Directly

```bash
# Run directly after granting execution permission
chmod +x nas_toolbox.sh
./nas_toolbox.sh
```

## Usage

### Basic Usage

```bash
# Run as normal user (some features require root permission)
./nas_toolbox.sh

# Run with root permission (recommended)
sudo ./nas_toolbox.sh
```

### Menu Operations

1. The main menu will be displayed after running the script
2. Select corresponding function via number keys
3. Press Enter key to confirm execution
4. Use Ctrl+C to exit the program

## Feature Descriptions

### 1. System Check (check_root & cmd_check_emmc)

**check_root()** - Permission Check
- Detects whether the current user has root permission
- Provides security assurance for operations requiring high privileges

**cmd_check_emmc()** - EMMC Storage Check
- Checks health status of embedded storage devices
- Displays storage space usage
- Provides storage warning functionality

### 2. Log Optimization (cmd_optimize_log)

**cmd_optimize_log()** - Log Management
- Clean up expired log files
- Compress historical logs
- Free up storage space
- Optimize log configuration

### 3. Terminal Color Support

Built-in colored output system for easy identification of different types of information:
- 🔴 Red: Warnings and error messages
- 🟡 Yellow: Hints and attention notices
- 🟢 Green: Success status
- 🔵 Blue: General information
- ⚪ White/NC: Normal text

## Contributing

We welcome community contributors to participate in the development and improvement of the project:

1. **Fork** this repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Submit a **Pull Request**

## Feedback & Suggestions

If you have any questions or suggestions, please provide feedback via the following methods:

- Submit issues on [Gitee Issues](https://gitee.com/hfgang/nas_toolbox/issues)
- Send an email to the project maintainer

## License

This project is open-source under the MIT license. For details, please refer to the [LICENSE](LICENSE) file.

---

**Development & Maintenance**: [hfgang](https://gitee.com/hfgang)  
**Project URL**: [https://gitee.com/hfgang/nas_toolbox](https://gitee.com/hfgang/nas_toolbox)

---

> ⚠️ **Note**: Please ensure important data is backed up before use. Some operations may affect system performance.