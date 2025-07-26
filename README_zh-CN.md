# `nupk` - 一个新的软件包管理工具

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/mokeyish/nupk/blob/main/LICENSE)
[![NuShell](https://img.shields.io/badge/Powered%20by-NuShell-green.svg)](https://www.nushell.sh)

> 简化 GitHub Releases 的软件包安装、更新和卸载流程

解决多系统环境下的软件管理痛点：
- 🚀 自动化安装常用工具
- ⚡ 一键更新保持软件最新
- 📦 支持自定义安装路径配置
- 🔍 透明化管理已安装软件

## 安装要求

- 已安装 [Nushell](https://www.nushell.sh) (v0.106.0+)
- `curl` 和 `unzip` 基础工具

## 快速安装

```bash
curl -LsSf https://raw.githubusercontent.com/mokeyish/nupk/main/install.sh | sh
```

> **提示**：安装后可通过 `nupk` 管理 Nushell 自身的版本更新

## 使用指南

### 基础命令

| 命令 | 简写 | 说明 |
|------|------|------|
| `nupk install <package>` | `nupk -i` | 安装软件包 |
| `nupk uninstall <package>` | `nupk -r` | 卸载软件包 |
| `nupk list` | `nupk -l` | 查看已安装包 |
| `nupk --help` | `nupk -h` | 查看帮助 |

### 安装示例

```bash
# 安装最新版
nupk install lazygit

# 安装特定版本
nupk install lazygit@v0.28.1

# 通过仓库地址安装
nupk install https://github.com/jesseduffield/lazygit.git
```

### 查看安装路径
```bash
nupk info lazygit
```

## 添加新软件包

### 基础配置（以 starship 为例）
在 `registry/` 中添加：
```nu
{
    owner: starship,
    name: starship
}
```

### 高级配置（以 helix 为例）
```nu
{
    owner: helix-editor,
    name: helix,
    install_paths: {
        "hx": "bin",                             # 安装到 $prefix/bin
        "runtime": $"($env.HOME)/.config/helix"  # 自定义安装路径
    }
}
```

> **环境变量**  
> 默认安装前缀：`$HOME/.local`  
> 可通过 `NUPK_INSTALL_PREFIX` 自定义

## 工作原理
1. 从 GitHub Releases 获取资源信息
2. 自动匹配系统架构（Linux/macOS/WSL）
3. 下载并解压到目标路径
4. 创建版本元数据便于管理

## 贡献指南
欢迎提交 PR 扩展软件包注册表：
1. Fork 本仓库
2. 在 `registry/` 添加新配置
3. 提交 Pull Request