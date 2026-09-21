#!/bin/bash
# ==============================================================================
# OpenWRT-CI Custom Verified Patches (独立特化外挂补丁)
# 与上游标杆仓库 (VIKINGYFY/OpenWRT-CI) 代码结构物理隔离，合并上游时绝不被覆盖
# 遵循规范：.agents/AGENTS.md Rule 14 标杆仓库对照与实测验证方案双向保留原则
# ==============================================================================
set -e

[ -n "$PKG_PATH" ] || PKG_PATH="$GITHUB_WORKSPACE/wrt/package"
[ -d "$PKG_PATH" ] || PKG_PATH="$(pwd)"

echo "=== [Custom Patches] Applying project verified patches ==="

# ------------------------------------------------------------------------------
# 1. HomeProxy 核心修复
#    - 计划任务去重修补 (防止重复写入更新定时任务)
#    - 延迟测速探针：避免 Cloudflare Worker 回环死锁 (cp.cloudflare.com -> google.com)
#    - 延迟测速探针：注入 default_mark: 8228 穿透 TUN 网卡，杜绝“代理套代理”双重回环死锁
#    - 延迟测速探针：去掉 curl -f 阻断参数，保留真实状态码，避免将 503 探测失败误判为超时
# ------------------------------------------------------------------------------
HP_DIR="$(find "$PKG_PATH" -maxdepth 3 -type d -iname '*homeproxy*' -print -quit 2>/dev/null)"
if [ -n "$HP_DIR" ]; then
	echo "-> Patching HomeProxy in $HP_DIR"

	if [ -f "$HP_DIR/root/etc/init.d/homeproxy" ]; then
		sed -i 's|sed "/\[\[:space:\]\]\${CRON_TAG}\[\[:space:\]\]\*\$/d"|sed "/\${CRON_TAG}/d"|g' "$HP_DIR/root/etc/init.d/homeproxy"
		echo "   [OK] HomeProxy crontab deduplication patched."
	fi

	if [ -f "$HP_DIR/root/usr/share/rpcd/ucode/luci.homeproxy" ]; then
		# 探针防 CF 回环死锁
		sed -i 's|cp.cloudflare.com%2Fgenerate_204|www.google.com%2Fgenerate_204|g' "$HP_DIR/root/usr/share/rpcd/ucode/luci.homeproxy"
		# 探针注入 default_mark: 8228 穿透 TUN 规则 (若未注入则追加)
		if ! grep -q "default_mark: 8228" "$HP_DIR/root/usr/share/rpcd/ucode/luci.homeproxy"; then
			sed -i "/auto_detect_interface: true,/a \\\t\t\t\t\t\tdefault_mark: 8228," "$HP_DIR/root/usr/share/rpcd/ucode/luci.homeproxy"
		fi
		# 探针 curl 取消 -f 避免吞错误码
		sed -i 's|/usr/bin/curl -fsS|/usr/bin/curl -sS|g' "$HP_DIR/root/usr/share/rpcd/ucode/luci.homeproxy"
		echo "   [OK] HomeProxy latency probe anti-loopback & TUN penetration patched."
	fi
fi

echo "=== [Custom Patches] All custom verified patches applied successfully! ==="
