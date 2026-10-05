#!/bin/sh
# /etc/profile.d/99-capctl-alert.sh - SSH login notification for capctl

if [ -f "/etc/capctl_disk_alert" ]; then
	printf "\n\033[1;31m======================================================================\033[0m\n"
	printf "\033[1;31m🚨 【抓包安全熔断告警】磁盘空间占用已超 50%% 阈值，系统已自动紧急停止抓包与日志！\033[0m\n"
	cat /etc/capctl_disk_alert
	printf "\033[1;33m💡 提示: 请及时清理磁盘历史文件。重新运行 'start-cap' 或清理后将自动恢复。\033[0m\n"
	printf "\033[1;31m======================================================================\033[0m\n\n"
elif [ -f "/var/run/capctl/tcpdump.pid" ] || [ -f "/var/run/capctl/singbox.pid" ]; then
	pid="$(cat /var/run/capctl/tcpdump.pid 2>/dev/null)"
	sb_pid="$(cat /var/run/capctl/singbox.pid 2>/dev/null)"
	dest="$(cat /var/run/capctl/current_dest_dir 2>/dev/null)"
	mode="$(cat /var/run/capctl/capture_mode 2>/dev/null || echo "轻量报头模式")"
	printf "\033[1;36m[capctl] 🟢 自动全量抓包与 Sing-Box 实时日志看门狗正在后台运行\033[0m\n"
	printf "\033[1;36m[capctl] 🎯 模式: %s | 单卷: 100MB | 阈值: 50%%\033[0m\n" "$mode"
	printf "\033[1;36m[capctl] 📁 目录: %s\033[0m\n" "$dest"
	printf "\033[1;33m[capctl] 💡 命令: stop-cap (停止并还原) | status-cap (状态) | analyze-cap (故障摘要)\033[0m\n\n"
fi
