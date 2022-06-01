# <center>Use QEMU to run a Linux system based on the LoongArch64 architecture</center>

<center>(Qemu For LoongArch64)</center>  

<center>Author: Sun Haiyong</center>
<center>Translator: Andrii Kurdiumov</center>

## 1 Introduction
    Loongson Technology launched a new instruction set architecture LoongArch in 2021. This 64-bit instruction set is called LoongArch64.  
    The operating system based on the LoongArch64 instruction set needs to run on a machine using the Loongson 3A5000 CPU. If you need simply work without such a machine, you need to use the QEMU emulator.  
    The goal of this article is to use QEMU to run a Linux system based on LoongArch64 through a step-by-step instructions.

    **At the end of the article, there are compiled QEMU files of different architectures available for download, simplifying the use process. **  

    This article involves some operations related to compiling software. If you want simply use it, you can refer to the simplified version of the document:
    [Qemu_For_LoongArch64-Simple.md](Qemu_For_LoongArch64-Simple_en.md)

## 2 Compile QEMU

    This article will use the method of compiling the QEMU source code to create a QEMU executable. Because most of the current QEMU systems do not support LoongArch64 instruction set, the next step is to download and compile QEMU.

### Prepare the compilation environment
    QEMU supports simulating the environment of the target instruction set from different machine instruction architectures, as long as the machine used can run QEMU. Of course, we recommend installing a "normal" Linux for machine used to run QEMU. Because QEMU also needs to be compiled, so operating system must be able to provide a development environment for compiling QEMU.

    Because the Linux system that's used for building QEMU and running LoongArch64 on machines of different architectures has nothing to do with the LoongArch64 architecture itself, the main difference is only in the steps of preparing the compilation environment for the specific Linux system because of the different package management tools used by Linux. Steps are different, but there is almost no difference in using QEMU, so we will explain with an environment using Fedora Linux distribution.

    If you are using an x86 machine, there are many Linux versions to choose from, and if you are using a machine with a non-x86 architecture, you must determine the version that can be used. Next, we will use the Loongson 3A4000 machine to run it. Take Fedora28 as an example to explain how to build and use. Of course, these steps are also suitable for newer versions such as Fedora 32 on 3A4000, or Fedora 34 on x86 machines or other Linux systems.

#### Create a normal user
    It is not recommended to use the root user to compile and build the software package, so we create an ordinary user at the beginning, such as "loongson". If there is already this user in the system, you can create a user with another name or skip this step.

    The creation command is as follows:

```sh
useradd -m loongson
```

    The use of the parameter "-m" is to create a home directory for this new user, and then we will need to use the user's home directory.

    Note: User creation must be performed by a user with root privileges.

#### Switch user
    After creating a normal user, you can switch to that user and use the following command:

```sh
su loongson
```

    Switching from the root user to a normal user can avoid entering a password.

    By default, after switching users, it will automatically enter the user's home directory, and subsequent work will be carried out in the home directory.

### Download the source code of QEMU

    The code that supports LoongArch64 in QEMU has not yet entered the upstream source code repository of QEMU. Therefore, we need to download a QEMU source code that supports LoongArch64 instructions.

    Use the following command to download the QEMU code:

```sh
git clone https://github.com/gaosong-loongson/qemu.git -b tcg-dev
```

After a some time of downloading, we will have the QEMU source code that supports the LoongArch64 instruction set.


### QEMU support mode
    The next step is the most critical compilation process.

    Enter the source code directory of QEMU:

```sh
cd ~/qemu
```
    Note: It is assumed that the source code is downloaded to the current user's home directory.

    Next, if the code needs to be patched or corrected, it can be done at this time. For example, the following fixes a problem that may occur during the configuration phase:

```sh
sed -i'/compile_prog/s@"\$glib_cflags"@"\$glib_cflags -Werror"@g' configure
```

```sh
sed -i's@"loongarch"@"loongarch64"@g' linux-user/loongarch64/target_syscall.h
```

    QEMU has many compilation parameters, which can be viewed with the following command:

```sh
./configure --help
```

    The parameter we care about here is mainly "--target-list". By checking the content supported by this parameter, we will find that QEMU has two main ways to use it, namely: softmmu and Linux user mode, the former is system emulation, and the latter is The simple understanding of Linux user mode simulation is that the former simulates a host, and the latter simulates the Linux kernel environment and can directly run linux commands.

    The opened QEMU source code that supports the LoongArch architecture only supports the Linux User mode, so the next step is to compile and use it according to this mode.

### Install and compile dependent environment
    Before compiling, you need to install some system software development packages. These packages are needed when compiling QEMU. Usually, the names of packages that are missing in the current system will be given in the ./configure configuration stage. If they are not installed, install them, such if you need glib2 development kit, you can use the following command:

```sh
dnf install glib2-devel
```
    In addition to installing the development files of the necessary software packages, some static libraries are also used for the Linux User mode, so they are should be also installed in the system, for example:

```sh
dnf install glib2-static pcre-static zlib-static
```

    Note that at this time, you need to use a root-privileged user to install, or add sudo execution permissions to the current user and then install it through the sudo command.

### Linux-User Mode

#### Configuration steps
    Use the following steps to configure first:

```sh
./configure --prefix=/usr --target-list=loongarch64-linux-user \
            --disable-werror --static --disable-docs
```
    Configuration parameter explanation:  
    ```--prefix=/usr```: Set the base directory for installation.  
    ```--target-list=loongarch64-linux-user```: This configuration parameter is a key item, here is specified loongarch64-linux-user, "loongarch64" means supporting LoongArch64 architecture, "linux-user" means Linux -User mode.  
    ```--disable-werror```: Prevent syntax warnings from becoming errors, which may cause errors when compiling QEMU with higher versions of gcc.  
    ```--static```: This configuration parameter is also a key item. It is used to specify that the compiled binary command file is statically linked. This requires the system to install a static library that compiles the link library files required by QEMU.  
    ```--disble-docs```: This parameter is not necessary, this parameter is used to cancel the production step of the document file, which can reduce some compilation time.

    In the configuration phase, you need to keep the network status, because the configuration process will need to download some files from the network. This is one-time process is, that is after first configuration phase will be carried out, as long as the software source code directory is not deleted, subsequent reconfiguration would not longer need to download anything.

#### Compilation steps
    Next steps if compilation which is very simple. Just use the make command, as follows:

```sh
make
```

    Of course, if you want to speed up the compilation, you can add the "-jN" parameter, N needs to be replaced with a certain number, and you can use the number calculated by your current "CPU core number*2+1".
    After some time (depending on the performance of the machine) the compilation will be completed.

#### installation steps
    After the compilation is complete, install QEMU. There is no need to use the common make install command to install, because currently we only need an executable file, which is stored in the build directory, switch to root user authority and install it with the following command:

```sh
strip --strip-all build/qemu-loongarch64
cp -a build/qemu-loongarch64 /bin/
```
    The strip command can be used to strip unnecessary debugging information from an executable file, which can greatly reduce the file size.

    After the qemu-loongarch64 command is copied to the /bin directory, the installation is completed.

## 3 Use QEMU

### Use of Linux User Mode

#### Download LoongArch Linux system
    There is already pre-made LoongArch Linux system on GitHub, use the following address steps to download:  

```sh
cd /tmp
wget -c https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/loongarch64-clfs-system-20210903.tar.bz2
```

    The system downloaded above is a Linux system based on the LoongArch instruction set architecture constructed entirely using open source codes.


#### Unzip the Linux system
    Please use the root user to complete the following decompression steps:

```sh
cd /opt
mkdir clfs-os
cd clfs-os
tar xvpf /tmp/loongarch64-clfs-system-20210903.tar.bz2
```
    After a period of decompression, we have a system based on the LoongArch instruction set in the /opt/clfs-os directory.

#### Test the Linux-User mode of QEMU
    After QEMU and Linux system have been installed, you can start to verify whether the Linux-User mode of QEMU is working properly, use the following command:

```sh
/bin/qemu-loongarch64 -L /opt/clfs-os /opt/clfs-os/bin/ls /
```

    If the command can be executed normally and the contents of the current system root directory are listed, it means that the Linux User mode of QEMU can be used.

#### Register Binfmt Information
    When we test the use of Linux User mode, we will find that in order to execute a command, we need to specify related parameters. This makes when we want to try to chroot into this system, we will cause a lot of problems because of these additional parameter specifications. Can the problem that is convenient for handling be used like the command in the current system?

    The answer is of course yes, the solution is to use Binfmt to execute.

    In simple terms, Binfmt is to register the "header information" of an executable file in the kernel. When the executed executable file matches the registered "header information", it will call the command execution file specified during registration.

    As can be seen from the above description, Binfmt needs kernel support before it can be used, so first confirm whether the following current system supports it, and use the command:

```sh
ls /proc/sys/fs/binfmt_misc/
```
    If it shows that there are the following files in the directory:  
    ```register status```  
    To check if Binfmt function is turned on, look at the content of the following status file:  

```sh
cat /proc/sys/fs/binfmt_misc/status
```

    If it is displayed as ```enable```, it means that the Binfmt function is currently supported and available by the kernel.

    The next step is to register the LoongArch executable file information, use the following command:

```sh
echo ":qemu-loongarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x02\x01:\xff\xff\ xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/bin/qemu-loongarch64:"> /proc/sys/ fs/binfmt_misc/register
```

    The above command registers the "header information" of the LoongArch executable file, and specifies that the qualified files will be executed using the "/bin/qemu-loongarch64" command, so this "/bin/qemu-loongarch64" command must be true and effective.

#### Chroot to LoongArch system
    In order to conveniently chroot to the LoongArch system through the Linux-User mode of QEMU, the registration of the Binfmt function is essential. After the registration is completed, the following one-time steps are required:

```sh
cp /bin/qemu-loongarch64 /opt/clfs-os/bin/
```

    We copy the executable file qemu-loongarch64 to the system that needs chroot. This step is very important, and we must ensure that the relative location of qemu-loongarch64 stored in the chroot system is the same as the directory location of the command in the current system,  is the same as what is given to Binfmt. Only in this way can the Binfmt function can find the correct simulator command after chrooting to the new system.

    Next, when we see success, use a root user or sudo command to chroot:

```sh
chroot /opt/clfs-os
```
    At this time we will see the familiar Bash prompt:

    bash-5.1#

    Try to enter some commands, such as ls, vi, you will find that you can run it directly.

    Then enter:  

```sh
uname -m
```  
    Will return: 

    loongarch64

    It represents the architecture of LoongArch being simulated in the current environment.


#### Graphical program execution
    In the LoongArch system we provide, if it is a command used in a terminal, it can be easily executed and operated, just like a program for local architecture, but what if you want to execute some programs in a graphical environment?

    Next, we will try to run a terminal program under a graphics system as an example.

##### Mount the necessary file system
    For a chrooted system, the lack of necessary file systems will affect the operation of some programs. You can mount several necessary file systems after chrooting. The steps are as follows:

```sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mount -t devpts devpts /dev/pts
```

##### Create a normal user
    Some programs in the system have certain requirements for users. For example, they cannot be run as the root user. However, chroot uses the root user to log in by default. Therefore, to create an ordinary user, the steps are as follows:

```sh
/sbin/useradd -m testuser
```

    And switch to that user

```sh
su testuser
```

##### Execute graphical program
    Because the system downloaded in this article already includes the Xorg graphics system, and a small amount of graphics applications have been added, if you chroot to the LoongArch system in the Xorg environment, you can run the graphics in the LoongArch Linux system in this environment program.

    Before running, you need to set the DISPLAY environment variable so that the graphics program can be linked to the Xorg environment. Refer to the following command:

```sh
export DISPLAY=:0
```

    After setting, you can run a graphical terminal program to test it, command:

```sh
xterm
```

    XTerm is a simple terminal program that runs under the X graphics system. If everything is normal, you can start XTerm and display a terminal window. This terminal window is displayed by the program execution under the LoongArch system.


##### Development environment
    Through the above methods, you can also run other programs or graphics programs, including various development tools. Since the system provides a complete development environment, you can also compile a program in the LoongArch system to execute it, and everything looks the same. The real LoongArch machine is similar.


## Appendix
Qemu for loongarch64 linux-user program under X86_64 system:

```
https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/qemu-x86_64-to-loongarch64
```


Qemu for loongarch64 linux-user program under MIPS64EL system:

```
https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/qemu-mips64el-to-loongarch64
```



## Finish

    This article will be updated from time to time based on QEMU's support for LoongArch.

    Thank you for your support and welcome your valuable comments.
