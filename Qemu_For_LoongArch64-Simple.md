﻿﻿﻿﻿﻿# <center>使用QEMU运行基于LoongArch64架构的Linux系统（简化版本）</center>

<center>（Qemu For LoongArch64 Simple）</center>  

<center>作者：孙海勇</center>

## 1 前言
　　本文是 https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/Qemu_For_LoongArch64.md 文档的简化版本。

　　本文的目的是通过简单的操作使用QEMU运行一个基于LoongArch64制作的Linux系统。

## 2 环境准备
### 准备Linux系统
　　请准备一个通用Linux的环境，比如Fedora、Debian等。

### 下载QEMU
　　在Linux环境中下载可以支持LoongArch架构的QEMU：

　　机器是X86系统，下载地址：

https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/qemu-x86_64-to-loongarch64

　　如果你刚巧手上有一个龙芯3A 4000的机器，刚巧也有一个，下载地址：

https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/qemu-mips64el-to-loongarch64

请将下载的文件更名为qemu-loongarch64，并存放到/bin目录中，如X86的文件使用命令：

```sh
cp qemu-x86_64-to-loongarch64 /bin/qemu-loongarch64
```

#### 下载LoongArch的Linux系统
　　在GitHub上有已经制作好的LoongArch Linux系统，使用以下地址步骤进行下载：  

```sh
cd /tmp
wget -c https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/loongarch64-clfs-system-20210903.tar.bz2
```

　　以上下载的系统是一个完全使用已开放的源代码构建的基于LoongArch指令集架构的Linux系统。


#### 解压缩LoongArch的Linux系统
　　请使用root权限的用户完成以下解压缩的步骤：

```sh
cd /opt
mkdir clfs-os
cd clfs-os
tar xvpf /tmp/loongarch64-clfs-system-20210903.tar.bz2
```
　　经过一段时间的解压后，我们就在/opt/clfs-os目录中拥有了一个基于LoongArch指令集制作的系统。

## 3 使用QEMU

　　接下来就是在Binfmt注册LoongArch可执行文件的信息了，使用如下命令：

```sh
echo ":qemu-loongarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x02\x01:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/bin/qemu-loongarch64:" > /proc/sys/fs/binfmt_misc/register
```

　　以上命令注册了LoongArch可执行文件“头信息”，并指定符合条件的文件会使用"/bin/qemu-loongarch64"命令来执行，所以这个"/bin/qemu-loongarch64"命令必须真实有效。

　　想了解什么是Binfmt，可自行上网搜索，或者看一下前言中所提及文档的简单说明。

#### Chroot到LoongArch系统
　　要想方便的通过QEMU的Linux-User模式chroot到LoongArch的系统中，Binfmt功能的注册是必不可少的，当完成注册后还需要如下的一次性步骤：

```sh
cp /bin/qemu-loongarch64 /opt/clfs-os/bin/
```

　　我们将qemu-loongarch64这个命令文件复制到需要chroot的系统中，这个步骤非常关键，并且要保证qemu-loongarch64在这个chroot的系统中存放的相对位置与当前系统中该命令的目录位置相同，即放在bin目录下。

　　接下来，我们就是见证胜利的时候，使用root权限的用户或者sudo命令进行chroot：

```sh
chroot /opt/clfs-os
```
　　这个时候我们会看到熟悉的Bash提示符：

　　bash-5.1#

　　尝试的输入一些命令，比如ls、vi，你会发现可以完全直接就运行起来了。

　　再输入：  

```sh
uname -m
```  
　　会返回： 

　　loongarch

　　代表当前环境正模拟的LoongArch的架构。

　　接下来可以参考：https://github.com/sunhaiyong1978/CLFS-for-LoongArch/blob/main/Qemu_For_LoongArch64.md 文档中的使用部分。

## 结束

　　感谢大家支持，欢迎提出宝贵的意见。






