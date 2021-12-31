﻿# <center>Use QEMU to run a Linux system based on the LoongArch64 architecture (simplified version)</center>

<center>(Qemu For LoongArch64 Simple)</center>  

<center>Author: Sun Haiyong</center>
<center>Translator: Andrii Kurdiumov</center>

## 1 Introduction
    This article is a simplified version of the [Qemu_For_LoongArch64.md](Qemu_For_LoongArch64_en.md) document.

    The purpose of this article is to explain how to use QEMU for running a Linux system based on LoongArch64 through a simple operation.

## 2 Environmental preparation
### Prepare the Linux system
    Please prepare a general Linux environment, such as Fedora, Debian, etc.

### Download QEMU
    Download QEMU that can support LoongArch architecture in Linux environment:

    If your machine is an x86-64 system, then use this download link:

https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/qemu-x86_64-to-loongarch64

    If you happen to have a Loongson 3A 4000 machine, you can use this download link:

https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/qemu-mips64el-to-loongarch64

Please rename the downloaded file to qemu-loongarch64 and store it in the /bin directory. For example, use the command for x86-64 files:

```sh
cp qemu-x86_64-to-loongarch64 /bin/qemu-loongarch64
```

#### Download LoongArch Linux system
    There is already pre-made LoongArch Linux system on GitHub, use the following steps to download from given address:  

```sh
cd /tmp
wget -c https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/loongarch64-clfs-system-20210903.tar.bz2
```

    The system downloaded above is a Linux system based on the LoongArch instruction set architecture constructed entirely using open source code.


#### Unzip LoongArch Linux system
    Please use the root user to complete the following decompression steps:

```sh
cd /opt
mkdir clfs-os
cd clfs-os
tar xvpf /tmp/loongarch64-clfs-system-20210903.tar.bz2
```
    After a period of decompression, we have a system based on the LoongArch instruction set in the /opt/clfs-os directory.

## 3 Use QEMU

    The next step is to register the LoongArch executable file information in Binfmt, use the following command:

```sh
echo ":qemu-loongarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x02\x01:\xff\xff\ xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/bin/qemu-loongarch64:"> /proc/sys/ fs/binfmt_misc/register
```

    The above command registers the "header information" of the LoongArch executable file, and specifies that the qualified files will be executed using the "/bin/qemu-loongarch64" command, so this "/bin/qemu-loongarch64" command must be true and effective.

    If you want to know what Binfmt is, you can search on the Internet by yourself, or look at the brief description of the documents mentioned in the preface.

#### Chroot to LoongArch system
    In order to conveniently chroot to the LoongArch system through the Linux user-mode of QEMU, the registration of the Binfmt function is essential. After the registration is completed, the following one-time steps are required:

```sh
cp /bin/qemu-loongarch64 /opt/clfs-os/bin/
```

    We copy the executable file qemu-loongarch64 to the system that needs chroot. This step is very critical, and we must ensure that the relative location of qemu-loongarch64 stored in the chroot system is the same as the directory location of the executable in the current system, so put it in the bin directory.

    Next, when we witness the victory, use a root user or sudo command to chroot:

```sh
chroot /opt/clfs-os
```
    At this time we will see the familiar Bash prompt:

    bash-5.1#

    Try to enter some commands, such as ls, vi, you will find that you can run them directly.

    Then enter:  

```sh
uname -m
```  
    Will return: 

    loongarch

    It represents the architecture of LoongArch being simulated in the current environment.

    Next you can refer to: [Qemu_For_LoongArch64.md](Qemu_For_LoongArch64_en.md) for the usage part in the document.

## Finish

    Thank you for your support and welcome your valuable comments.
