# CLFS for LoongArch
如何交叉编译一个基于LoongArch架构的LFS（Linux From Scratch）系统。

[更新说明](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/ChangeLog.md)


[CLFS_For_LoongArch64 2025.2 文档](https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/CLFS_For_LoongArch64.md)

对应的CLFS系统：
  
  [CLFS for LoongArch64 2025.2 boot 压缩包]

  [CLFS for LoongArch64 2025.2 sysroot 压缩包]

附加包：


以下交叉工具连均默认带gcc编译器。

　　交叉工具链（精简版，不带任何库文件）：[loongarch64-clfs-2025.2-cross-tools-c-only]
  
　　交叉工具链（仅带glibc库支持）：[loongarch64-clfs-2025.2-cross-tools-gcc-glibc]
  
　　交叉工具链（带有对应CLFS系统全部库文件）：[loongarch64-clfs-2025.2-cross-tools-gcc-full]
