#!/bin/bash

./scripts/feeds update -a
./scripts/feeds install -a

# 移除 SNAPSHOT 标签
sed -i 's,-SNAPSHOT,,g' include/version.mk
sed -i 's,-SNAPSHOT,,g' package/base-files/image-config.in
# 维多利亚的秘密
#rm -rf ./scripts/download.pl
#rm -rf ./include/download.mk
#cp -rf ../immortalwrt/scripts/download.pl ./scripts/download.pl
#cp -rf ../immortalwrt/include/download.mk ./include/download.mk
#sed -i '/unshift/d' scripts/download.pl
#sed -i '/mirror02/d' scripts/download.pl
echo "net.netfilter.nf_conntrack_helper = 1" >>./package/kernel/linux/files/sysctl-nf-conntrack.conf
# Nginx
sed -i "s/large_client_header_buffers 2 1k/large_client_header_buffers 4 32k/g" feeds/packages/net/nginx-util/files/uci.conf.template
sed -i "s/client_max_body_size 128M/client_max_body_size 2048M/g" feeds/packages/net/nginx-util/files/uci.conf.template
sed -i '/client_max_body_size/a\\tclient_body_buffer_size 8192M;' feeds/packages/net/nginx-util/files/uci.conf.template
sed -i '/client_max_body_size/a\\tserver_names_hash_bucket_size 128;' feeds/packages/net/nginx-util/files/uci.conf.template
sed -i '/ubus_parallel_req/a\        ubus_script_timeout 600;' feeds/packages/net/nginx/files-luci-support/60_nginx-luci-support
sed -ri "/luci-webui.socket/i\ \t\tuwsgi_send_timeout 600\;\n\t\tuwsgi_connect_timeout 600\;\n\t\tuwsgi_read_timeout 600\;" feeds/packages/net/nginx/files-luci-support/luci.locations
sed -ri "/luci-cgi_io.socket/i\ \t\tuwsgi_send_timeout 600\;\n\t\tuwsgi_connect_timeout 600\;\n\t\tuwsgi_read_timeout 600\;" feeds/packages/net/nginx/files-luci-support/luci.locations

### 必要的 Patches ###
# SSL
rm -rf ./package/libs/mbedtls
cp -rf ../immortalwrt/package/libs/mbedtls ./package/libs/mbedtls
#rm -rf ./package/libs/openssl
#cp -rf ../immortalwrt_21/package/libs/openssl ./package/libs/openssl
# fstool
wget -qO - https://github.com/coolsnowwolf/lede/commit/8a4db76.patch | patch -p1

### Fullcone-NAT 部分 ###
# Patch Kernel 以解决 FullCone 冲突
cp -rf ../lede/target/linux/generic/hack-5.15/952-add-net-conntrack-events-support-multiple-registrant.patch ./target/linux/generic/hack-5.15/952-add-net-conntrack-events-support-multiple-registrant.patch
cp -rf ../lede/target/linux/generic/hack-5.15/982-add-bcm-fullconenat-support.patch ./target/linux/generic/hack-5.15/982-add-bcm-fullconenat-support.patch
# Patch FireWall 以增添 FullCone 功能
# FW4
mkdir -p package/network/config/firewall4/patches
cp -f ../patch/firewall/001-fix-fw4-flow-offload.patch ./package/network/config/firewall4/patches/001-fix-fw4-flow-offload.patch
cp -f ../patch/firewall/990-unconditionally-allow-ct-status-dnat.patch ./package/network/config/firewall4/patches/990-unconditionally-allow-ct-status-dnat.patch
cp -f ../patch/firewall/999-01-firewall4-add-fullcone-support.patch ./package/network/config/firewall4/patches/999-01-firewall4-add-fullcone-support.patch
mkdir -p package/libs/libnftnl/patches
cp -f ../patch/firewall/libnftnl/001-libnftnl-add-fullcone-expression-support.patch ./package/libs/libnftnl/patches/001-libnftnl-add-fullcone-expression-support.patch
sed -i '/PKG_INSTALL:=/iPKG_FIXUP:=autoreconf' package/libs/libnftnl/Makefile
mkdir -p package/network/utils/nftables/patches
cp -f ../patch/firewall/nftables/002-nftables-add-fullcone-expression-support.patch ./package/network/utils/nftables/patches/002-nftables-add-fullcone-expression-support.patch
# iptables
cp -rf ../lede/package/network/utils/iptables/patches/900-bcm-fullconenat.patch ./package/network/utils/iptables/patches/900-bcm-fullconenat.patch
# network
wget -qO - https://github.com/openwrt/openwrt/commit/bbf39d07.patch | patch -p1
# Patch LuCI 以增添 FullCone 开关
pushd feeds/luci
patch -p1 <../../../patch/firewall/luci-app-firewall_add_fullcone_fw4.patch
popd
# FullCone PKG
git clone --depth 1 https://github.com/fullcone-nat-nftables/nft-fullcone package/new/nft-fullcone
cp -rf ../Lienol/package/network/utils/fullconenat ./package/new/fullconenat

### 获取额外的 LuCI 应用、主题和依赖 ###
# mount cgroupv2
pushd feeds/packages
patch -p1 <../../../patch/cgroupfs-mount/0001-fix-cgroupfs-mount.patch
popd
mkdir -p feeds/packages/utils/cgroupfs-mount/patches
cp -rf ../patch/cgroupfs-mount/900-mount-cgroup-v2-hierarchy-to-sys-fs-cgroup-cgroup2.patch ./feeds/packages/utils/cgroupfs-mount/patches/
cp -rf ../patch/cgroupfs-mount/901-fix-cgroupfs-umount.patch ./feeds/packages/utils/cgroupfs-mount/patches/
cp -rf ../patch/cgroupfs-mount/902-mount-sys-fs-cgroup-systemd-for-docker-systemd-suppo.patch ./feeds/packages/utils/cgroupfs-mount/patches/
# AutoCore
cp -rf ../immortalwrt_23/package/emortal/autocore ./package/new/autocore
sed -i 's/"getTempInfo" /"getTempInfo", "getCPUBench", "getCPUUsage" /g' package/new/autocore/files/luci-mod-status-autocore.json
cp -rf ../OpenWrt-Add/autocore/files/x86/autocore ./package/new/autocore/files/autocore
sed -i '/i386 i686 x86_64/{n;n;n;d;}' package/new/autocore/Makefile
sed -i '/i386 i686 x86_64/d' package/new/autocore/Makefile
rm -rf ./feeds/luci/modules/luci-base
cp -rf ../immortalwrt_luci_23/modules/luci-base ./feeds/luci/modules/luci-base
sed -i "s,(br-lan),,g" feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci
rm -rf ./feeds/luci/modules/luci-mod-status
cp -rf ../immortalwrt_luci_23/modules/luci-mod-status ./feeds/luci/modules/luci-mod-status
rm -rf ./feeds/packages/utils/coremark
cp -rf ../immortalwrt_pkg/utils/coremark ./feeds/packages/utils/coremark
sed -i "s,-O3,-Ofast -funroll-loops -fpeel-loops -fgcse-sm -fgcse-las,g" feeds/packages/utils/coremark/Makefile
cp -rf ../immortalwrt_23/package/utils/mhz ./package/utils/mhz
# igc-fix
cp -rf ../lede/target/linux/x86/patches-5.15/996-intel-igc-i225-i226-disable-eee.patch ./target/linux/x86/patches-5.15/996-intel-igc-i225-i226-disable-eee.patch
# UPX 可执行软件压缩
sed -i '/patchelf pkgconf/i\tools-y += ucl upx' ./tools/Makefile
sed -i '\/autoconf\/compile :=/i\$(curdir)/upx/compile := $(curdir)/ucl/compile' ./tools/Makefile
cp -rf ../Lienol/tools/ucl ./tools/ucl
cp -rf ../Lienol/tools/upx ./tools/upx
# 更换 golang 版本
rm -rf ./feeds/packages/lang/golang
cp -rf ../openwrt_pkg_ma/lang/golang ./feeds/packages/lang/golang
# MAC 地址与 IP 绑定
cp -rf ../immortalwrt_luci/applications/luci-app-arpbind ./feeds/luci/applications/luci-app-arpbind
ln -sf ../../../feeds/luci/applications/luci-app-arpbind ./package/feeds/luci/luci-app-arpbind
# 定时重启
cp -rf ../immortalwrt_luci/applications/luci-app-autoreboot ./feeds/luci/applications/luci-app-autoreboot
ln -sf ../../../feeds/luci/applications/luci-app-autoreboot ./package/feeds/luci/luci-app-autoreboot
# Boost 通用即插即用
rm -rf ./feeds/packages/net/miniupnpd
cp -rf ../openwrt_pkg_ma/net/miniupnpd ./feeds/packages/net/miniupnpd
pushd feeds/packages
patch -p1 <../../../patch/miniupnpd/01-set-presentation_url.patch
patch -p1 <../../../patch/miniupnpd/02-force_forwarding.patch
patch -p1 <../../../patch/miniupnpd/03-Update-301-options-force_forwarding-support.patch.patch
popd
pushd feeds/luci
wget -qO- https://github.com/openwrt/luci/commit/0b5fb915.patch | patch -p1
popd
# ChinaDNS
git clone -b luci --depth 1 https://github.com/QiuSimons/openwrt-chinadns-ng.git package/new/luci-app-chinadns-ng
cp -rf ../passwall_pkg/chinadns-ng ./package/new/chinadns-ng
# Docker 容器
rm -rf ./feeds/luci/applications/luci-app-dockerman
cp -rf ../dockerman/applications/luci-app-dockerman ./feeds/luci/applications/luci-app-dockerman
sed -i '/auto_start/d' feeds/luci/applications/luci-app-dockerman/root/etc/uci-defaults/luci-app-dockerman
pushd feeds/packages
wget -qO- https://github.com/openwrt/packages/commit/e2e5ee69.patch | patch -p1
wget -qO- https://github.com/openwrt/packages/pull/20054.patch | patch -p1
popd
sed -i '/sysctl.d/d' feeds/packages/utils/dockerd/Makefile
rm -rf ./feeds/luci/collections/luci-lib-docker
cp -rf ../docker_lib/collections/luci-lib-docker ./feeds/luci/collections/luci-lib-docker
# DiskMan
cp -rf ../diskman/applications/luci-app-diskman ./package/new/luci-app-diskman
mkdir -p package/new/parted && \
wget https://raw.githubusercontent.com/lisaac/luci-app-diskman/master/Parted.Makefile -O package/new/parted/Makefile
# Dnsfilter
git clone --depth 1 https://github.com/kiddin9/luci-app-dnsfilter.git package/new/luci-app-dnsfilter
# Dnsproxy
cp -rf ../OpenWrt-Add/luci-app-dnsproxy ./package/new/luci-app-dnsproxy
# FRP 内网穿透
rm -rf ./feeds/luci/applications/luci-app-frps
rm -rf ./feeds/luci/applications/luci-app-frpc
rm -rf ./feeds/packages/net/frp
cp -rf ../immortalwrt_pkg/net/frp ./feeds/packages/net/frp
sed -i '/etc/d' feeds/packages/net/frp/Makefile
sed -i '/defaults/{N;d;}' feeds/packages/net/frp/Makefile
cp -rf ../lede_luci/applications/luci-app-frps ./package/new/luci-app-frps
cp -rf ../lede_luci/applications/luci-app-frpc ./package/new/luci-app-frpc
sed -i '/luci.mk/c\include $(TOPDIR)/feeds/luci/luci.mk' ./package/new/luci-app-frps/Makefile
sed -i '/luci.mk/c\include $(TOPDIR)/feeds/luci/luci.mk' ./package/new/luci-app-frpc/Makefile
# IPv6 兼容助手
cp -rf ../lede/package/lean/ipv6-helper ./package/new/ipv6-helper
patch -p1 <../patch/odhcp6c/1002-odhcp6c-support-dhcpv6-hotplug.patch
# ODHCPD
mkdir -p package/network/services/odhcpd/patches
cp -f ../patch/odhcpd/0001-config-allow-configuring-max-limit-for-preferred-and.patch ./package/network/services/odhcpd/patches/0001-config-allow-configuring-max-limit-for-preferred-and.patch
# Luci app amlogic
git clone --depth 1 https://github.com/ophub/luci-app-amlogic.git ./package/new/luci-app-amlogic
# Mosdns
cp -rf ../mosdns/mosdns ./package/mosdns
cp -rf ../mosdns/luci-app-mosdns ./package/luci-app-mosdns
rm -rf ./feeds/packages/net/v2ray-geodata
cp -rf ../mosdns/v2ray-geodata ./package/v2ray-geodata
# homeproxy
git clone --single-branch --depth 1 -b dev https://github.com/immortalwrt/homeproxy.git ./package/new/luci-app-homeproxy
rm -rf ./feeds/packages/net/sing-box
cp -rf ../immortalwrt_pkg/net/sing-box ./feeds/packages/net/sing-box
# OpenClash
git clone --single-branch --depth 1 -b master https://github.com/vernesong/OpenClash.git ./package/new/luci-app-openclash
# Passwall
cp -rf ../passwall_luci/luci-app-passwall ./package/new/luci-app-passwall
wget -P package/new/luci-app-passwall/ https://github.com/QiuSimons/OpenWrt-Add/raw/master/move_2_services.sh
chmod -R 755 ./package/new/luci-app-passwall/move_2_services.sh
pushd package/new/luci-app-passwall
bash move_2_services.sh
popd
cp -rf ../passwall_pkg ./package/new/passwall_pkg
# Passwall 白名单
echo '
teamviewer.com
epicgames.com
dangdang.com
account.synology.com
ddns.synology.com
checkip.synology.com
checkip.dyndns.org
checkipv6.synology.com
ntp.aliyun.com
cn.ntp.org.cn
ntp.ntsc.ac.cn
' >>./package/new/luci-app-passwall/root/usr/share/passwall/rules/direct_host
# 清理内存
cp -rf ../lede_luci/applications/luci-app-ramfree ./package/new/luci-app-ramfree
sed -i '/luci.mk/c\include $(TOPDIR)/feeds/luci/luci.mk' ./package/new/luci-app-ramfree/Makefile
# 订阅转换
cp -rf ../immortalwrt_pkg/net/subconverter ./feeds/packages/net/subconverter
ln -sf ../../../feeds/packages/net/subconverter ./package/feeds/packages/subconverter
cp -rf ../immortalwrt_pkg/libs/jpcre2 ./feeds/packages/libs/jpcre2
ln -sf ../../../feeds/packages/libs/jpcre2 ./package/feeds/packages/jpcre2
cp -rf ../immortalwrt_pkg/libs/rapidjson ./feeds/packages/libs/rapidjson
ln -sf ../../../feeds/packages/libs/rapidjson ./package/feeds/packages/rapidjson
cp -rf ../immortalwrt_pkg/libs/libcron ./feeds/packages/libs/libcron
ln -sf ../../../feeds/packages/libs/libcron ./package/feeds/packages/libcron
cp -rf ../immortalwrt_pkg/libs/quickjspp ./feeds/packages/libs/quickjspp
ln -sf ../../../feeds/packages/libs/quickjspp ./package/feeds/packages/quickjspp
cp -rf ../immortalwrt_pkg/libs/toml11 ./feeds/packages/libs/toml11
ln -sf ../../../feeds/packages/libs/toml11 ./package/feeds/packages/toml11
# uwsgi
sed -i 's,procd_set_param stderr 1,procd_set_param stderr 0,g' feeds/packages/net/uwsgi/files/uwsgi.init
sed -i 's,buffer-size = 10000,buffer-size = 131072,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's,logger = luci,#logger = luci,g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i '$a cgi-timeout = 600' feeds/packages/net/uwsgi/files-luci-support/luci-*.ini
sed -i 's/threads = 1/threads = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/processes = 3/processes = 4/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
sed -i 's/cheaper = 1/cheaper = 2/g' feeds/packages/net/uwsgi/files-luci-support/luci-webui.ini
# rpcd
sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config
sed -i 's#20) \* 1000#60) \* 1000#g' feeds/luci/modules/luci-base/htdocs/luci-static/resources/rpc.js
# KMS 激活助手
cp -rf ../lede_luci/applications/luci-app-vlmcsd ./package/new/luci-app-vlmcsd
sed -i '/luci.mk/c\include $(TOPDIR)/feeds/luci/luci.mk' ./package/new/luci-app-vlmcsd/Makefile
cp -rf ../lede_pkg/net/vlmcsd ./package/new/vlmcsd
# Vsftpd
# cp -rf ../lede_luci/applications/luci-app-vsftpd ./package/new/luci-app-vsftpd
# sed -i '/luci.mk/c\include $(TOPDIR)/feeds/luci/luci.mk' ./package/new/luci-app-vsftpd/Makefile
# cp -rf ../lede_pkg/net/vsftpd ./package/net/vsftpd
# Filebrowser 文件浏览器
cp -rf ../Lienol_pkg/luci-app-filebrowser ./package/new/luci-app-filebrowser
# Filetransfer
# cp -rf ../lede_luci/applications/luci-app-filetransfer ./package/new/luci-app-filetransfer
# sed -i '/luci.mk/c\include $(TOPDIR)/feeds/luci/luci.mk' ./package/new/luci-app-filetransfer/Makefile
# cp -rf ../lede_luci/libs/luci-app-fs ./package/libs/luci-app-fs
# 翻译及部分功能优化
cp -rf ../OpenWrt-Add/addition-trans-zh ./package/new/addition-trans-zh
sed -i 's,iptables-mod-fullconenat,iptables-nft +kmod-nft-fullcone,g' package/new/addition-trans-zh/Makefile

### Shortcut-FE 部分 ###
# Patch Kernel 以支持 Shortcut-FE
cp -rf ../lede/target/linux/generic/hack-5.15/953-net-patch-linux-kernel-to-support-shortcut-fe.patch ./target/linux/generic/hack-5.15/953-net-patch-linux-kernel-to-support-shortcut-fe.patch
cp -rf ../lede/target/linux/generic/pending-5.15/613-netfilter_optional_tcp_window_check.patch ./target/linux/generic/pending-5.15/613-netfilter_optional_tcp_window_check.patch
# Patch LuCI 以增添 Shortcut-FE 开关
patch -p1 < ../patch/firewall/luci-app-firewall_add_sfe_switch.patch
# Shortcut-FE 相关组件
mkdir ./package/lean
mkdir ./package/lean/shortcut-fe
cp -rf ../lede/package/lean/shortcut-fe/fast-classifier ./package/lean/shortcut-fe/fast-classifier
wget -qO - https://github.com/coolsnowwolf/lede/commit/331f04f.patch | patch -p1
wget -qO - https://github.com/coolsnowwolf/lede/commit/232b8b4.patch | patch -p1
wget -qO - https://github.com/coolsnowwolf/lede/commit/ec795c9.patch | patch -p1
wget -qO - https://github.com/coolsnowwolf/lede/commit/789f805.patch | patch -p1
wget -qO - https://github.com/coolsnowwolf/lede/commit/6398168.patch | patch -p1
cp -rf ../lede/package/lean/shortcut-fe/shortcut-fe ./package/lean/shortcut-fe/shortcut-fe
wget -qO - https://github.com/coolsnowwolf/lede/commit/0e29809.patch | patch -p1
wget -qO - https://github.com/coolsnowwolf/lede/commit/eb70dad.patch | patch -p1
wget -qO - https://github.com/coolsnowwolf/lede/commit/7ba3ec0.patch | patch -p1
cp -rf ../lede/package/lean/shortcut-fe/simulated-driver ./package/lean/shortcut-fe/simulated-driver

#LTO/GC
# Grub 2
sed -i 's,no-lto,no-lto no-gc-sections,g' package/boot/grub2/Makefile
# openssl disable LTO
sed -i 's,no-mips16 gc-sections,no-mips16 gc-sections no-lto,g' package/libs/openssl/Makefile
# nginx
sed -i 's,gc-sections,gc-sections no-lto,g' feeds/packages/net/nginx/Makefile
# libsodium
sed -i 's,no-mips16,no-mips16 no-lto,g' feeds/packages/libs/libsodium/Makefile

exit 0