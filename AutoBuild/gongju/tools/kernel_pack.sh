#!/bin/bash -e

INITRAMFS_URL="https://mirrors.wsyu.edu.cn/fedora/linux/Yongbao/initramfs/initramfs-squashfs.img.gz"

declare OUT_DIR=""
declare ARCH_FAMILY="loongarch"

while getopts 'o:a:h' OPT; do
    case $OPT in
        o)
            OUT_DIR=$OPTARG
            ;;
	a)
	    ARCH_FAMILY=$OPTARG
	    ;;
        h|?)
            echo "将指定目录中的内核及内核模块文件打包成Yongbao系统使用的目录和文件结构。"
	    echo "-o：该参数需要指定一个目录，该目录用来存放内核及模块的处理结果文件，不指定该参数将默认使用out目录。"
	    exit 0
	    ;;
    esac
done
shift $(($OPTIND - 1))

if [ "x${1}" == "x" ]; then
        echo "必须指定一个目录，该目录下以lib/modules/<要打包内核版本>目录结构存放。"
        exit 1
fi

if [ ! -d ${1} ]; then
	echo "指定的目录不存在，无法进行处理。"
	exit 2	
fi

MKSQUASHFS=""
if [ -f /usr/bin/mksquashfs ]; then
	MKSQUASHFS=/usr/bin/mksquashfs
else
	if [ -f /sbin/mksquashfs ]; then
		MKSQUASHFS=/sbin/mksquashfs
	fi
fi
if [ "x${MKSQUASHFS}" == "x" ]; then
	echo "没有发现 mksquashfs 命令，请安装。"
	exit 3
fi

KERNEL_COUNT=$(find ${1}/lib/modules/ -mindepth 1 -maxdepth 1 -type d | sed "s@${1}/lib/modules/@@g" | wc -l)
if [ "x${KERNEL_COUNT}" != "x1" ]; then
	echo "指定目录中存在多个内核模块目录或不存在内核模块目录，请处理多余的内核模块目录或安装需要处理的内核模块目录"
	exit 5
fi

KERNEL_VERSION=$(find ${1}/lib/modules/ -mindepth 1 -maxdepth 1 -type d | sed "s@${1}/lib/modules/@@g")
echo "处理的内核版本： ${KERNEL_VERSION}"

if [ "x${OUT_DIR}" == "x" ]; then
	echo "未指定存放结果的目录，将使用默认的out目录，若需要指定目录，可使用-o参数"
	OUT_DIR="out"
fi

if [ ! -d initramfs_template ]; then
	mkdir -p initramfs_template
fi
if [ ! -f initramfs_template/initramfs-squashfs.img.gz ]; then
	echo "下载 initramfs 模板文件..."
	wget -c "${INITRAMFS_URL}" -O initramfs_template/initramfs-squashfs.img.gz
	if [ "x$?" == "x0" ]; then
		echo "下载完成，请不要删除，以后在当前目录下制作可以复用，不用再次下载。"
	else
		echo "下载失败，请检查网络环境。"
		exit 7
	fi
fi


DATA_SUFF="$(date +%Y%m%d%H%M%S)"
if [ -d "${OUT_DIR}" ]; then
	echo "${OUT_DIR} 目录已经存在，将备份原目录为 ${OUT_DIR}.${DATA_SUFF} ..."
	mv "${OUT_DIR}" "${OUT_DIR}.${DATA_SUFF}"
fi
echo -n "创建 ${OUT_DIR} , 处理结果将存放在该目录下..."
mkdir -p "${OUT_DIR}"/dist/{boot,images}
mkdir -p "${OUT_DIR}"/build/usr/lib/modules
echo "完成！"

echo "复制内核文件..."
if [ ! -L ${1}/lib/modules/${KERNEL_VERSION}/build ]; then
	echo "内核源码目录找不到，请检查 ${1}/lib/modules/${KERNEL_VERSION}/build 链接是否存在。"
	exit 6
fi
KERNEL_SOURCE_DIR=$(realpath ${1}/lib/modules/${KERNEL_VERSION}/build)
if [ -d ${KERNEL_SOURCE_DIR} ]; then
	cp -af ${KERNEL_SOURCE_DIR}/arch/${ARCH_FAMILY}/boot/vmlinux.efi ${OUT_DIR}/dist/boot/vmlinux_${KERNEL_VERSION}.efi
	cp -af ${KERNEL_SOURCE_DIR}/.config ${OUT_DIR}/dist/boot/vmlinux_${KERNEL_VERSION}.config
else
	echo "没有 ${KERNEL_SOURCE_DIR} 目录，无法复制内核文件。"
	exit 6
fi
echo "完成！"

echo "安装 initramfs-squashfs.img.gz ..."
cp -a initramfs_template/initramfs-squashfs.img.gz ${OUT_DIR}/dist/boot/initramfs_${KERNEL_VERSION}.img.gz

echo "创建内核模块的镜像文件..."
cp -a ${1}/lib/modules/${KERNEL_VERSION} "${OUT_DIR}"/build/usr/lib/modules/
${MKSQUASHFS} "${OUT_DIR}"/build "${OUT_DIR}"/dist/images/kernel_${KERNEL_VERSION}.loongarch64.squashfs -all-root -comp xz
echo "镜像文件创建完成！"
echo ""

echo -n "创建启动项参考内容 ${OUT_DIR}/dist/boot/grub.cfg.${KERNEL_VERSION} ..."
cat > ${OUT_DIR}/dist/boot/grub.cfg.${KERNEL_VERSION} << EOF
menuentry '勇豹 测试内核 (Linux ${KERNEL_VERSION})' {
  set gfxpayload=keep
  echo '加载Linux内核……'
  linux /boot/vmlinux_${KERNEL_VERSION}.efi LABEL=Yongbao quiet amdgpu.dpm=0
  initrd /boot/initramfs_${KERNEL_VERSION}.img.gz
  echo '加载完成，开始启动勇豹系统……'
}
EOF
echo "完成！请将该文件内容复制并添加到启动系统的 boot/grub/grub.cfg 中，并参考已有启动项修改LABEL=之后的标签名。"
echo ""
echo "所有需要安装的文件均存放在 "${OUT_DIR}"/dist 目录中。"

# MODULE_DIR=$(realpath ${1}/lib/modules/${KERNEL_VERSION}/)
# KERNEL_SOURCE_DIR=$(realpath ${1}/lib/modules/${KERNEL_VERSION}/build)
