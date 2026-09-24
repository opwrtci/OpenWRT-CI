#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修正高通等5G高频段初始信道100(DFS不可用)为原生支持的149
	sed -i 's/let channel = rband.default_channel ?? "auto";/let channel = (rband.default_channel == 100 ? 149 : (rband.default_channel ?? "auto"));/g' $WIFI_UC
	#统一 fallback 国家码为 US，杜绝 ath11k_pci failed to perform regd update: -22 错误
	sed -i "s/country || 'CN'/country || 'US'/g" $WIFI_UC
fi

#雅典娜三频射频信道校准与QCN9074稳定性物理规范脚本
ATHENA_WIFI_DEF="./target/linux/qualcommax/base-files/etc/uci-defaults/993_set-athena-wireless.sh"
mkdir -p "$(dirname "$ATHENA_WIFI_DEF")"
cat << 'EOF' > "$ATHENA_WIFI_DEF"
#!/bin/sh
# SPDX-License-Identifier: MIT
# Qualcommax Wi-Fi Defaults & Athena Tri-Band / QCN9074 Fixes

. /lib/functions.sh 2>/dev/null
. /lib/functions/system.sh 2>/dev/null

BASE_SSID='OWRT'
BASE_WORD='12345678'

case "$(cat /tmp/sysinfo/board_name 2>/dev/null || board_name 2>/dev/null)" in
jdcloud,re-cs-02)
	# === JDCloud RE-CS-02 (Athena / 雅典娜) 三频独立优化与 QCN9074 物理规范对齐 ===
	for dev in $(uci -q show wireless | grep -oE "wireless\.radio[0-9]+" | sort -u | cut -d. -f2); do
		iface=$(uci -q show wireless | grep -E "\.device='$dev'" | head -n 1 | cut -d. -f2)
		[ -z "$iface" ] && iface="default_$dev"
		path=$(uci -q get wireless.$dev.path)
		band=$(uci -q get wireless.$dev.band)

		# 1. 2.4GHz 频段 (IPQ6000 2.4G)
		if [ "$band" = "2g" ]; then
			uci -q set wireless.$dev.country='US'
			uci -q set wireless.$dev.channel='1'
			uci -q set wireless.$dev.htmode='HE20'
			uci -q set wireless.$iface.ssid="${BASE_SSID}_2.4G"
			uci -q set wireless.$iface.encryption='psk2+ccmp'
			uci -q set wireless.$iface.key="${BASE_WORD}"
			uci -q set wireless.$iface.disabled='0'
		# 2. 5GHz-2 电竞频段 (QCN9074 5G PCIe 插卡 - 低信道 36 / 功率 23dBm / 关闭 4x4 束波成型避免客户端死锁)
		elif echo "$path" | grep -qi "pcie"; then
			uci -q set wireless.$dev.country='US'
			uci -q set wireless.$dev.channel='36'
			uci -q set wireless.$dev.htmode='HE80'
			uci -q set wireless.$dev.txpower='23'
			uci -q set wireless.$dev.mu_beamformer='0'
			uci -q set wireless.$dev.he_mu_beamformer='0'
			uci -q set wireless.$dev.beamformer='0'
			uci -q set wireless.$dev.he_su_beamformer='0'
			uci -q set wireless.$iface.ssid="${BASE_SSID}_5G_Game"
			uci -q set wireless.$iface.encryption='psk2+ccmp'
			uci -q set wireless.$iface.key="${BASE_WORD}"
			uci -q set wireless.$iface.disabled='0'
		# 3. 5GHz-1 频段 (IPQ6000 SOC 板载 5G - 高信道 149)
		elif [ "$band" = "5g" ]; then
			uci -q set wireless.$dev.country='US'
			uci -q set wireless.$dev.channel='149'
			uci -q set wireless.$dev.htmode='HE80'
			uci -q set wireless.$iface.ssid="${BASE_SSID}_5G"
			uci -q set wireless.$iface.encryption='psk2+ccmp'
			uci -q set wireless.$iface.key="${BASE_WORD}"
			uci -q set wireless.$iface.disabled='0'
		fi
	done
	uci -q commit wireless
	;;
*)
	# 通用 qualcommax 设备的国家码规范统一为 US (避免 ath11k 固件 -22 错误)
	for dev in $(uci -q show wireless | grep -oE "wireless\.radio[0-9]+" | sort -u | cut -d. -f2); do
		[ "$(uci -q get wireless.$dev.country)" = "CN" ] && uci -q set wireless.$dev.country='US'
	done
	uci -q commit wireless
	;;
esac

exit 0
EOF
sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" "$ATHENA_WIFI_DEF"
sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" "$ATHENA_WIFI_DEF"
chmod +x "$ATHENA_WIFI_DEF"

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE
#修改默认NTP服务器：移除存在DNS重绑定风险的cn.ntp.org.cn，增补微软及Cloudflare权威授时源
sed -i "s/cn\.ntp\.org\.cn/time.windows.com/g" $CFG_FILE
sed -i "/time\.windows\.com/a \\\t\\tadd_list system.ntp.server='time.cloudflare.com'" $CFG_FILE

#增补UCI自愈升级脚本，确保保留配置升级时自动清理旧版残留的cn.ntp.org.cn
SYS_NTP_DEF="./package/base-files/files/etc/uci-defaults/994_set-system-ntp.sh"
mkdir -p "$(dirname "$SYS_NTP_DEF")"
cat << 'EOF' > "$SYS_NTP_DEF"
#!/bin/sh
# SPDX-License-Identifier: MIT
# 自动净化升级或保留配置中残留的污染授时源，对齐微软及Cloudflare权威授时阵列

if uci -q get system.ntp.server | grep -q "cn.ntp.org.cn"; then
	uci -q del_list system.ntp.server="cn.ntp.org.cn"
fi

if ! uci -q get system.ntp.server | grep -q "time.windows.com"; then
	uci -q add_list system.ntp.server="time.windows.com"
fi

if ! uci -q get system.ntp.server | grep -q "time.cloudflare.com"; then
	uci -q add_list system.ntp.server="time.cloudflare.com"
fi

uci -q commit system
exit 0
EOF
chmod +x "$SYS_NTP_DEF"

#预置docker用户组，消除dockerd启动时group docker not found警告
GROUP_FILE="./package/base-files/files/etc/group"
if [ -f "$GROUP_FILE" ]; then
	grep -q "^docker:" "$GROUP_FILE" || echo "docker:x:1000:docker" >> "$GROUP_FILE"
fi

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
