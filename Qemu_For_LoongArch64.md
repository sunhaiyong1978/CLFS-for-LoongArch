# <center>使用QEMU运行基于LoongArch64架构的Linux系统</center>

<center>（Qemu For LoongArch64）</center>  

<center>作者：孙海勇</center>

## 1 前言
　　龙芯中科于2021年推出了全新指令集架构LoongArch，其中64位指令集称为LoongArch64。  
　　基于LoongArch64指令集的操作系统需要运行在使用龙芯3A5000 CPU的机器上，在没有这样的机器的情况下如果想简单的体验就需要使用到QEMU这个模拟器。  
　　本文的目标是通过一步一步的制作使用QEMU运行一个基于LoongArch64制作的Linux系统。

## 2 编译QEMU

　　本文将采用编译QEMU源代码的方式来创建可执行的QEMU，因当前大多数系统中的QEMU并未支持LoongArch64指令，所以接下来先从下载和编译QEMU开始说起。

### 准备编译环境
　　QEMU支持从不同的指令架构机器上模拟目标指令架构的环境，因此用的机器只要是能运行QEMU就可以了，当然这个用来运行QEMU的机器我们建议安装一个“正常”的Linux系统，因为后续还需要进行编译，所以必须能提供编译QEMU的开发环境。

　　因在不同架构的机器上制作QEMU并运行LoongArch64的Linux系统与架构本身并没有太大关系，主要差异仅在具体的Linux系统准备编译环境的步骤上会因为Linux所使用的包管理工具不同而有所不同，但在使用QEMU上几乎没有差异，所以接下来我们将以一个使用Fedora Linux发行版系统的环境来讲解。

　　如果你使用的是X86的机器，那么可以选择的系统版本非常多，而如果你用的是非X86架构的机器那么就要确定可使用的版本，接下来我们会以龙芯3A4000的机器上可以运行的Fedora28为例进行制作和使用的讲解，当然这些步骤也同样适合例如同样在3A4000上的Fedora 32这样更新的版本，或者在X86机器上的Fedora 34或者其他Linux系统上。

#### 创建一个普通用户
　　不建议使用root用户来编译制作软件包，所以我们在一开始创建一个普通用户，比如“loongson”，如果系统中已经有了这个用户可以创建其他名字的用户或者跳过这个步骤。

　　创建命令如下：

```sh
useradd -m loongson
```

　　参数“-m”的用处是给这个新用户创建家目录，接下来我们会需要用到用户的家目录。

　　注意：创建用户的工作必须由具有root权限的用户来进行。

#### 切换用户
　　创建好普通用户后，就可以切换到该用户下，使用如下命令：

```sh
su loongson
```

　　通过root用户切换到普通用户可以避免输入密码。

　　默认情况下切换用户后会自动进入该用户的家目录，之后的工作将在家目录中进行。

### 下载QEMU的源代码

　　QEMU中支持LoongArch64的代码目前还没有进入到QEMU的上游源代码仓库中，因此，我们需要下载一个有LoongArch64指令支持的QEMU源代码。

　　使用以下命令下载QEMU代码：

```sh
git clone https://github.com/gaosong-loongson/qemu.git -b tcg-dev
```

经过一段时间的下载过程后我们就拥有了支持LoongArch64指令集的QEMU源代码。


### QEMU的支持模式
　　接下来就是最为关键的编译过程。

　　进入QEMU的源代码目录：

```sh
cd ~/qemu
```
　　注意：这里假定源代码是下载到当前用户的家目录中。

　　接下来，如果代码有需要打补丁或者修正问题的，可以在这个时候进行，例如下面修复一个在配置阶段可能出现的问题：

```sh
sed -i '/compile_prog/s@"\$glib_cflags"@"\$glib_cflags -Werror"@g' configure
```

　　QEMU的编译参数非常的多，可以通过以下命令查看：

```sh
./configure --help
```

　　这里我们关心的参数主要是“--target-list”，通过查看该参数支持的内容会发现，QEMU主要有两种使用方式，分别是：softmmu和linux-user，前者是系统仿真，而后者是linux用户模式仿真，简单的理解就是前面模拟了一台主机，后者模拟了Linux内核环境可以直接运行linux命令。

　　目前开放出来的支持LoongArch架构的QEMU源代码仅支持Linux-User模式，因此接下来按照该模式进行编译和使用。

### 安装编译依赖环境
　　在编译前需要安装一些系统软件开发包，这些软件包是编译QEMU时所需要的，通常在./configure配置阶段会给出目前系统中缺少的软件包名称，如果有确实就及时安装上，比如需要glib2的开发包，可以使用如下命令：

```sh
dnf install glib2-devel
```
　　除了安装必要的软件包的开发文件外，针对Linux-User模式还会用到一些静态库，因此也一并安装到系统中，例如：

```sh
dnf install glib2-static pcre-static zlib-static
```

　　注意，此时需要使用root权限的用户进行安装，或者给当前用户增加sudo执行的权限然后通过sudo命令进行安装。

### Linux-User模式

#### 配置步骤
　　使用如下步骤先进行配置：

```sh
./configure --prefix=/usr --target-list=loongarch64-linux-user \
            --disable-werror --static --disable-docs
```
　　配置参数解释：  
　　```--prefix=/usr```：设置安装的基础目录。  
　　```--target-list=loongarch64-linux-user```：此配置参数是关键项，这里指定了loongarch64-linux-user，“loongarch64”代表支持LoongArch64架构，“linux-user”代表是Linux-User模式。  
　　```--disable-werror```：防止语法警告变成错误，这可能导致高版本的gcc编译QEMU时出现错误。  
　　```--static```：这个配置参数也时关键项，用于指定编译出来的二进制命令文件是静态链接的，这就需要系统中安装编译QEMU所需链接库文件的静态库。  
　　```--disble-docs```:该参数不是必须的，该参数用来取消文档文件的制作步骤，这样可以减少一些编译时间。

　　在配置阶段，需要保持联网状态，因配置过程中会需要从网络上下载一些文件，这个过程是一次性的，也就是第一次配置阶段会进行，只要软件源码目录没有被删除，后续重新配置时不再需要下载。

#### 编译步骤
　　接下来进行编译，编译非常简单，使用make命令即可，如下：

```sh
make
```

　　当然，你要想加速编译，可以增加“-jN”参数，N需要替换成确定的数字，可以使用你当前"CPU核数*2+1"计算出的数字。
　　如果顺利经过一段时间（视机器性能）后即可完成编译。

#### 安装步骤
　　编译完成后进行安装，这里不必使用常见的make install命令进行安装，因为当前我们只需要一个可执行文件即可，该文件存放在build目录中，切换到root用户权限下并使用如下命令安装：

```sh
strip --strip-all build/qemu-loongarch64
cp -a build/qemu-loongarch64 /bin/
```
　　strip命令可以用来剥离可执行文件中不需要的调试信息，可以极大的减少文件大小。

　　qemu-loongarch64命令被复制到/bin目录之后，就完成了安装。

## 3 使用QEMU

### Linux-User模式的使用

#### 下载LoongArch的Linux系统
　　在GitHub上有已经制作好的LoongArch Linux系统，使用以下地址步骤进行下载：  

```sh
cd /tmp
wget -c https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/loongarch64-clfs-system-20210903.tar.bz2
```

　　以上下载的系统是一个完全使用已开放的源代码构建的基于LoongArch指令集架构的Linux系统。


#### 解压缩Linux系统
　　请使用root权限的用户完成以下解压缩的步骤：

```sh
cd /opt
mkdir clfs-os
cd clfs-os
tar xvpf /tmp/loongarch64-clfs-system-20210903.tar.bz2
```
　　经过一段时间的解压后，我们就在/opt/clfs-os目录中拥有了一个基于LoongArch指令集制作的系统。

#### 测试QEMU的Linux-User模式
　　已经安装好QEMU和Linux系统后，就可以开始验证QEMU的Linux-User模式工作是否正常了，使用如下命令：

```sh
/bin/qemu-loongarch64 -L /opt/clfs-os /opt/clfs-os/bin/ls /
```

　　如果命令能正常执行并列出了当前系统根目录的内容，那么就代表QEMU的Linux-User模式已经能使用了。

#### 注册Binfmt信息
　　当我们在测试Linux-User模式使用时会发现，为了执行一个命令，需要通过指定相关参数才行，这使得当我们想尝试chroot到这个系统中时，会因为这些额外的参数指定而导致很多不方便处理的问题，能不能像执行当前系统中的命令一样使用呢？

　　答案当然是可以，方案就是使用Binfmt方式执行。

　　Binfmt简单来说就是在内核中注册一个可执行文件的“头信息”，当执行的可执行文件符合注册的“头信息”时就会调用注册时指定的命令执行文件。

　　从上面的说明可以看出，Binfmt需要内核支持才可以使用，所以先确认以下当前的系统是否支持，使用命令：

```sh
ls /proc/sys/fs/binfmt_misc/
```
　　如果显示该目录下有以下文件：  
　　```register  status```  
　　代表Binfmt功能是打开的，再看以下status文件的内容：  

```sh
cat /proc/sys/fs/binfmt_misc/status
```

　　如果显示为```enable```，则代表Binfmt功能目前内核支持且可用。

　　接下来就是注册LoongArch可执行文件的信息了，使用如下命令：

```sh
echo ":qemu-loongarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x02\x01:\xff\xff\xff\xff\xff\xfe\xfe\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/bin/qemu-loongarch64:" > /proc/sys/fs/binfmt_misc/register
```

　　以上命令注册了LoongArch可执行文件“头信息”，并指定符合条件的文件会使用"/bin/qemu-loongarch64"命令来执行，所以这个"/bin/qemu-loongarch64"命令必须真实有效。

#### Chroot到LoongArch系统
　　要想方便的通过QEMU的Linux-User模式chroot到LoongArch的系统中，Binfmt功能的注册是必不可少的，当完成注册后还需要如下的一次性步骤：

```sh
cp /bin/qemu-loongarch64 /opt/clfs-os/bin/
```

　　我们将qemu-loongarch64这个命令文件复制到需要chroot的系统中，这个步骤非常关键，并且要保证qemu-loongarch64在这个chroot的系统中存放的相对位置与当前系统中该命令的目录位置相同，也就是保证与Binfmt中注册的路径相同，只有这样才能在chroot到新系统后Binfmt功能依旧能够找到正确的模拟器命令。

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


#### 图形程序的执行
　　在我们提供的LoongArch系统中，如果是在文本中断使用的命令，那么可以很容易的执行和操作，就跟本地架构的程序一样，然而要想执行一些图形环境下的程序会怎么样呢？

　　接下来我们以尝试运行一个图形系统下的终端程序为例来进行介绍。

##### 挂载必要的文件系统
　　对于一个chroot的系统来说，缺少必要的文件系统会影响部分程序的运行，可以在chroot后挂载几个必要的文件系统，步骤如下：

```sh
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mount -t devpts devpts /dev/pts
```

##### 创建普通用户
　　系统中有些程序对用户有一定的要求，比如不能使用root用户运行，然而chroot默认使用root用户登录，因此创建一个普通用户，步骤如下：

```sh
useradd -m testuser
```

　　并且切换到该用户

```sh
su testuser
```

##### 执行图形化程序
　　因本文下载的系统已经包含了Xorg的图形系统，并有加入了少量的图形应用程序，如果是在Xorg环境下chroot到LoongArch系统中的情况下，可以在该环境下运行LoongArch Linux系统中的图形程序。

　　在运行之前需要设置DISPLAY环境变量，以便图形程序能够链接到Xorg环境，参考如下命令：

```sh
export DISPLAY=:0
```

　　设置完成后，可以运行一个图形终端程序测试一下，命令：

```sh
xterm
```

　　XTerm是一个简易的X图形系统下运行的终端程序，如果一切正常的话可以启动XTerm，并显示一个终端窗口，这个终端窗口就是LoongArch系统下的程序执行显示的。


##### 开发环境
　　通过以上的方式还可以运行其它程序或图形程序，这包括各种开发工具，由于系统中提供了完整的开发环境，你也可以在LoongArch系统中自行编译某个程序来执行，一切看起来跟用真实的LoongArch机器相似。


## 附件
X86_64系统下的Qemu for loongarch64 linux-user 程序：

```
https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/qemu-x86_64-to-loongarch64
```


MIPS64EL系统下的Qemu for loongarch64 linux-user 程序：

```
https://github.com/sunhaiyong1978/CLFS-for-LoongArch/releases/download/20210903/qemu-mips64el-to-loongarch64
```



## 结束

　　本文会根据QEMU支持LoongArch的状况不定期的进行更新。

　　感谢大家支持，欢迎提出宝贵的意见。

