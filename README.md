# CLFS for LoongArch
如何交叉编译一个基于LoongArch架构的LFS（Linux From Scratch）系统。

[更新说明](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/ChangeLog.md)


[CLFS_For_LoongArch64 8.0 文档](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/CLFS_For_LoongArch64.md)

对应的CLFS系统：
  
  [CLFS for LoongArch64 8.0 boot 压缩包](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/8.0/loongarch64-clfs-system-8.0-boot.tar.xz)

  [CLFS for LoongArch64 8.0 sysroot 压缩包](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/8.0/loongarch64-clfs-system-8.0-sysroot.tar.xz)

附加包：

　　LightDM桌面登录管理器：[loongarch64-clfs-system-8.0-lightdm](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/8.0/loongarch64-clfs-system-8.0-lightdm.tar.xz)

　　LXDE桌面环境：[loongarch64-clfs-system-8.0-LXDE](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/8.0/loongarch64-clfs-system-8.0-lxde.tar.xz)

　　桌面应用：[loongarch64-clfs-system-8.0-Desktop_APP](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/8.0/loongarch64-clfs-system-8.0-desk_app.tar.xz)


以下交叉工具连均默认带gcc编译器。

　　交叉工具链（精简版，不带任何库文件）：[loongarch64-clfs-8.0-cross-tools-c-only](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/8.0/loongarch64-clfs-8.0-cross-tools-c-only.tar.xz)
  
　　交叉工具链（仅带glibc库支持）：[loongarch64-clfs-8.0-cross-tools-gcc-glibc](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/8.0/loongarch64-clfs-8.0-cross-tools-gcc-glibc.tar.xz)
  
　　交叉工具链（带有对应CLFS系统全部库文件）：[loongarch64-clfs-8.0-cross-tools-gcc-full](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/8.0/loongarch64-clfs-8.0-cross-tools-gcc-full.tar.xz)
