# `nupk` - A new type of Package Manager

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/mokeyish/nupk/blob/main/LICENSE)
[![NuShell](https://img.shields.io/badge/Powered%20by-NuShell-green.svg)](https://www.nushell.sh)

English | [中文](https://github.com/mokeyish/nupk/blob/main/README_zh-CN.md)

> Simplifying package installation, updates, and uninstallation from GitHub Releases

Solves software management pain points in multi-system environments:
- 🚀 Automated installation of common tools
- ⚡ One-click updates to keep software current
- 📦 Customizable installation path configuration
- 🔍 Transparent management of installed software

## Installation Requirements

- [Nushell](https://www.nushell.sh) installed (v0.106.0+)
- Basic tools: `curl`, `file`, `tar` and `unzip` etc.

## Quick Installation

```bash
curl -LsSf https://raw.githubusercontent.com/mokeyish/nupk/main/install.sh | sh
```

> **Tip**: After installation, manage Nushell's own version updates via `nupk`

## Usage Guide

### Basic Commands

| Command | Shortcut | Description |
|------|------|------|
| `nupk install <package>` | `nupk -i` | Install package |
| `nupk uninstall <package>` | `nupk -r` | Uninstall package |
| `nupk list` | `nupk -l` | List installed packages |
| `nupk --help` | `nupk -h` | Show help |

### Installation Examples

```bash
# Install latest version
nupk install lazygit

# Install specific version
nupk install lazygit@v0.28.1

# Install via repository URL
nupk install https://github.com/jesseduffield/lazygit.git
```

### View Installation Path
```bash
nupk info lazygit
```

## Adding New Packages

### Basic Configuration (starship example)
Add in `registry/`:
```nu
{
    owner: starship,
    name: starship
}
```

### Advanced Configuration (helix example)
```nu
{
    owner: helix-editor,
    name: helix,
    install_paths: {
        "hx": "bin",                             # Installs to $prefix/bin
        "runtime": $"($env.HOME)/.config/helix"  # Custom installation path
    }
}
```

> **Environment Variables**  
> Default install prefix: `$HOME/.local`  
> Customize via `NUPK_INSTALL_PREFIX`

## How It Works
1. Fetches asset information from GitHub Releases
2. Automatically matches system architecture (Linux/macOS/WSL)
3. Downloads and extracts to target paths
4. Creates version metadata for easy management

## Contribution Guide
Welcome PRs to expand the package registry:
1. Fork this repository
2. Add new configuration in `registry/`
3. Submit Pull Request