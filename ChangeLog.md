##### 20210818
- 增加Python软件包的制作步骤
- 增加Perl软件包的制作步骤
- 增加XML-Parser软件包的制作步骤
- 增加GPM软件包的制作步骤
- 增加证书文件的安装步骤
- 增加Libevent软件包的制作步骤
- 增加Links软件包的制作步骤

##### 20210812
- 采用20210801之后更新的Binutils和GCC作为工具链，该工具链更新了部分LA指令集
- 更新GCC的制作步骤，去掉了--with-arch和--with-tls选项
- 更新支持LoongArch的Linux内核源代码制作步骤，适合日期2021-08-21之后更新的5.14-rc5版本，支持更新后的工具链编译
- 更新GCC和Glibc生成的ld.so.1改为ld-linux-loongarch64.so.1的补丁
- 更新Grub软件包的制作步骤，支持更新后的工具链编译
- 更新Linux-Firmware软件包
- 增加ACPI-Update的制作步骤
- 增加DHCPCD软件包的制作步骤
- 增加Inetutils软件包的制作步骤
- 增加OpenSSH软件包的制作步骤
- 增加PCIUtils软件包的制作步骤
- 增加WGet软件包 的制作步骤

##### 20210801
- 采用开源的Binutils、GCC、Glibc和Linux内核制作CLFS系统。
