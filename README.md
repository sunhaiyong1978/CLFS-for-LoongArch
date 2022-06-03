# CLFS-for-LoongArch
如何交叉编译一个基于LoongArch架构的LFS（Linux From Scratch）系统。

[更新说明](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/ChangeLog.md)


[CLFS_For_LoongArch64 5.0](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/CLFS_For_LoongArch64.md)：

　　对应的CLFS系统：[loongarch64-clfs-system-5.1](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/5.0/loongarch64-clfs-system-5.1.tar.bz2)

附加包：

　　LightDM桌面登录管理器：[loongarch64-clfs-system-5.0-lightdm](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/5.0/loongarch64-clfs-system-5.0-lightdm.tar.bz2)

　　LXDE桌面环境：[loongarch64-clfs-system-5.0-WM-LXDE](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/5.0/loongarch64-clfs-system-5.0-WM-LXDE.tar.bz2)

　　KDE桌面环境：[loongarch64-clfs-system-5.0-WM-KDE](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/5.0/loongarch64-clfs-system-5.1-WM-KDE.tar.bz2)



以下交叉工具连均默认带gcc编译器。

　　交叉工具链（精简版，不带任何库文件）：[loongarch64-clfs-5.0-cross-tools-c-only](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/5.0/loongarch64-clfs-5.0-cross-tools-c-only.tar.xz)
  
　　交叉工具链（仅带glibc库支持）：[loongarch64-clfs-5.0-cross-tools-gcc-glibc](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/5.0/loongarch64-clfs-5.0-cross-tools-gcc-glibc.tar.xz)
  
　　交叉工具链（带有对应CLFS系统全部库文件）：[loongarch64-clfs-5.0-cross-tools-gcc-full](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/5.0/loongarch64-clfs-5.0-cross-tools-gcc-full.tar.xz)
  
　　交叉工具链（带有clang编译器且带有对应CLFS系统全部库文件）：[loongarch64-clfs-5.0-cross-tools-gcc_clang-full](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/5.0/loongarch64-clfs-5.0-cross-tools-gcc_and_clang-full.tar.xz)
