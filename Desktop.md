# <center>手把手教你构建基于LoongArch64架构的Linux系统（桌面应用篇）</center>

<center>（Desktop Application For LoongArch64）</center>  

<center>作者：孙海勇</center>

## 0 制作说明

本文是CLFS for LoongArch文档的扩展内容，主要针对桌面应用相关的软件包制作。

## 1 制作环境的准备

本文制作步骤基于CLFS for LoongArch文档制作的基础系统来进行，因此默认认为当前具备了交叉编译的基础系统的环境。

#### 切换到制作用户

　　使用命令切换到新创建的用户：  

```sh
su - lauser
```

　　使用“su”命令进行切换时加上“-”参数可以防止切换前的用户环境变量带到新用户环境中。


## 2 设置环境变量

```sh
export LDFLAGS="-Wl,-rpath-link=${SYSDIR}/sysroot/usr/lib64"
export PKG_CONFIG_SYSROOT_DIR=${SYSDIR}/sysroot
export PKG_CONFIG_PATH="${SYSDIR}/sysroot/usr/lib64/pkgconfig:${SYSDIR}/sysroot/usr/share/pkgconfig"
export COMMON_CONFIG="--prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=/usr/lib64 \
                      --build=${CROSS_HOST} --host=${CROSS_TARGET}"
export JOBS="-j8"
```

## 3 软件包的制作

#### VLC
https://download.videolan.org/vlc/3.0.17.4/vlc-3.0.17.4.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/vlc-3.0.17.4.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/vlc-3.0.17.4
    patch -Np1 -i ${DOWNLOADDIR}/0001-VLC-fix-for-gcc13.patch
    ./configure $COMMON_CONFIG --disable-chromecast
    make -C compat ${JOBS}
    make -C src ${JOBS}
    make -C src DESTDIR=${SYSDIR}/sysroot install
    make ${JOBS}
    make DESTDIR=${SYSDIR}/sysroot install
popd
```

#### SimpleScreenRecorder
https://github.com/MaartenBaert/ssr.git

```sh
git clone https://github.com/MaartenBaert/ssr.git --depth 1
pushd ssr
    patch -Np1 -i ${DOWNLOADDIR}/ssr-add-loongarch64.patch
    mkdir cross-build
    pushd cross-build
        CC="${CROSS_TARGET}-gcc" CXX="${CROSS_TARGET}-g++" \
        cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
              -DPKG_CONFIG_EXECUTABLE=${SYSDIR}/cross-tools/bin/${CROSS_TARGET}-pkg-config \
              -DCMAKE_SYSROOT=${SYSDIR}/sysroot \
              -DCMAKE_FIND_ROOT_PATH=${SYSDIR}/sysroot/usr \
              -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=/usr/lib64 \
              -DWITH_QT5=TRUE \
              ..
        make ${JOBS}
        make DESTDIR=${SYSDIR}/sysroot install
    popd
popd
```

#### LibreOffice

获取软件代码。

```sh
git clone https://git.libreoffice.org/core --depth 1
pushd core
git submodule init
git submodule update --depth 1
popd
mv core libreoffice-7.5-git
tar -czf ${DOWNLOADDIR}/libreoffice-7.5-git.tar.gz libreoffice-7.5-git
```

编译和安装。

```
tar xvf ${DOWNLOADDIR}/libreoffice-7.5-git.tar.gz -C ${BUILDDIR}
pushd ${BUILDDIR}/libreoffice-7.5-git
    cp ${SYSDIR}/cross-tools/share/automake-1.16/config.* ./
    aclocal
    patch -Np1 -i ${DOWNLOADDIR}/libreoffice-7.5-for-clfs.patch
    patch -Np1 -i ${DOWNLOADDIR}/libreoffice-7.5-libgpg-error-add-loongarch64.patch
    patch -Np1 -i ${DOWNLOADDIR}/libreoffice-7.5-postgresql-disable_spinlock.patch
    PKG_CONFIG_FOR_BUILD=/bin/pkg-config \
    perl ./autogen.sh CC=${CROSS_TARGET}-gcc CXX=${CROSS_TARGET}-g++ \
                      --build=${CROSS_HOST} --host=${CROSS_TARGET} \
                      --prefix=/opt/libreoffice \
                      --with-lang="zh-CN" --with-vendor=Sunhaiyong \
                      --with-help --with-myspell-dicts \
                      --without-junit --without-system-dicts --disable-dconf --disable-odk \
                      --enable-release-build=yes --without-java \
                      --with-system-boost --with-system-curl --with-system-epoxy \
                      --with-system-expat --with-system-graphite --with-system-harfbuzz \
                      --with-system-icu --with-system-jpeg --with-system-lcms2 \
                      --with-system-libatomic_ops --with-system-libpng --with-system-libxml \
                      --with-system-nss --with-system-openssl \
                      --with-system-zlib --with-system-openjpeg \
                      LIBS="-lstdc++" \
                      --with-boost-libdir=${SYSDIR}/sysroot/usr/lib64 \
                      --disable-coinmp --enable-python=no
    ZIC=/usr/sbin/zic make build ${JOBS}
    make DESTDIR=${PWD}/dest distro-pack-install
    cp -a ${PWD}/dest/opt/libreoffice ${SYSDIR}/sysroot/opt/
    mkdir -pv ${SYSDIR}/sysroot/usr/share/bash-completion/completions/
    cp -a ${PWD}/dest/usr/share/bash-completion/completions/* ${SYSDIR}/sysroot/usr/share/bash-completion/completions/
    cp -a ${PWD}/dest/opt/libreoffice/share/applications/*.desktop \
           ${SYSDIR}/sysroot/usr/share/applications/
    mkdir -pv ${SYSDIR}/sysroot/usr/share/xdg/
    cp -a ${PWD}/dest/opt/libreoffice/lib/libreoffice/share/xdg/*.desktop \
           ${SYSDIR}/sysroot/usr/share/xdg/
popd
```


#### Thunderbird 100
https://archive.mozilla.org/pub/thunderbird/releases/100.0b4/source/thunderbird-100.0b4.source.tar.xz

```sh
tar xvf ${DOWNLOADDIR}/thunderbird-100.0b4.source.tar.xz -C ${BUILDDIR}
pushd ${BUILDDIR}/thunderbird-100.0
    mkdir -pv mozbuild/l10n-central
    pushd mozbuild/l10n-central
        unzip ${DOWNLOADDIR}/firefox-100-l10.zip
        mv zh-CN* zh-CN
    popd
    patch -Np1 -i ${DOWNLOADDIR}/firefox-100-add-loongarch.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-100-add-rust-libc.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-100-xpcom-add-loongarch.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-100-for-clfs.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-100-workround.patch
    patch -Np1 -i ${DOWNLOADDIR}/firefox-100-fix-for-gcc13.patch
    cat > comm/third_party/botan/src/build-data/arch/loongarch64.txt << "EOF"
family loongarch
endian little
wordsize 64
EOF

    cat > mozconfig << "EOF"
ac_add_options --disable-necko-wifi
ac_add_options --with-system-libevent
ac_add_options --with-system-libvpx
ac_add_options --with-system-nspr
ac_add_options --with-system-nss
ac_add_options --with-system-icu
ac_add_options --prefix=/usr
ac_add_options --libdir=/usr/lib64
ac_add_options --target=loongarch64-unknown-linux-gnu
ac_add_options --enable-application=comm/mail
ac_add_options --disable-jit
ac_add_options --disable-crashreporter
ac_add_options --disable-updater
ac_add_options --disable-debug
ac_add_options --disable-debug-symbols
ac_add_options --disable-tests
ac_add_options --enable-optimize=-O2
ac_add_options --enable-official-branding
ac_add_options --enable-system-ffi
ac_add_options --enable-system-pixman
ac_add_options --with-system-jpeg
ac_add_options --with-system-png
ac_add_options --with-system-zlib
ac_add_options --without-wasm-sandboxed-libraries
ac_add_options --with-system-webp
ac_add_options --disable-strip
ac_add_options --disable-jemalloc
ac_add_options --disable-install-strip
ac_add_options --enable-fmp4
ac_add_options --with-sysroot=${SYSDIR}/sysroot

unset MOZ_TELEMETRY_REPORTING
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/thunderbird-build-dir
EOF
    CC=${CROSS_TARGET}-gcc CXX=${CROSS_TARGET}-g++ \
    CXXFLAGS="-fpermissive" \
    MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system MOZBUILD_STATE_PATH=${PWD}/mozbuild \
    ./mach configure
    CC=${CROSS_TARGET}-gcc CXX=${CROSS_TARGET}-g++ \
    CXXFLAGS="-fpermissive" \
    MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system MOZBUILD_STATE_PATH=${PWD}/mozbuild \
    ./mach build ${JOBS}
    CC=${CROSS_TARGET}-gcc CXX=${CROSS_TARGET}-g++ \
    CXXFLAGS="-fpermissive" \
    MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system MOZBUILD_STATE_PATH=${PWD}/mozbuild \
    ./mach package
    CC=${CROSS_TARGET}-gcc CXX=${CROSS_TARGET}-g++ \
    CXXFLAGS="-fpermissive" \
    MACH_BUILD_PYTHON_NATIVE_PACKAGE_SOURCE=system MOZBUILD_STATE_PATH=${PWD}/mozbuild \
    ./mach build installers-zh-CN
    tar xvf thunderbird-build-dir/dist/thunderbird-100.0.zh-CN.linux-loongarch64.tar.bz2 \
        -C ${SYSDIR}/sysroot/usr/lib64/
    ln -sfv /usr/lib64/thunderbird/thunderbird ${SYSDIR}/sysroot/usr/bin/thunderbird
popd
cat > ${SYSDIR}/sysroot/usr/share/applications/thunderbird.desktop << "EOF"
[Desktop Entry]
Encoding=UTF-8
Name=Thunderbird Mail
Name[zh_CN]=邮件客户端
Comment=Send and receive mail
Comment[zh_CN]=邮件客户端
GenericName=邮件客户端
Exec=thunderbird %u
Terminal=false
Type=Application
Icon=thunderbird
Categories=Network;Email;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/rss+xml;x-scheme-handler/mailto;
StartupNotify=true
EOF
ln -sfv ${SYSDIR}/sysroot/usr/lib/thunderbird/chrome/icons/default/default256.png \
        ${SYSDIR}/sysroot/usr/share/pixmaps/thunderbird.png
```

## 4 处理目标系统

### 清理符号（symbol）信息
　　目前安装到目标系统中的二进制文件大多带有各种符号信息，这些信息不影响执行，但是占用了大量的存储空间，如果没有调试相关的需求，可以将这些信息清理掉以减少存储空间。

　　清理符号信息可以使用strip命令，但strip必须能够处理目标平台二进制，所以我们可以使用交叉编译工具链中的strip命令来操作，操作步骤如下：

```sh
pushd ${SYSDIR}/sysroot
	find usr/lib{,64} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {} ';'
	find usr/lib{,64} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'
	find usr/{bin,sbin,libexec} -type f -exec ${CROSS_TARGET}-strip --strip-all {} ';'
	find opt -type f -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'
popd
```

　　这里我们发现strip使用的参数有多种，这里简单的说明一下：  
　　* `--strip-debug`，仅去掉调试相关的符号信息，该参数适合用于静态库文件，对于链接过程需要的信息是不会去掉的。  
　　* `--strip-unneeded`，删除所有与重定位无关的所有符号信息，该参数不能用于静态库文件，否则会导致静态链接时无法使用处理过的静态库。  
　　* `--strip-all`，该参数代表所有能去掉的符号信息都尽量去掉，该参数不建议用于库文件，特别是静态库文件。

### 清除.la文件
```sh
find ${SYSDIR}/sysroot/usr/lib64/ -type f -name "*.la" -exec rm '{}' ';'
```

### 打包系统
　　制作完成后就可以退出制作用户环境了，使用命令:

```sh
exit
```


### 打包系统

　　接着可以使用root权限对目标系统进行打包，打包步骤如下：

```sh
pushd ${SYSDIR}/sysroot
	sudo tar --xattrs-include='*' --owner=root --group=root -cjpf \
			${SYSDIR}/loongarch64-clfs-system-6.1-DesktopApp.tar.bz2 *
popd
```

## 附录

### 参考资料
《用“芯”探索 教你构建龙芯平台的Linux系统》 孙海勇 著

LFS： https://www.linuxfromscratch.org/lfs/  

BLFS: https://www.linuxfromscratch.org/blfs/
