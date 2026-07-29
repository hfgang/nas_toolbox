

# NAS Toolbox (NAS 工具箱)

一个功能强大的NAS系统管理工具箱，提供多种实用功能来优化和维护您的网络存储系统。

## 📋 目录

- [项目简介](#项目简介)
- [功能特性](#功能特性)
- [系统要求](#系统要求)
- [安装部署](#安装部署)
- [使用方法](#使用方法)
- [功能说明](#功能说明)
- [参与贡献](#参与贡献)
- [许可证](#许可证)

## 项目简介

NAS Toolbox 是一个基于 Shell 脚本的系统管理工具，专为NAS设备设计，提供系统检查、日志优化等功能，帮助用户更好地管理和维护其网络存储系统。

## 功能特性

- **系统检查工具**：提供EMMC存储检查功能
- **日志优化**：智能清理和优化系统日志
- **Root权限检查**：确保关键操作的安全性
- **彩色终端输出**：直观的命令行交互体验

## 系统要求

- Linux 系统（推荐NAS设备如群晖、威联通等）
- Bash shell 4.0+
- Root 访问权限（部分功能需要）
- 基本的命令行操作知识

## 安装部署

### 方式一：直接下载使用

```bash
# 克隆仓库
git clone https://gitee.com/hfgang/nas_toolbox.git

# 进入目录
cd nas_toolbox

# 设置执行权限
chmod +x nas_toolbox.sh
```

### 方式二：直接运行脚本

```bash
# 赋予执行权限后直接运行
chmod +x nas_toolbox.sh
./nas_toolbox.sh
```

## 使用方法

### 基本用法

```bash
# 以普通用户运行（部分功能需要root权限）
./nas_toolbox.sh

# 以root权限运行（推荐）
sudo ./nas_toolbox.sh
```

### 菜单操作

1. 运行脚本后会显示主菜单
2. 通过数字键选择相应功能
3. 按回车键确认执行
4. 使用 Ctrl+C 退出程序

## 功能说明

### 1. 系统检查 (check_root & cmd_check_emmc)

**check_root()** - 权限检查
- 检测当前用户是否具有root权限
- 为需要高权限的操作提供安全保障

**cmd_check_emmc()** - EMMC存储检查
- 检查嵌入式存储设备健康状态
- 显示存储空间使用情况
- 提供存储预警功能

### 2. 日志优化 (cmd_optimize_log)

**cmd_optimize_log()** - 日志管理
- 清理过期日志文件
- 压缩历史日志
- 释放存储空间
- 优化日志配置

### 3. 终端色彩支持

内置彩色输出系统，便于识别不同类型的信息：
- 🔴 红色：警告和错误信息
- 🟡 黄色：提示和注意信息
- 🟢 绿色：成功状态
- 🔵 蓝色：常规信息
- ⚪ 白色/NC：普通文本

## 参与贡献

我们欢迎社区贡献者参与项目的开发和改进：

1. **Fork** 本仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交 **Pull Request**

## 反馈建议

如有任何问题或建议，请通过以下方式反馈：

- 在 [Gitee Issues](https://gitee.com/hfgang/nas_toolbox/issues) 提交问题
- 发送邮件至项目维护者

## 许可证

本项目采用 MIT 许可证开源，详情请参阅 [LICENSE](LICENSE) 文件。

---

**开发维护**: [hfgang](https://gitee.com/hfgang)  
**项目地址**: [https://gitee.com/hfgang/nas_toolbox](https://gitee.com/hfgang/nas_toolbox)

---

> ⚠️ **注意**：使用前请确保备份重要数据，部分操作可能影响系统性能。