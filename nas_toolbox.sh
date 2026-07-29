#!/bin/bash
# ==============================================================================
# 工具箱名称: nas_toolbox.sh
# 适用系统: 群晖 DSM / 飞牛 OS / 通用 Linux NAS
# 功能描述: 1. 检测内置 eMMC 健康度与寿命 
#           2. 一键优化 /var/log 目录 (Log-to-RAM)
#           3. 检查 Log-to-RAM 挂载与占用状态
#           4. 动态修改内存盘大小
# ==============================================================================

# 颜色定义
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;36m'
NC='\033[0m'

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

    echo -e "${GREEN}===== 1. 检查依赖工具 =====${NC}"
    if ! command -v mmc &> /dev/null; then
        echo -e "${YELLOW}未安装 mmc-utils，正在尝试自动安装...${NC}"
        if command -v apt &> /dev/null; then
            apt update && apt install -y mmc-utils
        elif command -v yum &> /dev/null; then
            yum install -y mmc-utils
        else
            echo -e "${RED}当前系统未识别到包管理器或非支持架构，无法自动安装 mmc-utils。${NC}"
            return 1
        fi
    else
        echo -e "mmc-utils 已就绪。"
    fi

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
        return 1
    fi
    echo -e "检测到 eMMC 设备：${YELLOW}$MMC_DEVICE${NC}"

    echo -e "\n${GREEN}===== 3. 读取 eMMC 健康参数 =====${NC}"
    EXT_CSD_DATA=$(sudo mmc extcsd read "$MMC_DEVICE" 2>/dev/null)

    if [ -z "$EXT_CSD_DATA" ]; then
        echo -e "${RED}无法读取 $MMC_DEVICE 的扩展寄存器数据。${NC}"
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
            0x06) echo "50-60% (注意，该值越低越好)" ;;
            0x07) echo "60-70% (注意，该值越低越好)" ;;
            0x08) echo "70-80% (警告，该值越低越好)" ;;
            0x09) echo "80-90% (警告，该值越低越好)" ;;
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

    echo -e "\n${GREEN}===== 4. 检查坏块与系统错误 =====${NC}"
    BAD_BLOCKS=$(echo "$EXT_CSD_DATA" | grep -i "bad" | grep -v "no info" || echo "无坏块信息")
    echo -e "坏块管理状态: $BAD_BLOCKS"

    echo -e "最近10条 eMMC/区块 相关内核错误日志："
    dmesg | grep -i "mmc\|blk" | grep -i "error\|fail\|timeout" | tail -10 || echo -e "${GREEN}无错误日志${NC}"

    echo -e "\n${GREEN}===== 5. 健康度总结 =====${NC}"
    if [[ "$PRE_EOL" == "0x01" && "$LIFE_TIME_A" != "0x08" && "$LIFE_TIME_A" != "0x09" && "$LIFE_TIME_A" != "0x0A" ]]; then
        echo -e "${GREEN}✅ eMMC 健康度良好，可正常使用${NC}"
    elif [[ "$PRE_EOL" == "0x02" || "$LIFE_TIME_A" == "0x08" || "$LIFE_TIME_A" == "0x09" ]]; then
        echo -e "${YELLOW}⚠️ eMMC 健康度警告，建议备份重要数据，减少频繁写入${NC}"
    elif [[ "$PRE_EOL" == "0x03" || "$LIFE_TIME_A" == "0x0A" ]]; then
        echo -e "${RED}❌ eMMC 健康度危险，立即备份数据，建议更换设备${NC}"
    else
        echo -e "${YELLOW}ℹ️ 部分健康参数无法完全识别，建议结合日志和使用情况判断${NC}"
    fi
}

# ==============================================================================
# 功能模块 2：优化 log 目录位置 (Log-to-RAM)
# ==============================================================================
cmd_optimize_log() {
    echo -e "\n${BLUE}==============================================${NC}"
    echo -e "${BLUE}       开始执行：优化 /var/log 目录配置         ${NC}"
    echo -e "${BLUE}==============================================${NC}"
    echo -e "提示：该功能将日志转存至内存 (tmpfs)，并定时同步到指定的持久化存储盘中。\n"

    echo "正在读取系统物理硬盘及型号..."
    
    index=1
    declare -A DISK_MAP
    declare -A MOUNT_MAP
    
    for sys_dir in /sys/block/sd[a-z] /sys/block/nvme[0-9]n[0-9]; do
        if [ -d "$sys_dir" ]; then
            d_name=$(basename "$sys_dir")
            d_model="未知型号"
            d_type="未知类型"
            
            if [ -f "$sys_dir/device/model" ]; then
                d_model=$(cat "$sys_dir/device/model" 2>/dev/null | xargs)
            else
                d_model="物理磁盘 ($d_name)"
            fi
            
            if [ -f "$sys_dir/queue/rotational" ]; then
                is_rot=$(cat "$sys_dir/queue/rotational" 2>/dev/null)
                if [ "$is_rot" -eq 1 ]; then
                    d_type="机械硬盘 (HDD)"
                else
                    d_type="固态硬盘 (SSD/NVMe)"
                fi
            fi

            mounted_path=$(lsblk -n -o MOUNTPOINTS /dev/$d_name 2>/dev/null | grep -E '^/vol' | head -1)
            if [ -z "$mounted_path" ]; then
                mounted_path=$(lsblk -n -o MOUNTPOINTS /dev/$d_name 2>/dev/null | grep -v '^$' | grep -v '^/boot$' | head -1)
            fi

            echo "  [$index] 物理盘: /dev/$d_name"
            echo "      └─ 型号: $d_model | 类型: $d_type | 挂载路径: ${mounted_path:-未挂载/未知}"
            
            DISK_MAP[$index]="$d_name"
            MOUNT_MAP[$index]="${mounted_path}"
            ((index++))
        fi
    done

    if [ ${#DISK_MAP[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠️ 未检测到标准的本地物理硬盘！${NC}"
        read -p "请输入一个安全的持久化目录绝对路径: " TARGET_BASE_DIR
    else
        echo "  [0] 手动输入其他自定义路径"
        echo "--------------------------------------------------------"
        read -p "请选择目标物理硬盘编号 [0-$((index-1))]: " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$index" ]; then
            sel_disk="${DISK_MAP[$choice]}"
            sel_mount="${MOUNT_MAP[$choice]}"
            
            if [ -z "$sel_mount" ] || [ "$sel_mount" = "/" ]; then
                read -p "已选中 /dev/$sel_disk，未自动匹配到有效卷路径，请输入其挂载目录（例如 /vol1）: " sel_mount
            else
                echo -e "✅ 已自动关联到存储卷挂载路径: ${GREEN}$sel_mount${NC}"
            fi
            
            TARGET_BASE_DIR="$sel_mount/system_log_bak"
        elif [ "$choice" -eq 0 ]; then
            read -p "请输入你自定义的绝对路径: " TARGET_BASE_DIR
        else
            echo -e "${RED}❌ 无效的选择，操作终止。${NC}"
            return 1
        fi
    fi

    if [ -z "$TARGET_BASE_DIR" ]; then
        echo -e "${RED}❌ 路径不能为空，操作终止。${NC}"
        return 1
    fi

    echo -e "\n--------------------------------------------------------"
    read -p "请输入内存盘 (tmpfs) 大小 [默认 300M，直接回车即为300M]: " CUSTOM_RAM_SIZE
    if [ -z "$CUSTOM_RAM_SIZE" ]; then
        RAM_SIZE="300M"
    else
        RAM_SIZE="$CUSTOM_RAM_SIZE"
    fi
    echo -e "✅ 选定的内存盘大小为: ${YELLOW}$RAM_SIZE${NC}"
    echo -e "✅ 选定的日志持久化备份目录为: ${YELLOW}$TARGET_BASE_DIR${NC}"

    INSTALL_BIN="/usr/local/bin/log_to_ram.sh"
    SERVICE_FILE="/etc/systemd/system/log2ram.service"
    SYNC_TIME=3600

    echo "正在写入核心运行脚本到 $INSTALL_BIN ..."
    cat << 'EOF' > "$INSTALL_BIN"
#!/bin/bash
RAM_DISK_SIZE="REPLACE_RAM_SIZE"
BACKUP_DIR="REPLACE_TARGET_DIR"
LOG_TARGET="/var/log"
SYNC_INTERVAL=3600

mkdir -p "$BACKUP_DIR"

case "$1" in
    start)
        if ! grep -q " $LOG_TARGET " /proc/mounts; then
            cp -a "$LOG_TARGET"/. "$BACKUP_DIR"/ 2>/dev/null
            mount -t tmpfs -o size="$RAM_DISK_SIZE",noatime,nodiratime tmpfs "$LOG_TARGET"
            cp -a "$BACKUP_DIR"/. "$LOG_TARGET"/
            chmod 755 "$LOG_TARGET"
            
            if command -v systemctl &> /dev/null; then
                if systemctl list-units --full --all | grep -q "systemd-journald"; then
                    systemctl restart systemd-journald
                elif systemctl list-units --full --all | grep -q "rsyslog"; then
                    systemctl restart rsyslog
                fi
            elif [ -x /usr/syno/sbin/synoservicectl ]; then
                /usr/syno/sbin/synoservicectl --restart syslog-ng 2>/dev/null
            fi

            echo "[$(date)] 成功将 /var/log 挂载至内存 ($RAM_DISK_SIZE)"
        else
            echo "[$(date)] /var/log 已经在内存中，跳过挂载。"
        fi

        if ! pgrep -f "$0 daemon" > /dev/null; then
            "$0" daemon &
            echo "[$(date)] 后台同步进程已启动"
        fi
        ;;
    daemon)
        while true; do
            sleep "$SYNC_INTERVAL"
            if grep -q " $LOG_TARGET " /proc/mounts; then
                rsync -a --delete "$LOG_TARGET"/ "$BACKUP_DIR"/
                sync
            fi
        done
        ;;
    sync)
        if grep -q " $LOG_TARGET " /proc/mounts; then
            rsync -a --delete "$LOG_TARGET"/ "$BACKUP_DIR"/
            sync
            echo "[$(date)] 手动同步完成"
        else
            echo "错误: 未检测到内存挂载。"
        fi
        ;;
    *)
        echo "用法: $0 {start|sync}"
        exit 1
        ;;
es
exit 0
EOF

    sed -i "s|REPLACE_TARGET_DIR|$TARGET_BASE_DIR|g" "$INSTALL_BIN"
    sed -i "s|REPLACE_RAM_SIZE|$RAM_SIZE|g" "$INSTALL_BIN"
    chmod +x "$INSTALL_BIN"

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
        echo -e "${YELLOW}提示: 当前系统未检测到 systemd，请根据你的 NAS 类型自行配置开机启动: $INSTALL_BIN start${NC}"
    fi

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
# 功能模块 3：检查 Log-to-RAM 状态与占用
# ==============================================================================
cmd_check_status() {
    echo -e "\n${BLUE}==============================================${NC}"
    echo -e "${BLUE}        Log-to-RAM 运行状态与空间占用检查       ${NC}"
    echo -e "${BLUE}==============================================${NC}"

    if ! grep -q " /var/log " /proc/mounts; then
        echo -e "${YELLOW}⚠️ 当前 /var/log 未挂载到内存中 (未启用 Log-to-RAM)。${NC}"
    else
        echo -e "${GREEN}✅ /var/log 当前已成功挂载在内存 (tmpfs) 中：${NC}"
        df -h /var/log
    fi

    echo -e "\n----------------------------------------"
    echo -e "📁 内存日志目录占用详情 (/var/log):"
    du -sh /var/log 2>/dev/null

    echo -e "\n----------------------------------------"
    # 尝试从持久化脚本中读取备份路径
    if [ -f "/usr/local/bin/log_to_ram.sh" ]; then
        bak_dir=$(grep "BACKUP_DIR=" /usr/local/bin/log_to_ram.sh | cut -d'"' -f2)
        if [ -n "$bak_dir" ] && [ -d "$bak_dir" ]; then
            echo -e "💾 持久化备份目录位置: ${YELLOW}$bak_dir${NC}"
            echo -e "📦 持久化备份目录占用大小:"
            du -sh "$bak_dir" 2>/dev/null
        else
            echo -e "${YELLOW}ℹ️ 未能自动定位持久化备份目录。${NC}"
        fi
    else
        echo -e "${YELLOW}ℹ️ 核心管理脚本 /usr/local/bin/log_to_ram.sh 尚未安装。${NC}"
    fi
    echo -e "==============================================${NC}"
}

# ==============================================================================
# 功能模块 4：修改内存盘大小
# ==============================================================================
cmd_resize_ram() {
    echo -e "\n${BLUE}==============================================${NC}"
    echo -e "${BLUE}          动态修改 Log-to-RAM 内存盘大小      ${NC}"
    echo -e "${BLUE}==============================================${NC}"

    if [ ! -f "/usr/local/bin/log_to_ram.sh" ]; then
        echo -e "${RED}❌ 错误: 尚未安装 Log-to-RAM 脚本，请先执行选项 [2] 进行一键优化配置！${NC}"
        return 1
    fi

    current_size=$(grep "RAM_DISK_SIZE=" /usr/local/bin/log_to_ram.sh | cut -d'"' -f2)
    echo -e "当前内存盘设定大小: ${YELLOW}${current_size:-未知}${NC}"
    
    read -p "请输入新的内存盘大小 (例如 400M、512M、1G，注意要有单位): " NEW_SIZE
    if [ -z "$NEW_SIZE" ]; then
        echo -e "${YELLOW}未输入有效大小，操作取消。${NC}"
        return 1
    fi

    echo "正在更新配置文件..."
    # 替换 /usr/local/bin/log_to_ram.sh 中的内存盘大小
    sed -i "s|RAM_DISK_SIZE=\".*\"|RAM_DISK_SIZE=\"$NEW_SIZE\"|g" /usr/local/bin/log_to_ram.sh

    echo "正在重新挂载 /var/log 以应用新大小..."
    umount -l /var/log 2>/dev/null
    /usr/local/bin/log_to_ram.sh start

    echo -e "\n${GREEN}🎉 内存盘大小已成功修改为: ${YELLOW}$NEW_SIZE${NC}"
    df -h /var/log
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
    echo -e "  [2] 一键优化 /var/log 目录 (Log-to-RAM 内存缓存)"
    echo -e "  [3] 检查 Log-to-RAM 挂载状态与占用大小"
    echo -e "  [4] 修改 Log-to-RAM 内存盘大小"
    echo -e "  [0] 退出工具箱"
    echo -e "${BLUE}----------------------------------------------${NC}"
    read -p "请输入选项编号 [0-4]: " main_choice

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
        3)
            cmd_check_status
            echo -e "\n"
            read -p "按回车键返回主菜单..."
            ;;
        4)
            cmd_resize_ram
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