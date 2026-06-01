#!/bin/bash -e

export BASE_DIR="${PWD}"

declare UPDATE_MODE=FALSE
declare KERNEL_ONLY=FALSE
declare DISTRO_ARCHIVE_MODE="dir"
declare DISTRO_LABEL=""
declare WORLD_PARM=""

while getopts 'ukwl:m:h' OPT; do
    case $OPT in
        u)
            UPDATE_MODE=TRUE
            ;;
        k)
            KERNEL_ONLY=TRUE
            ;;
	l)
	    DISTRO_LABEL=$OPTARG
	    ;;
	m)
	    DISTRO_ARCHIVE_MODE=$OPTARG
	    ;;
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    echo "强制指定使用主线环境中进行构建。"
	    ;;
        h|?)
            echo "用法: `basename $0` [选项]"
	    echo "选项："
	    echo "w: 强制使用主线构建部分。"
	    echo "l: 指定发行版的名称字串。"
	    echo "u: 使用更新模式。"
	    echo "k: 仅导出内核及启动相关部分。"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

if [ "x${WORLD_PARM}" == "x" ]; then
	if [ -f ${BASE_DIR}/current_branch ]; then
		RELEASE_VERSION="$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
		if [ -d ${BASE_DIR}/Branch_${RELEASE_VERSION} ]; then
			NEW_TARGET_SYSDIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/workbase"
			NEW_BASE_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}"
			RELEASE_BUILD_MODE=1
			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中制作Live系统。"
		else
			echo "没有发现 Branch_${RELEASE_VERSION} 目录。"
			NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
			NEW_BASE_DIR="${BASE_DIR}"
			RELEASE_BUILD_MODE=0
		fi
	else
		NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
		NEW_BASE_DIR="${BASE_DIR}"
		RELEASE_BUILD_MODE=0
	fi
fi

HOST_TOOLS_DIR=${NEW_TARGET_SYSDIR}/host-tools

if [ "x${1}" == "x" ]; then
#	echo "错误：必须指定一个目录。"
#	exit 1
	echo "警告：没有指定一个制作目录，将使用默认目录 ${NEW_TARGET_SYSDIR}/live_usb 。"
	LIVE_DIRECTORY="${NEW_TARGET_SYSDIR}/live_usb"
else
	LIVE_DIRECTORY="${1}"
fi


if [ ! -d ${LIVE_DIRECTORY} ]; then
	mkdir -pv ${LIVE_DIRECTORY}
fi


DISTRO_NAME=$(grep -r "^DISTRO_NAME=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_NAME}" == "x" ]; then
	echo "无法获取操作系统名称，无法继续，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_NAME的定义。"
	exit 3
fi
DISTRO_ARCH=$(grep -r "^DISTRO_ARCH=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_ARCH}" == "x" ]; then
	echo "缺少架构名称，无法继续，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_ARCH的定义。"
	exit 3
fi
DISTRO_VERSION=$(grep -r "^DISTRO_VERSION=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_VERSION}" == "x" ]; then
	echo "缺少系统的版本号，无法继续，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_VERSION的定义。"
	exit 3
fi
DISTRO_NAME_CN=$(grep -r "^DISTRO_NAME_CN=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_NAME_CN}" == "x" ]; then
        echo "无法获取操作系统中文名称，无法继续，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_NAME_CN的定义。"
        exit 3
fi
DISTRO_ARCH_NAME_CN=$(grep -r "^DISTRO_ARCH_NAME_CN=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
if [ "x${DISTRO_ARCH_NAME_CN}" == "x" ]; then
        echo "无法获取架构中文名称，无法继续，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_ARCH_NAME_CN的定义。"
        exit 3
fi

if [ "x${UPDATE_MODE}" != "xTRUE" ]; then
	for i in boot EFI images
	do
		if [ -d ${LIVE_DIRECTORY}/${i} ]; then
			mv ${LIVE_DIRECTORY}/${i}{,.$(date +%Y%m%d%H%M%S)}
		fi
	done
fi

if [ "x${KERNEL_ONLY}" != "xTRUE" ]; then
	# 复制启动相关文件
	if [ -d ${NEW_TARGET_SYSDIR}/dist/os/bootimage-squashfs ]; then
		cp -a ${NEW_TARGET_SYSDIR}/dist/os/bootimage-squashfs/{boot,EFI} ${LIVE_DIRECTORY}/
	else
		echo "错误：缺少制作LiveUSB的文件，请确认是否完成了系统的制作，可以使用./build.sh完成系统的构建。"
		exit 5
	fi


	# 复制所有squashfs文件
	if [ -d ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/ ]; then
		mkdir -p ${LIVE_DIRECTORY}/images/update
		if [ -f ${NEW_BASE_DIR}/info_set/release_sort ]; then
			for i in $(cat ${NEW_BASE_DIR}/info_set/release_sort | grep -v "^#")
			do
				if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${DISTRO_ARCH}.squashfs ]; then
					echo "发现 ${i}.... ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${DISTRO_ARCH}.squashfs "
					cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/
				fi
			done
		else
			if [ "x$(find ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/*.${DISTRO_ARCH}.squashfs)" != "x" ]; then
				cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/*.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/
			fi
		fi
	else
		echo "错误：缺少LiveUSB所需的文件，可以使用 ./pack_os.sh 命令来准备这些文件。"
		exit 5
	fi




	# 处理基础squashfs文件

	echo "# 顺序编号 文件名称" > ${LIVE_DIRECTORY}/images/images.list

	declare IMAGE_INDEX=5
	for i in boot sysroot
	do
		if [ -f ${LIVE_DIRECTORY}/images/${i}.${DISTRO_ARCH}.squashfs ]; then
			echo "${IMAGE_INDEX} ${i}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
			if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${DISTRO_ARCH}.squashfs ]; then
				cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/update/
			fi
			# devel docs etc.
			if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${i}.split ]; then
				for j in $(cat ${NEW_TARGET_SYSDIR}/overlaydir/${i}.split | awk -F'[[:blank:]]' '{ print $1 }' | sort | uniq) 
				do
					if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${j}.${DISTRO_ARCH}.squashfs ]; then
						cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${j}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/
						echo "$((IMAGE_INDEX+1)) ${i}.${j}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
					fi
					if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${j}.${DISTRO_ARCH}.squashfs ]; then
						cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${j}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/update/
					fi
				done
			fi
		else
			echo "错误：缺少启动核心文件images/${i}.${DISTRO_ARCH}.squashfs，可能导致启动失败！"
			exit 6
		fi
		((IMAGE_INDEX+=10))
	done


	#根据基础squashfs文件生成LABEL字串。
	if [ "x${DISTRO_LABEL}" == "x" ]; then
		MD5_1=$(md5sum ${LIVE_DIRECTORY}/images/boot.${DISTRO_ARCH}.squashfs)
		MD5_2=$(md5sum ${LIVE_DIRECTORY}/images/sysroot.${DISTRO_ARCH}.squashfs)
		NEW_LABEL="$(echo ${DISTRO_NAME}_${DISTRO_VERSION}_${MD5_1:0:5}${MD5_2:0:5} | sed "s@ @@g")"
	else
		NEW_LABEL="$(echo ${DISTRO_LABEL} | sed "s@ @@g")"
	fi
else
	mkdir -p ${LIVE_DIRECTORY}/boot/grub
	mkdir -p ${LIVE_DIRECTORY}/images/update
	#根据基础squashfs文件生成LABEL字串。
	if [ "x${DISTRO_LABEL}" == "x" ]; then
		MD5_1=$(md5sum ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/boot.${DISTRO_ARCH}.squashfs)
		MD5_2=$(md5sum ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/sysroot.${DISTRO_ARCH}.squashfs)
		NEW_LABEL="$(echo ${DISTRO_NAME}_${DISTRO_VERSION}_${MD5_1:0:5}${MD5_2:0:5} | sed "s@ @@g")"
	else
		NEW_LABEL="$(echo ${DISTRO_LABEL} | sed "s@ @@g")"
	fi
fi

if [ "x${KERNEL_ONLY}" != "xTRUE" ]; then
	# 处理各个squashfs文件
	if [ -f ${NEW_BASE_DIR}/info_set/release_sort ]; then
		for i in $(cat ${NEW_BASE_DIR}/info_set/release_sort | grep -v "^#" | sed -e "/^boot$/d" -e "/^sysroot$/d" )
		do
			if [ -f ${LIVE_DIRECTORY}/images/${i}.${DISTRO_ARCH}.squashfs ]; then
				echo "${IMAGE_INDEX} ${i}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
				if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${DISTRO_ARCH}.squashfs ]; then
					cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/update/
				fi
#				for j in devel docs
				if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${i}.split ]; then
					for j in $(cat ${NEW_TARGET_SYSDIR}/overlaydir/${i}.split | awk -F'[[:blank:]]' '{ print $1 }' | sort | uniq)
					do
						if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${j}.${DISTRO_ARCH}.squashfs ]; then
							cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.${j}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/
							echo "$((IMAGE_INDEX+1)) ${i}.${j}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
						fi
						if [ -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${j}.${DISTRO_ARCH}.squashfs ]; then
							cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/${i}.update.${j}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/update/
						fi
					done
				fi
				((IMAGE_INDEX+=10))
			fi
		done
	else
		for i in $(ls ${LIVE_DIRECTORY}/images/*.squashfs | sed "s@${LIVE_DIRECTORY}/images/@@g" | grep "\.${DISTRO_ARCH}\.squashfs" | sed "s@\.${DISTRO_ARCH}\.squashfs@@g" | awk -F'.' '{ print $1 }')
		do
			if [ "x${i}" == "xboot" ] || [ "x${i}" == "xsysroot" ] || [ "x${i:0:7}" == "xkernel_" ]; then
				continue
			fi
			echo "# ${IMAGE_INDEX} ${i}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
			((IMAGE_INDEX+=10))
		done
	fi
fi


# 安装Kernel

KERNEL_VERSION=$(cat ${NEW_TARGET_SYSDIR}/common_files/linux-kernel.version)

if [ "x${KERNEL_VERSION}" != "x" ]; then
	KERNEL_LIST="$(ls ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION})"
	if [ "x$?" == "x0" ] && [ "x${KERNEL_LIST}" != "x" ]; then
		cat > ${LIVE_DIRECTORY}/boot/grub/grub.cfg << EOF
set timeout=5
set theme=\$prefix/themes/starfield/theme.txt

font=\$prefix/fonts/unicode.pf2
if loadfont \$font ; then
  set gfxmode=auto
  set locale_dir=\$prefix/locale
  set lang=zh_CN
fi

terminal_output gfxterm

EOF
		for kernel_dir in $(ls ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION})
		do
			if [ -f ${LIVE_DIRECTORY}/images/kernel_${kernel_dir}.${DISTRO_ARCH}.squashfs ]; then
				rm ${LIVE_DIRECTORY}/images/kernel_${kernel_dir}.${DISTRO_ARCH}.squashfs
			fi
			cp ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/kernel_${kernel_dir}.${DISTRO_ARCH}.squashfs ${LIVE_DIRECTORY}/images/kernel_${KERNEL_VERSION}_${kernel_dir}.${DISTRO_ARCH}.squashfs
			cp ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/boot/vmlinux.efi ${LIVE_DIRECTORY}/boot/vmlinux_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.efi
			cp ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/initramfs-squashfs.img.gz ${LIVE_DIRECTORY}/boot/initramfs_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.img.gz
			cp ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/boot/vmlinux.config ${LIVE_DIRECTORY}/boot/vmlinux_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.config
			EXTRA_KERNEL_PARM=""
			if [ -f ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/boot/boot.parm ]; then
				EXTRA_KERNEL_PARM=$(cat ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/boot/boot.parm | grep -v "^#" | head -n1)
			fi
			cat >> ${LIVE_DIRECTORY}/boot/grub/grub.cfg << EOF
menuentry '${DISTRO_NAME_CN} ${DISTRO_VERSION} ${DISTRO_ARCH_NAME_CN} (Linux ${KERNEL_VERSION}_${kernel_dir})' {
  set gfxpayload=keep
  echo '加载Linux内核……'
  linux /boot/vmlinux_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.efi LABEL=${NEW_LABEL} quiet ${EXTRA_KERNEL_PARM}
  initrd /boot/initramfs_${KERNEL_VERSION}_${kernel_dir}_${NEW_LABEL}.img.gz
  echo '加载完成，开始启动${DISTRO_NAME_CN}系统……'
}
EOF
#		echo "1 kernel_${KERNEL_VERSION}_${kernel_dir}.${DISTRO_ARCH}" >> ${LIVE_DIRECTORY}/images/images.list
		done
	else
		echo "发现编译内核的版本信息，但未找到对应的内核文件，无法继续！请检查 ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION} 目录中是否存放有内核目录。"
		exit 6
	fi
else
	echo "没有发现构建内核版本的信息，无法选择安装的内核，请确认是否完成内核的编译。"
	exit 7
fi
# sed -i "/LABEL/s@vmlinux.efi@vmlinux_${NEW_LABEL}.efi @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
# sed -i "/initrd/s@initramfs.img.gz@initramfs_${NEW_LABEL}.img.gz @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
# mv ${LIVE_DIRECTORY}/boot/vmlinux{,_${NEW_LABEL}}.efi
# mv ${LIVE_DIRECTORY}/boot/initramfs{,_${NEW_LABEL}}.img.gz

# sed -i "s@ LABEL=Sunhaiyong @ LABEL=${NEW_LABEL} @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg
echo "${NEW_LABEL}" > ${LIVE_DIRECTORY}/LABEL
# sed -i "/ quiet/s@ quiet@ quiet amdgpu.dpm=0 @g" ${LIVE_DIRECTORY}/boot/grub/grub.cfg


if [ "x${KERNEL_ONLY}" != "xTRUE" ]; then

	# 提示可能漏掉的安装包
#	 ls ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/*.squashfs | awk -F'/' '{ print $NF }' | sed -e "s@\.docs\.${DISTRO_ARCH}\.squashfs@@g" -e "s@\.devel\.${DISTRO_ARCH}\.squashfs@@g" -e "s@\.${DISTRO_ARCH}\.squashfs@@g" | sed -e "/^kernel_/d" | sort | uniq > ${NEW_TARGET_SYSDIR}/temp/all_can_install_file.temp
#	 cat ${NEW_BASE_DIR}/info_set/release_sort | grep -v "^#" | sort | uniq > ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1
#	 cat ${NEW_BASE_DIR}/info_set/release_sort | grep -v "^#" | sed "s@\$@&.update@g" |sort | uniq >> ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1

	find ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${DISTRO_NAME}/${DISTRO_VERSION}/ -maxdepth 1 -type f -name "*.squashfs" | awk -F'/' '{ print $NF }' | sed -e "s@\.${DISTRO_ARCH}\.squashfs@@g" | sed -e "/^kernel_/d" | sort | uniq > ${NEW_TARGET_SYSDIR}/temp/all_can_install_file.temp
	find ${LIVE_DIRECTORY}/images/ -maxdepth 1 -type f -name "*.squashfs" | awk -F'/' '{ print $NF }' | sed -e "s@\.${DISTRO_ARCH}\.squashfs@@g" | sed -e "/^kernel_/d" > ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1
	find ${LIVE_DIRECTORY}/images/update/ -maxdepth 1 -type f -name "*.squashfs" | awk -F'/' '{ print $NF }' | sed -e "s@\.${DISTRO_ARCH}\.squashfs@@g" | sed -e "/^kernel_/d" >> ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1
	cat ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp1 | sort | uniq > ${NEW_TARGET_SYSDIR}/temp/is_install_file.temp
	NOT_INSTALL_FILE="$(diff -Nurp ${NEW_TARGET_SYSDIR}/temp/{is_install_file,all_can_install_file}.temp | grep "^+[^+]" | sed "s@^+@@g" | tr '\n' ' ' | sed 's/ $//')"
	if [ "x${NOT_INSTALL_FILE}" != "x" ]; then
		echo -e "\e[33m发现了可能被遗漏安装的组件包： ${NOT_INSTALL_FILE}\e[0m"
	fi



	# 安装文档文件

	if [ -d ${NEW_BASE_DIR}/docs ]; then
		cp -a ${NEW_BASE_DIR}/docs ${LIVE_DIRECTORY}/ 
	fi

	# 安装发布信息文件
	if [ -f ${NEW_TARGET_SYSDIR}/logs/release_summary.txt ]; then
		echo "本次发布的${DISTRO_NAME_CN} ${DISTRO_VERSION} 版本概要如下：" > ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
		cat ${NEW_TARGET_SYSDIR}/logs/release_summary.txt >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
		echo "" >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
		echo "" >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
		echo "" >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
		echo "更加详细的软件列表及版本信息如下：" >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
		cat ${NEW_TARGET_SYSDIR}/logs/release_info.txt >> ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt

		iconv -t GBK -o ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.GBK.txt ${LIVE_DIRECTORY}/${DISTRO_NAME}_${DISTRO_VERSION}-release-info.txt
	fi

	if [ -f ${NEW_TARGET_SYSDIR}/logs/update_release_summary.txt ]; then
		echo "本次发布的${DISTRO_NAME_CN} ${DISTRO_VERSION} 更新包新增或更新内容概要如下：" > ${LIVE_DIRECTORY}/images/update/${DISTRO_NAME}_${DISTRO_VERSION}-update-release-info.txt
		cat ${NEW_TARGET_SYSDIR}/logs/update_release_summary.txt >> ${LIVE_DIRECTORY}/images/update/${DISTRO_NAME}_${DISTRO_VERSION}-update-release-info.txt
		echo "" >> ${LIVE_DIRECTORY}/images/update/${DISTRO_NAME}_${DISTRO_VERSION}-update-release-info.txt
		echo "" >> ${LIVE_DIRECTORY}/images/update/${DISTRO_NAME}_${DISTRO_VERSION}-update-release-info.txt
		echo "" >> ${LIVE_DIRECTORY}/images/update/${DISTRO_NAME}_${DISTRO_VERSION}-update-release-info.txt
		echo "更加详细的软件列表及版本信息如下：" >> ${LIVE_DIRECTORY}/images/update/${DISTRO_NAME}_${DISTRO_VERSION}-update-release-info.txt
		cat ${NEW_TARGET_SYSDIR}/logs/update_release_info.txt >> ${LIVE_DIRECTORY}/images/update/${DISTRO_NAME}_${DISTRO_VERSION}-update-release-info.txt

		iconv -t GBK -o ${LIVE_DIRECTORY}/images/update/${DISTRO_NAME}_${DISTRO_VERSION}-update-release-info.GBK.txt ${LIVE_DIRECTORY}/images/update/${DISTRO_NAME}_${DISTRO_VERSION}-update-release-info.txt
	fi

# 	echo "Live USB系统导出完成，存放在 ${LIVE_DIRECTORY} , 准备一个第一分区为VFAT格式空分区的U盘，将 ${LIVE_DIRECTORY} 目录中所有内容复制到U盘的第一分区中，该U盘即可在支持UEFI的机器上作为LiveUSB启动。"
# else
# 	echo "Live USB系统内核部分导出完成，存放在 ${LIVE_DIRECTORY} 。"
fi



function umount_temp_rawdisk
{
        sudo umount -R ${NEW_TARGET_SYSDIR}/temp/rawdisk/
        if [ "x$?" != "x0" ]; then
                echo "卸载 ${NEW_TARGET_SYSDIR}/temp/rawdisk/ 错误！"
                echo "sudo umount -R ${NEW_TARGET_SYSDIR}/temp/rawdisk/"
                exit -2
        fi
        sync
}

function convert_to_rawdisk
{
#	convert_to_rawdisk "${ARCHIVE_DIR}"

	RAWDISK_SOURCE_DIR=${1}

	pushd ${RAWDISK_SOURCE_DIR} > /dev/null
		mkdir -p ${NEW_TARGET_SYSDIR}/temp/rawdisk/
		while mount | grep "on ${NEW_TARGET_SYSDIR}/temp/rawdisk/ type " > /dev/null
		do
			echo "卸载已挂载的目录 ${NEW_TARGET_SYSDIR}/temp/rawdisk ..."
			umount_temp_rawdisk
		done
		mkdir -p ${NEW_TARGET_SYSDIR}/dist/system/rawdisk/
		ARCHIVE_DIR_USESPACE_DU="$(du -lBM -s . | awk -F'M' '{ print $1 }')"
		ARCHIVE_DIR_USESPACE_COUNT=$(expr ${ARCHIVE_DIR_USESPACE_DU} + \( \( \( ${ARCHIVE_DIR_USESPACE_DU} / 100 \) \* 8 \) + 52 \))
		if [ -f ${NEW_TARGET_SYSDIR}/dist/system/rawdisk/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.raw ]; then
			rm -f ${NEW_TARGET_SYSDIR}/dist/system/rawdisk/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.raw
		fi
		echo "正在创建虚拟磁盘文件(${ARCHIVE_DIR_USESPACE_COUNT}M)..."
		dd if=/dev/zero of=${NEW_TARGET_SYSDIR}/dist/system/rawdisk/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.raw bs=1M count=${ARCHIVE_DIR_USESPACE_COUNT} 1>/dev/null
		echo "完成。"
		echo "开始格式化为ext4文件系统..."
		/sbin/mkfs.ext4 -E root_owner=$(id -u):$(id -g) ${NEW_TARGET_SYSDIR}/dist/system/rawdisk/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.raw 1>/dev/null
		echo "完成。"
		echo -n "开始复制文件到虚拟磁盘文件中，请耐心等待..."
		sudo mount ${NEW_TARGET_SYSDIR}/dist/system/rawdisk/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.raw ${NEW_TARGET_SYSDIR}/temp/rawdisk/ 2>&1 1>/dev/null
		cp -a . ${NEW_TARGET_SYSDIR}/temp/rawdisk/
		echo "完成。"
		umount_temp_rawdisk
		echo "${NEW_TARGET_SYSDIR}/dist/system/rawdisk/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.raw 文件创建完成。"
	popd > /dev/null
}

function convert_to_vdisk
{
# 	convert_to_vdisk "${LIVE_DIRECTORY}" "${FORMAT}"

	RAWDISK_SOURCE_DIR="${1}"
	VDISK_FORMAT="${2}"

	case "${VDISK_FORMAT}" in
		qcow2)
			VDISK_CONVERT_FORMAT_STR="qcow2 -c"
			VDISK_CONVERT_SUFF="qcow2"
			;;
		vdi)
			VDISK_CONVERT_FORMAT_STR="vdi"
			VDISK_CONVERT_SUFF="vdi"
			;;
		vhdx)
			VDISK_CONVERT_FORMAT_STR="vhdx"
			VDISK_CONVERT_SUFF="vhdx"
			;;
		*)
			echo "不支持 ${VDISK_FORMAT} 磁盘文件格式，将使用默认的 qcow2 格式。"
			VDISK_CONVERT_FORMAT_STR="qcow2 -c"
			VDISK_CONVERT_SUFF="qcow2"
			;;
	esac

	convert_to_rawdisk "${1}"

	echo "正在创建 ${VDISK_FORMAT} 格式的磁盘文件..."
	${HOST_TOOLS_DIR}/bin/qemu-img convert -f raw -O ${VDISK_CONVERT_FORMAT_STR} ${NEW_TARGET_SYSDIR}/dist/system/rawdisk/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.raw ${NEW_TARGET_SYSDIR}/dist/system/rawdisk/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.${VDISK_CONVERT_SUFF} -p
	if [ "x$?" == "x0" ]; then
		echo "${VDISK_FORMAT} 磁盘文件创建成功：${NEW_TARGET_SYSDIR}/dist/system/rawdisk/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.${VDISK_CONVERT_SUFF}"
	else
		echo "${VDISK_FORMAT} 磁盘文件创建失败。"
	fi
}


case "x${DISTRO_ARCHIVE_MODE}" in
	xdir)
		if [ "x${KERNEL_ONLY}" != "xTRUE" ]; then
			echo "Live USB系统导出完成，存放在 ${LIVE_DIRECTORY} , 准备一个第一分区为VFAT格式空分区的U盘，将 ${LIVE_DIRECTORY} 目录中所有内容复制到U盘的第一分区中，该U盘即可在支持UEFI的机器上作为LiveUSB启动。"
		else
			echo "Live USB系统内核部分导出完成，存放在 ${LIVE_DIRECTORY} 。"
		fi
		;;
	xtar*)
		ARCHIVE_TAR_FORMAT="--zstd"
		ARCHIVE_TAR_SUFF="zst"
		case "${DISTRO_ARCHIVE_MODE}" in
			tar.gz )
                                ARCHIVE_TAR_FORMAT="--gzip"
				ARCHIVE_TAR_SUFF="gz"
				;;
			tar.xz )
                                ARCHIVE_TAR_FORMAT="--xz"
				ARCHIVE_TAR_SUFF="xz"
				;;
			tar | tar.zst)
                                ARCHIVE_TAR_FORMAT="--zstd"
				ARCHIVE_TAR_SUFF="zst"
				;;
			tar.lzma)
                                ARCHIVE_TAR_FORMAT="--lzma"
				ARCHIVE_TAR_SUFF="lzma"
				;;
			tar.lz4)
                                ARCHIVE_TAR_FORMAT="--lzip"
				ARCHIVE_TAR_SUFF="lz4"
				;;
			tar.lzo)
                                ARCHIVE_TAR_FORMAT="--lzop"
				ARCHIVE_TAR_SUFF="lzo"
				;;
			*)
				echo "尚未支持“${DISTRO_ARCHIVE_MODE}”的创建方式。"
				exit 5
				;;
		esac
		mkdir -p ${NEW_TARGET_SYSDIR}/dist/system/tar/
		echo -n "开始进行压缩..."
		tar --checkpoint=2000 --checkpoint-action=dot --xattrs-include='*' --owner=root --group=root ${ARCHIVE_TAR_FORMAT} -caf ${NEW_TARGET_SYSDIR}/dist/system/tar/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.tar.${ARCHIVE_TAR_SUFF} ${LIVE_DIRECTORY}/*
		echo "完成！"
		echo "正在生成校验文件..."
		pushd ${NEW_TARGET_SYSDIR}/dist/system/tar/ >/dev/null
			md5sum ${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.tar.${ARCHIVE_TAR_SUFF} > ${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.tar.${ARCHIVE_TAR_SUFF}.md5sum
		popd > /dev/null
		echo "Live 系统压缩文件存放在: ${NEW_TARGET_SYSDIR}/dist/system/tar/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.tar.${ARCHIVE_TAR_SUFF}"
		echo "Live 系统压缩文件md5校验文件存放在: ${NEW_TARGET_SYSDIR}/dist/system/tar/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.tar.${ARCHIVE_TAR_SUFF}.md5sum"
		;;
	xiso)
		mkdir -p ${NEW_TARGET_SYSDIR}/dist/system/iso/
		${HOST_TOOLS_DIR}/bin/xorriso -as mkisofs -iso-level 3 -full-iso9660-filenames -volid "${DISTRO_NAME}-${DISTRO_VERSION}" -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info -uid 0 -gid 0 -output ${NEW_TARGET_SYSDIR}/dist/system/iso/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.iso ${LIVE_DIRECTORY}/
		echo "正在生成校验文件..."
		pushd ${NEW_TARGET_SYSDIR}/dist/system/iso/ >/dev/null
			md5sum ${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.iso > ${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.iso.md5sum
		popd > /dev/null
		echo "Live 系统ISO文件存放在: ${NEW_TARGET_SYSDIR}/dist/system/iso/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.iso"
		echo "Live 系统ISO文件md5校验文件存放在: ${NEW_TARGET_SYSDIR}/dist/system/iso/${DISTRO_NAME}-${DISTRO_VERSION}-$(date +%Y%m%d).${DISTRO_ARCH}.iso.md5sum"
		;;
	xrawdisk)
		convert_to_rawdisk "${LIVE_DIRECTORY}"
# 		echo "尚未支持"
		;;
	xvdisk*)
		case "${DISTRO_ARCHIVE_MODE}" in
			vdisk.qcow2 | vdisk )
				convert_to_vdisk "${LIVE_DIRECTORY}" "qcow2"
				;;
			vdisk.vdi )
				convert_to_vdisk "${LIVE_DIRECTORY}" "vdi"
				;;
			vdisk.vhdx)
				convert_to_vdisk "${LIVE_DIRECTORY}" "vhdx"
				;;
			*)
				echo "尚未支持“${DISTRO_ARCHIVE_MODE}”格式的虚拟磁盘创建。"
				exit 3
				;;
		esac
		;;
	*)
		echo "不支持 ${DISTRO_ARCHIVE_MODE} 打包模式，请设置 dir 、tar 、iso 、rawdisk 其中指一 。"
		exit 3
		;;
esac
