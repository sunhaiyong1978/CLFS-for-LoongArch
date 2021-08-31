##### 20210831
- 重新获取工具链代码，并重构整个系统
- 去掉"-march=loongarch"制作参数，工具链默认探测架构进行设置。
- 更新以下软件包：  
  Binutils  
  Diffutils  
  GCC  
  Glibc  
  Grep  
  Libcap  
  Linux-Firmware  
  M4  
  OpenSSL  
  ACPI-Update

- 增加以下软件包和制作步骤：  
  Boost  
  Ctags  
  Ethtool  
  Fontconfig  
  Freetype  
  Fribidi  
  Glibmm  
  GnuTLS  
  Gobject-Introspection  
  Harfbuzz  
  Jasper  
  Lcms  
  Libaio  
  Libcap  
  Libgudev  
  Libgusb  
  Libjpeg-Turbo  
  Libmng  
  Libnl  
  Libpng  
  LibRaw  
  Libsigc++  
  Libtasn1  
  Libusb  
  Libunistring  
  LVM2  
  Mdadm  
  Nettle  
  OpenJPEG  
  P11-Kit  
  TIFF  
  Usbutils  
  Vala  
  Wireless-Tools  
  Wpa_Supplicant  

- 增加系统第一次使用时需要执行的命令步骤

##### 20210822
- 增加CMake软件包的制作步骤
- 增加CURL软件包的制作步骤
- 增加Dosfstools软件包的制作步骤
- 增加Doxygen软件包的制作步骤
- 增加Git软件包的制作步骤
- 增加Glib软件包的制作步骤
- 增加ICU4C软件包的制作步骤
- 增加Inih软件包的制作步骤
- 增加Libxml2软件包的制作步骤
- 增加Libxslt软件包的制作步骤
- 增加Meson软件包的制作步骤
- 增加NSPR软件包的制作步骤
- 增加NSS软件包的制作步骤
- 增加PCRE软件包的制作步骤
- 增加Python-Pip软件包的制作步骤
- 增加Python-Setuptools软件包的制作步骤
- 增加Sqlite3软件包的制作步骤
- 增加Sudo软件包的制作步骤
- 增加Xfsprogs软件包的制作步骤
- 增加UnRAR软件包的制作步骤
- 增加UnZip软件包的制作步骤
- 增加Zip软件包的制作步骤

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
