#!/bin/bash
# ==============================================================================
# 工具箱名称: nas_toolbox.sh
# 适用系统: 群晖 DSM / 飞牛 OS / 通用 Linux NAS
# 功能描述: 1. 检测内置 eMMC 健康度与寿命 (支持部分 ARM 架构 NAS)
#           2. 一键优化 /var/log 目录 (Log-to-RAM，保护 eMMC/机械盘寿命)
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;36m'
NC='\033[0m' # 重置颜色

# 检查是否以 root 权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ 错误: 请使用 root 权限运行此脚本！(例如: sudo bash nas_toolbox.sh)${NC}"
        exit 1
    fi
}

# ==============================================================================
# 功能模块 1：检测 eMMC 健康度
# ==============================================================================
cmd_check_emmc() {
    echo -e "\n${BLUE}==============================================${NC}"
    echo -e "${BLUE}          开始执行：eMMC 健康度检测             ${NC}"
    echo -e "${BLUE}==============================================${NC}"

    # 1. 检查依赖工具
    echo -e "${GREEN}===== 1. 检查依赖工具 =====${NC}"
    if ! command -v mmc &> /dev/null; then
        echo -e "${YELLOW}未安装 mmc-utils，正在尝试自动安装...${NC}"
        if command -v apt &> /dev/null; then
            apt update && apt install -y mmc-utils
        elif command -v yum &> /dev/null; then
            yum install -y mmc-utils
        else
            echo -e "${RED}当前系统未识别到包管理器或非支持架构，无法自动安装 mmc-utils。${NC}"
            echo -e "${YELLOW}提示: 如果是群晖等无 eMMC 的系统，此项功能可能无法使用。${NC}"
            return 1
        fi
    else
        echo -e "mmc-utils 已就绪。"
    fi

    # 2. 识别 eMMC 设备
    echo -e "\n${GREEN}===== 2. 识别 eMMC 设备 =====${NC}"
    MMC_DEVICE=$(df | grep -E "/dev/mmcblk.*p[0-9]+ /(|/boot)" | awk -F'p' '{print $1}' | head -1)
    if [ -z "$MMC_DEVICE" ]; then
        MMC_DEVICE=$(ls /dev/mmcblk* 2>/dev/null | grep -E "^/dev/mmcblk[0-9]+$" | head -1)
    fi
    if [ -z "$MMC_DEVICE" ]; then
        MMC_DEVICE="/dev/mmcblk1"
    fi

    if [ ! -b "$MMC_DEVICE" ]; then
        echo -e "${RED}未检测到合法的 eMMC 设备！当前识别路径：$MMC_DEVICE${NC}"
        echo -e "${YELLOW}当前 NAS 可能不包含板载 eMMC 存储（例如标准群晖机型）。${NC}"
        return 1
    fi
    echo -e "检测到 eMMC 设备：${YELLOW}$MMC_DEVICE${NC}"

    # 3. 读取核心健康参数
    echo -e "\n${GREEN}===== 3. 读取 eMMC 健康参数 =====${NC}"
    EXT_CSD_DATA=$(sudo mmc extcsd read "$MMC_DEVICE" 2>/dev/null)

    if [ -z "$EXT_CSD_DATA" ]; then
        echo -e "${RED}无法读取 $MMC_DEVICE 的扩展寄存器数据，设备可能不支持该操作。${NC}"
        return 1
    fi

    LIFE_TIME_A=$(echo "$EXT_CSD_DATA" | grep "EXT_CSD_DEVICE_LIFE_TIME_EST_TYP_A" | awk '{print $NF}')
    LIFE_TIME_B=$(echo "$EXT_CSD_DATA" | grep "EXT_CSD_DEVICE_LIFE_TIME_EST_TYP_B" | awk '{print $NF}')
    PRE_EOL=$(echo "$EXT_CSD_DATA" | grep "PRE_EOL_INFO" | awk '{print $NF}')

    parse_life_time() {
        case $1 in
            0x01) echo "0-10% (健康)" ;;
            0x02) echo "10-20% (健康)" ;;
            0x03) echo "20-30% (健康)" ;;
            0x04) echo "30-40% (健康)" ;;
            0x05) echo "40-50% (健康)" ;;
            0x06) echo "50-60% (注意)" ;;
            0x07) echo "60-70% (注意)" ;;
            0x08) echo "70-80% (警告)" ;;
            0x09) echo "80-90% (警告)" ;;
            0x0A) echo "90-100% (危险，接近寿命终点)" ;;
            *) echo "未知或不支持 ($1)" ;;
        esac
    }

    parse_pre_eol() {
        case $1 in
            0x01) echo -e "${GREEN}正常 (剩余寿命>30%)${NC}" ;;
            0x02) echo -e "${YELLOW}降级 (剩余寿命<30%)${NC}" ;;
            0x03) echo -e "${RED}紧急 (剩余寿命<10%，建议只读)${NC}" ;;
            *) echo "未知 ($1)" ;;
        esac
    }

    echo -e "SLC区域寿命: ${LIFE_TIME_A:-N/A} → $(parse_life_time "$LIFE_TIME_A")"
    echo -e "MLC区域寿命: ${LIFE_TIME_B:-N/A} → $(parse_life_time "$LIFE_TIME_B")"
    echo -e "整体EOL状态: ${PRE_EOL:-N/A} → $(parse_pre_eol "$PRE_EOL")"

    # 4. 检查坏块与系统错误
    echo -e "\n${GREEN}===== 4. 检查坏块与系统错误 =====${NC}"
    BAD_BLOCKS=$(echo "$EXT_CSD_DATA" | grep -i "bad" | grep -v "no info" || echo "无坏块信息")
    echo -e "坏块管理状态: $BAD_BLOCKS"

    echo -e "最近10条 eMMC/区块 相关内核错误日志："
    dmesg | grep -i "mmc\|blk" | grep -i "error\|fail\|timeout" | tail -10 || echo -e "${GREEN}无错误日志${NC}"

    # 5. 健康度总结
    echo -e "\n${GREEN}===== 5. 健康度总结 =====${NC}"
    if [[ "$PRE_EOL" == "0x01" && "$LIFE_TIME_A" != "0x08" && "$LIFE_TIME_A" != "0x09" && "$LIFE_TIME_A" != "0x0A" ]]; then
        echo -e "${GREEN}✅ eMMC 健康度良好，可正常使用${NC}"
    elif [[ "$PRE_EOL" == "0x02" || "$LIFE_TIME_A" == "0x08" || "$LIFE_TIME_A" == "0x09" ]]; then
        echo -e "${YELLOW}⚠️ eMMC 健康度警告，建议备份重要数据，减少频繁写入${NC}"
    elif [[ "$PRE_EOL" == "0x03" || "$LIFE_TIME_A" == "0x0A" ]]; then
        echo -e "${RED}❌ eMMC 健康度危险，立即备份数据，建议更换设备${NC}"
    else
        echo -e "${YELLOW}ℹ️ 部分健康参数无法完全识别，建议结合日志和使用情况判断${NC}"
    }
}

# ==============================================================================
# 功能模块 2：优化 log 目录位置 (Log-to-RAM)
# ==============================================================================
cmd_optimize_log() {
    echo -e "\n${BLUE}==============================================${NC}"
    echo -e "${BLUE}       开始执行：优化 /var/log 目录配置         ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo -e "提示：该功能将日志转存至内存 (tmpfs)，并定时同步到指定的持久化存储盘中，"
    echo -e "不仅能拯救 eMMC，对机械硬盘减少频繁唤醒和磨损也同样适用。\n"

    # 1. 扫描可用存储盘
    echo "正在扫描系统挂载点以寻找合适的持久化存储盘..."
    mapfile -t MOUNT_POINTS < <(df -BM --output=target,avail,fstype | awk 'NR>1 && $1 !~ /^\/(boot|sys|proc|dev|run|tmp|var\/log)?$/ && $3 !~ /^(tmpfs|overlay|squashfs)$/ {print $1 "|" $2 "|" $3}')

    if [ ${#MOUNT_POINTS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️ 未检测到标准外挂数据盘挂载点！${NC}"
        read -p "请输入一个安全的持久化目录绝对路径（例如群晖的 /volume1/ssd/system_log_bak）: " TARGET_BASE_DIR
    else
        echo "检测到以下可用存储路径:"
        index=1
        declare -A PATH_MAP
        for item in "${MOUNT_POINTS[@]}"; do
            IFS="|" read -r mpath mavail mfstype <<< "$item"
            echo "  [$index] 路径: $mpath (可用空间: $mavail, 文件系统: $mfstype)"
            PATH_MAP[$index]="$mpath"
            ((index++))
        done
        echo "  [0] 手动输入其他自定义路径"

        read -p "请选择用于存放日志备份的存储盘编号 [1-$((index-1))]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$index" ]; then
            TARGET_BASE_DIR="${PATH_MAP[$choice]}/system_log_bak"
        else
            read -p "请输入你自定义的绝对路径: " TARGET_BASE_DIR
        fi
    fi

    if [ -z "$TARGET_BASE_DIR" ]; then
        echo -e "${RED}❌ 路径不能为空，操作终止。${NC}"
        return 1
    fi

    echo -e "✅ 选定的日志持久化备份目录为: ${YELLOW}$TARGET_BASE_DIR${NC}"

    # 2. 生成底层管理脚本
    INSTALL_BIN="/usr/local/bin/log_to_ram.sh"
    SERVICE_FILE="/etc/systemd/system/log2ram.service"
    RAM_SIZE="100M"
    SYNC_TIME=3600

    echo "正在写入核心运行脚本到 $INSTALL_BIN ..."
    cat << EOF > "$INSTALL_BIN"
#!/bin/bash
RAM_DISK_SIZE="$RAM_SIZE"
BACKUP_DIR="$TARGET_BASE_DIR"
LOG_TARGET="/var/log"
SYNC_INTERVAL=$SYNC_TIME

mkdir -p "\$BACKUP_DIR"

case "\$1" in
    start)
        if ! grep -q " \$LOG_TARGET " /proc/mounts; then
            cp -a "\$LOG_TARGET"/. "\$BACKUP_DIR"/ 2>/dev/null
            mount -t tmpfs -o size="\$RAM_DISK_SIZE",noatime,nodiratime tmpfs "\$LOG_TARGET"
            cp -a "\$BACKUP_DIR"/. "\$LOG_TARGET"/
            chmod 755 "\$LOG_TARGET"
            
            # 智能兼容不同系统的日志服务重启
            if command -v systemctl &> /dev/null; then
                if systemctl list-units --full --all | grep -q "systemd-journald"; then
                    systemctl restart systemd-journald
                elif systemctl list-units --full --all | grep -q "rsyslog"; then
                    systemctl restart rsyslog
                fi
            elif [ -x /usr/syno/sbin/synoservicectl ]; then
                /usr/syno/sbin/synoservicectl --restart syslog-ng 2>/dev/null
            fi

            echo "[\\\$(date)] 成功将 /var/log 挂载至内存 (\$RAM_DISK_SIZE)"
        else
            echo "[\\\$(date)] /var/log 已经在内存中，跳过挂载。"
        fi

        if ! pgrep -f "\$0 daemon" > /dev/null; then
            "\$0" daemon &
            echo "[\\\$(date)] 后台同步进程已启动"
        fi
        ;;
    daemon)
        while true; do
            sleep "\$SYNC_INTERVAL"
            if grep -q " \$LOG_TARGET " /proc/mounts; then
                rsync -a --delete "\$LOG_TARGET"/ "\$BACKUP_DIR"/
                sync
            fi
        done
        ;;
    sync)
        if grep -q " \$LOG_TARGET " /proc/mounts; then
            rsync -a --delete "\$LOG_TARGET"/ "\$BACKUP_DIR"/
            sync
            echo "[\\\$(date)] 手动同步完成"
        else
            echo "错误: 未检测到内存挂载。"
        fi
        ;;
    *)
        echo "用法: \$0 {start|sync}"
        exit 1
        ;;
es:
exit 0
EOF
    chmod +x "$INSTALL_BIN"

    # 3. 创建并注册 Systemd 服务 (如支持)
    if command -v systemctl &> /dev/null; then
        echo "正在配置 Systemd 开机自启服务..."
        cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Log to RAM Service for NAS
After=network.target local-fs.target

[Service]
Type=forking
ExecStart=$INSTALL_BIN start

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable log2ram.service
    else
        echo -e "${YELLOW}提示: 当前系统未检测到 systemd，请根据你的 NAS 类型（如群晖计划任务）自行配置开机启动: $INSTALL_BIN start${NC}"
    fi

    # 4. 首次备份与启用
    echo "正在进行首次数据初始化与安全迁移..."
    mkdir -p "$TARGET_BASE_DIR"
    if ! grep -q " /var/log " /proc/mounts; then
        cp -a /var/log/. "$TARGET_BASE_DIR"/ 2>/dev/null
    fi
    "$INSTALL_BIN" start

    echo -e "\n${GREEN}🎉 /var/log 优化配置完成！${NC}"
    echo -e "👉 常用管理命令："
    echo -e "   - 检查挂载状态: ${BLUE}df -h /var/log${NC}"
    echo -e "   - 手动同步日志: ${BLUE}log_to_ram.sh sync${NC}"
}

# ==============================================================================
# 主菜单交互界面
# ==============================================================================
check_root

while true; do
    clear
    echo -e "${BLUE}==============================================${NC}"
    echo -e "${BLUE}        NAS 系统存储与健康维护工具箱          ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo -e "  [1] 检测内置 eMMC 健康度及寿命报告"
    echo -e "  [2] 优化 log 目录位置 (Log-to-RAM 内存缓存)"
    echo -e "  [0] 退出工具箱"
    echo -e "${BLUE}----------------------------------------------${NC}"
    read -p "请输入选项编号 [0-2]: " main_choice

    case "$main_choice" in
        1)
            cmd_check_emmc
            echo -e "\n"
            read -p "按回车键返回主菜单..."
            ;;
        2)
            cmd_optimize_log
            echo -e "\n"
            read -p "按回车键返回主菜单..."
            ;;
        0)
            echo -e "${GREEN}再见！${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ 无效的选项，请重新输入！${NC}"
            sleep 1
            ;;
    esac
done