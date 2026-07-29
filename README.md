# 🛠️ NAS System Toolbox (`nas_toolbox.sh`)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%2F%20NAS-blue.svg)](https://gitee.com/hfgang/nas_toolbox)

[English](#-english) | [中文说明](#-中文说明)

---

## 🇨🇳 中文说明

一个专为各类 NAS 系统（如飞牛 OS、群晖 DSM、通用 Linux 等）打造的轻量级系统存储与健康维护工具箱。

### 💡 解决的核心痛点

1. **解决机械硬盘（HDD）的噪音与损耗问题**：
   * 系统后台服务（如 `rsyslog`、`journald` 等）会高频、随机地向 `/var/log` 写入大量碎片日志。
   * 这会导致机械硬盘**无法正常休眠**，频繁引发磁头寻道噪音，并加速机械硬盘的机械磨损。
2. **解决嵌入式 eMMC 芯片的寿命危机**：
   * 许多 ARM 架构 NAS 将系统装在内置 eMMC 芯片上。长期的持续小流量写入是 eMMC 的“慢性毒药”，极易导致闪存寿命耗尽、预留块耗尽甚至系统崩溃。

### 🚀 核心功能

* **🩺 eMMC 健康度与寿命检测**：
  * 精准识别内置 eMMC 设备，调用 `mmc-utils` 读取底层 `EXT_CSD` 寄存器。
  * 直观展示 **SLC/MLC 区域寿命消耗百分比**及 **EOL（生命终结）预警状态**，结合系统内核日志给出健康总结。
* **🗂️ 日志目录内存化优化 (`Log-to-RAM`)**：
  * 一键将高频写入的 `/var/log` 目录安全迁移至内存 (`tmpfs`) 中。
  * 内置后台守护进程，支持按设定周期（默认 1 小时）或手动触发增量同步（`rsync`），将日志安全备份到指定的持久化存储盘中。

### 📥 一键安装与运行

请使用 **Root 权限** 登录你的 NAS 终端，执行以下命令即可启动工具箱：

```bash
bash <(curl -sL https://gitee.com/hfgang/nas_toolbox/raw/master/nas_toolbox.sh)
```

运行后将进入交互式主菜单：
```text
==============================================
        NAS 系统存储与健康维护工具箱          
==============================================
  [1] 检测内置 eMMC 健康度及寿命报告
  [2] 优化 log 目录位置 (Log-to-RAM 内存缓存)
  [0] 退出工具箱
----------------------------------------------
```

## 🇬🇧 English

A lightweight system storage and health maintenance toolbox designed for various NAS systems (such as fnOS, Synology DSM, general Linux, etc.).

### 💡 Core Problems Solved
1. **Noise and Wear on Mechanical Hard Drives (HDD)**:
   * Background services (like rsyslog, journald) continuously write fragmented logs to /var/log.
   * This prevents HDDs from spinning down, causes frequent head-seeking noise, and accelerates mechanical wear.
2. **Lifespan Crisis on Embedded eMMC Chips**:
   * Many ARM-based NAS devices run systems on built-in eMMC chips. Long-term continuous small writes act as "slow poison" to eMMC, easily exhausting flash lifespan and reserved blocks.
### 🚀 Key Features
* **🩺 eMMC Health & Lifespan Detection**:
  * Accurately identifies embedded eMMC devices and reads underlying EXT_CSD registers via mmc-utils.
  * Visually displays **SLC/MLC wear-leveling percentages** and **EOL (End of Life) status**.
* **🗂️ Log-to-RAM Optimization**:
  * Safely migrates high-frequency write operations of /var/log into memory (tmpfs).
  * Includes a background daemon that periodically (default: every 1 hour) or manually syncs logs (rsync) to a designated persistent storage disk.
### 📥 Quick Start
Log in to your NAS terminal with Root privileges and run the following command:

```bash
bash <(curl -sL https://gitee.com/hfgang/nas_toolbox/raw/master/nas_toolbox.sh)
```

### 📄 License
This project is licensed under the MIT License. Feel free to use, modify, and distribute.
