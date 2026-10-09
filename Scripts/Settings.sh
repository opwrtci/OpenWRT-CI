#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "/attendedsysupgrade/d" {} +
#修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" {} +
#修改immortalwrt.lan关联IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -exec sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" {} +
#添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -exec sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" {} +

WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_UC" ]; then
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
			uci -q set wireless.$iface.disassoc_low_ack='0'
			uci -q set wireless.$iface.uapsd='0'
			uci -q set wireless.$iface.ieee80211k='1'
			uci -q set wireless.$iface.ieee80211v='1'
			uci -q set wireless.$iface.bss_transition='1'
			uci -q set wireless.$iface.disabled='0'
		# 2. 5GHz-2 电竞频段 (QCN9074 5G PCIe 插卡 - 低信道 36 / 发射功率 28dBm / 开启 4x4 MU-MIMO 与 SU/HE 波束成形增强穿墙与物理层覆盖)
		elif echo "$path" | grep -qi "pcie"; then
			uci -q set wireless.$dev.country='US'
			uci -q set wireless.$dev.channel='36'
			uci -q set wireless.$dev.htmode='HE80'
			uci -q set wireless.$dev.txpower='28'
			uci -q set wireless.$dev.beamformer='1'
			uci -q set wireless.$dev.su_beamformer='1'
			uci -q set wireless.$dev.mu_beamformer='1'
			uci -q set wireless.$dev.he_su_beamformer='1'
			uci -q set wireless.$dev.he_mu_beamformer='1'
			uci -q set wireless.$dev.su_beamformee='1'
			uci -q set wireless.$dev.he_su_beamformee='1'
			uci -q set wireless.$dev.he_twt_responder='0'
			uci -q set wireless.$dev.he_twt_required='0'
			uci -q set wireless.$iface.ssid="${BASE_SSID}_5G_Game"
			uci -q set wireless.$iface.encryption='psk2+ccmp'
			uci -q set wireless.$iface.key="${BASE_WORD}"
			uci -q set wireless.$iface.disassoc_low_ack='0'
			uci -q set wireless.$iface.uapsd='0'
			uci -q set wireless.$iface.ieee80211k='1'
			uci -q set wireless.$iface.ieee80211v='1'
			uci -q set wireless.$iface.bss_transition='1'
			uci -q set wireless.$iface.disabled='0'
		# 3. 5GHz-1 频段 (IPQ6000 SOC 板载 5G - 高信道 149 / 发射功率 28dBm / 开启 SU/MU 波束成形与弱信号防踢)
		elif [ "$band" = "5g" ]; then
			uci -q set wireless.$dev.country='US'
			uci -q set wireless.$dev.channel='149'
			uci -q set wireless.$dev.htmode='HE80'
			uci -q set wireless.$dev.txpower='28'
			uci -q set wireless.$dev.beamformer='1'
			uci -q set wireless.$dev.su_beamformer='1'
			uci -q set wireless.$dev.mu_beamformer='1'
			uci -q set wireless.$dev.he_su_beamformer='1'
			uci -q set wireless.$dev.he_mu_beamformer='1'
			uci -q set wireless.$dev.su_beamformee='1'
			uci -q set wireless.$dev.he_su_beamformee='1'
			uci -q set wireless.$dev.he_twt_responder='0'
			uci -q set wireless.$dev.he_twt_required='0'
			uci -q set wireless.$iface.ssid="${BASE_SSID}_5G"
			uci -q set wireless.$iface.encryption='psk2+ccmp'
			uci -q set wireless.$iface.key="${BASE_WORD}"
			uci -q set wireless.$iface.disassoc_low_ack='0'
			uci -q set wireless.$iface.uapsd='0'
			uci -q set wireless.$iface.ieee80211k='1'
			uci -q set wireless.$iface.ieee80211v='1'
			uci -q set wireless.$iface.bss_transition='1'
			uci -q set wireless.$iface.disabled='0'
		fi
	done
	uci -q commit wireless
	uci -q set dhcp.@dnsmasq[0].cachesize='1024'
	uci -q commit dhcp
	;;
*)
	# 通用 qualcommax 设备的国家码规范统一为 US (避免 ath11k 固件 -22 错误)
	for dev in $(uci -q show wireless | grep -oE "wireless\.radio[0-9]+" | sort -u | cut -d. -f2); do
		[ "$(uci -q get wireless.$dev.country)" = "CN" ] && uci -q set wireless.$dev.country='US'
	done
	uci -q commit wireless
	uci -q set dhcp.@dnsmasq[0].cachesize='1024'
	uci -q commit dhcp
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

#固化 TCP 长连接与保活超时配置 (系统级 sysctl.conf)
SYSCTL_FILE="./package/base-files/files/etc/sysctl.conf"
mkdir -p "$(dirname "$SYSCTL_FILE")"
touch "$SYSCTL_FILE"
cat << 'EOF' >> "$SYSCTL_FILE"

# ==========================================
# Optimized TCP Keepalive & Long Connections
# ==========================================
net.ipv4.tcp_keepalive_time=120
net.ipv4.tcp_keepalive_intvl=15
net.ipv4.tcp_keepalive_probes=4
net.ipv4.tcp_fin_timeout=30
net.netfilter.nf_conntrack_tcp_timeout_established=7200
net.netfilter.nf_conntrack_tcp_timeout_close_wait=60
net.netfilter.nf_conntrack_tcp_timeout_fin_wait=30
net.netfilter.nf_conntrack_tcp_timeout_time_wait=30
# 固化默认 TCP 拥塞控制为 BBR (随 74-tcp-bbr 模块加载后自动生效)
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq_codel
EOF

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

#预置Clashoo默认开启QUIC阻断，杜绝浏览器在透明代理下因QUIC丢包引发协议错误或降级等待卡顿
CLASHOO_DEF="./package/base-files/files/etc/uci-defaults/995_set-clashoo.sh"
mkdir -p "$(dirname "$CLASHOO_DEF")"
cat << 'EOF' > "$CLASHOO_DEF"
#!/bin/sh
# SPDX-License-Identifier: MIT
# 默认开启 Clashoo 的 block_quic，防止浏览器在透明代理下报网络协议错误或降级超时卡顿

if [ -f /etc/config/clashoo ]; then
	uci -q set clashoo.config.block_quic='1'
	uci -q commit clashoo
fi
exit 0
EOF
chmod +x "$CLASHOO_DEF"

#预置HomeProxy规则源为OpWrtCI，优化国内DNS为低延迟UDP，放行国内直连QUIC
HP_CIDR_DEF="./package/base-files/files/etc/uci-defaults/996_set-homeproxy-ruleset.sh"
mkdir -p "$(dirname "$HP_CIDR_DEF")"
cat << 'EOF' > "$HP_CIDR_DEF"
#!/bin/sh
# SPDX-License-Identifier: MIT
# 预置规则源为 opwrtci，直连国内 DNS 采用极速 UDP 223.5.5.5，仅拦截代理出站 QUIC 解绑国内大带宽直连

if [ -f /etc/config/homeproxy ]; then
	uci -q set homeproxy.config=homeproxy
	uci -q set homeproxy.config.ruleset_provider='opwrtci'
	uci -q set homeproxy.config.dns_server='tcp://8.8.8.8'
	uci -q set homeproxy.config.china_dns_server='223.5.5.5'
	uci -q set homeproxy.config.kernel_block_quic='1'
	uci -q set homeproxy.config.block_proxy_quic='0'
	uci -q commit homeproxy
fi
exit 0
EOF
chmod +x "$HP_CIDR_DEF"

#增补网络与无线高敏性能优化脚本（LAN IGMP Snooping、Wi-Fi U-APSD 节能与组播转单播）
SYS_NET_DEF="./package/base-files/files/etc/uci-defaults/997_optimize-network-wireless.sh"
mkdir -p "$(dirname "$SYS_NET_DEF")"
cat << 'EOF' > "$SYS_NET_DEF"
#!/bin/sh
# SPDX-License-Identifier: MIT
# 启用 LAN IGMP Snooping 防广播风暴，开启 Wi-Fi U-APSD 节能与组播单播化提速

if [ -f /etc/config/network ]; then
	uci -q set network.lan.igmp_snooping='1'
	uci -q commit network
fi

if [ -f /etc/config/wireless ]; then
	for iface in $(uci -q show wireless | grep '=wifi-iface' | cut -d'.' -f2 | cut -d'=' -f1); do
		uci -q set wireless.${iface}.multicast_to_unicast='1'
		uci -q set wireless.${iface}.uapsd='1'
	done
	uci -q commit wireless
fi
exit 0
EOF
chmod +x "$SYS_NET_DEF"

#预置docker用户组，消除dockerd启动时group docker not found警告
GROUP_FILE="./package/base-files/files/etc/group"
if [ -f "$GROUP_FILE" ]; then
	grep -q "^docker:" "$GROUP_FILE" || echo "docker:x:1000:docker" >> "$GROUP_FILE"
fi

#部署全量抓包与 Sing-Box 实时决策流排障取证系统 (CapCtl)
CAPCTL_SRC_DIR="$GITHUB_WORKSPACE/Scripts/capctl"
[ -d "$CAPCTL_SRC_DIR" ] || CAPCTL_SRC_DIR="$(dirname "$0")/capctl"
if [ -d "$CAPCTL_SRC_DIR" ]; then
	echo "-> Deploying CapCtl suite to package/base-files/files/..."
	mkdir -p ./package/base-files/files/usr/bin
	mkdir -p ./package/base-files/files/usr/lib/capctl
	mkdir -p ./package/base-files/files/etc/profile.d

	cp -f "$CAPCTL_SRC_DIR/capctl" ./package/base-files/files/usr/bin/
	cp -f "$CAPCTL_SRC_DIR/capctl-rotate" ./package/base-files/files/usr/lib/capctl/
	cp -f "$CAPCTL_SRC_DIR/capctl-singbox" ./package/base-files/files/usr/lib/capctl/
	cp -f "$CAPCTL_SRC_DIR/capctl-rotate-singbox" ./package/base-files/files/usr/lib/capctl/
	cp -f "$CAPCTL_SRC_DIR/99-capctl-alert.sh" ./package/base-files/files/etc/profile.d/

	chmod +x ./package/base-files/files/usr/bin/capctl*
	chmod +x ./package/base-files/files/usr/lib/capctl/*
	chmod +x ./package/base-files/files/etc/profile.d/99-capctl-alert.sh

	# 统一命令入口: capctl 与超短别名 cap
	ln -sf capctl ./package/base-files/files/usr/bin/cap
	echo "   [OK] CapCtl suite deployed successfully."
fi

# 固件升级时自动保留 HomeProxy 自定义分流规则与 CapCtl 密钥凭据
SYSUPGRADE_FILE="./package/base-files/files/etc/sysupgrade.conf"
mkdir -p "$(dirname "$SYSUPGRADE_FILE")"
touch "$SYSUPGRADE_FILE"
grep -q "/etc/homeproxy/diversion/" "$SYSUPGRADE_FILE" || echo "/etc/homeproxy/diversion/" >> "$SYSUPGRADE_FILE"
grep -q "/etc/capctl/" "$SYSUPGRADE_FILE" || echo "/etc/capctl/" >> "$SYSUPGRADE_FILE"

# 预置 HomeProxy 最新代理与直连规则（即使全新刷机不保留配置也能开箱即用）
HP_DIVERSION_DIR="./package/base-files/files/etc/homeproxy/diversion"
mkdir -p "$HP_DIVERSION_DIR"
curl -fsSL -m 15 https://raw.githubusercontent.com/opwrtci/meta-rules-dat/master/resouces/proxy.txt -o "$HP_DIVERSION_DIR/proxy.txt" 2>/dev/null || true
curl -fsSL -m 15 https://raw.githubusercontent.com/opwrtci/meta-rules-dat/master/resouces/direct.txt -o "$HP_DIVERSION_DIR/direct.txt" 2>/dev/null || true

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

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "$WRT_WIFI" == "WIFI-NO" ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
