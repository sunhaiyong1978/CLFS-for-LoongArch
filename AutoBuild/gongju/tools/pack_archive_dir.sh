#!/bin/bash

#使用示例：tools/pack_archive_dir.sh ${BASE_DIR}/workbase/overlaydir_strip/sysroot "sysroot" squashfs xz Yongbao 1.0 loongarch64

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

export ARCHIVE_STEP_NAME=""
export ARCHIVE_DIR=""


declare FORCE_CREATE=FALSE
declare ARCHIVE_PKG_SET_NAME="foo"
declare WORLD_PARM=""

while getopts 'fwn:h' OPT; do
    case $OPT in
        f)
            FORCE_CREATE=TRUE
            ;;
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
#	    echo "强制指定使用主线环境中进行打包。"
	    ;;
	n)
	    ARCHIVE_PKG_SET_NAME=$OPTARG
	    ;;
        h|?)
            echo "用法: `basename $0` [选项] 需打包目录 打包方式 文件格式 发行版名称 发行版版本 架构名称"
	    echo ""
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
	    echo "    -w: 强制在主线环境中进行打包，不指定该参数将使用 current_branch 指定的分支环境中进行打包，若不存在 current_branch 文件则默认对主线环境进行打包。"
	    echo "    -n: 设置打包文件的保存名称，该参数仅在第4个参数设置为 "pkg" 时才有效。"
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
		else
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
	echo "没有指定需要打包的目录。"
	exit 1
fi
ARCHIVE_DIR="${1}"

if [ "x${2}" == "x" ]; then
	echo "没有指定步骤名称!"
	exit 2
fi
ARCHIVE_STEP_NAME="${2}"

if [ "x${3}" == "x" ]; then
	echo "没有指定打包模式!"
	exit 3
fi
ARCHIVE_MODE="${3}"

if [ "x${4}" == "x" ]; then
	ARCHIVE_COMP_FORMAT="xz"
else
	ARCHIVE_COMP_FORMAT="${4}"
fi

if [ "x${ARCHIVE_MODE}" != "xpkg" ]; then
	if [ "x${5}" == "x" ]; then
		echo "没有指定发行版名称!"
		exit 5
	fi
	ARCHIVE_OS_NAME="${5}"

	if [ "x${6}" == "x" ]; then
		echo "没有指定发行版版本!"
		exit 6
	fi
	ARCHIVE_OS_VERSION="${6}"

	if [ "x${7}" == "x" ]; then
		echo "没有指定指令集架构!"
		exit 7
	fi
	ARCHIVE_ARCH_NAME="${7}"
fi

if [ "x${ARCHIVE_MODE}" == "xpkg" ]; then
	if [ "x${ARCHIVE_PKG_SET_NAME}" == "x" ] || [ "x${ARCHIVE_PKG_SET_NAME}" == "xfoo" ]; then
		ARCHIVE_PKG_SET_NAME="foo-$(date +%N)"
		echo "打包模式设置为 pkg 时，但没有使用 -n 参数指定打包文件的名称，将使用 ${ARCHIVE_PKG_SET_NAME} 作为临时名称。"
	fi
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

case "${ARCHIVE_MODE}" in
	tar | squashfs )
		case "${ARCHIVE_COMP_FORMAT}" in
			xz | zstd | gzip | lzma )
				ARCHIVE_SQUASHFS_FORMAT="${ARCHIVE_COMP_FORMAT}"
				ARCHIVE_TAR_FORMAT="--${ARCHIVE_COMP_FORMAT}"
				;;
			lz4)
				ARCHIVE_SQUASHFS_FORMAT="${ARCHIVE_COMP_FORMAT}"
				ARCHIVE_TAR_FORMAT="--lzip"
				;;
			lzo)
				ARCHIVE_SQUASHFS_FORMAT="${ARCHIVE_COMP_FORMAT}"
				ARCHIVE_TAR_FORMAT="--lzop"
				;;
			none)
				ARCHIVE_SQUASHFS_FORMAT="xz"
				ARCHIVE_TAR_FORMAT="--xz"
				;;
			*)
				echo "指定的压缩格式 "${ARCHIVE_COMP_FORMAT}" 无法识别，将使用默认的 xz 压缩格式。"
				ARCHIVE_SQUASHFS_FORMAT="xz"
				ARCHIVE_TAR_FORMAT="--xz"
				;;
		esac

		case "${ARCHIVE_COMP_FORMAT}" in
			xz | lzma | lz4 | lzo)
				ARCHIVE_TAR_SUFF="${ARCHIVE_COMP_FORMAT}"
				;;
			zstd)
				ARCHIVE_TAR_SUFF="zst"
				;;
			gzip)
				ARCHIVE_TAR_SUFF="gz"
				;;
			*)
				ARCHIVE_TAR_SUFF="xz"
				;;
		esac
		;;
	merge | clearmerge | rawdisk)
		ARCHIVE_SQUASHFS_FORMAT="xz"
		ARCHIVE_TAR_FORMAT="--xz"
		;;
	vdisk)
		case "${ARCHIVE_COMP_FORMAT}" in
			qcow2 | vdi | vhdx)
				;;
			*)
				echo "指定的磁盘格式 "${ARCHIVE_COMP_FORMAT}" 无法识别，将使用默认的qcow2格式。"
				;;
		esac
		;;
	pkg)
		case "${ARCHIVE_COMP_FORMAT}" in
			tar.gz)
				ARCHIVE_TAR_FORMAT="--gzip"
				ARCHIVE_TAR_SUFF="gz"
				;;
			tar | tar.xz )
				ARCHIVE_TAR_FORMAT="--xz"
				ARCHIVE_TAR_SUFF="xz"
				;;
			tar.zst)
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
				echo "指定的打包格式 "${ARCHIVE_COMP_FORMAT}" 无法识别，将使用默认的tar进行打包。"
				ARCHIVE_TAR_FORMAT="--xz"
				ARCHIVE_TAR_SUFF="xz"
				;;
		esac
		;;
	*)
		echo "不支持 ${ARCHIVE_MODE} 的打包模式。"
		exit 7
		;;
esac


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
		mkdir -p ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/
		ARCHIVE_DIR_USESPACE_DU="$(du -lBM -s . | awk -F'M' '{ print $1 }')"
		ARCHIVE_DIR_USESPACE_COUNT=$(expr ${ARCHIVE_DIR_USESPACE_DU} + \( \( \( ${ARCHIVE_DIR_USESPACE_DU} / 100 \) \* 8 \) + 52 \))
		if [ -f ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.raw ]; then
			rm -f ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.raw
		fi
		echo "正在创建虚拟磁盘文件(${ARCHIVE_DIR_USESPACE_COUNT}M)..."
		dd if=/dev/zero of=${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.raw bs=1M count=${ARCHIVE_DIR_USESPACE_COUNT} 1>/dev/null
		echo "完成。"
		echo "开始格式化为ext4文件系统..."
		/sbin/mkfs.ext4 -E root_owner=$(id -u):$(id -g) ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.raw 1>/dev/null
		echo "完成。"
		echo -n "开始复制文件到虚拟磁盘文件中，请耐心等待..."
# 		fuse2fs ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.raw ${NEW_TARGET_SYSDIR}/temp/rawdisk/ 2>&1 1>/dev/null
		sudo mount ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.raw ${NEW_TARGET_SYSDIR}/temp/rawdisk/ 2>&1 1>/dev/null
		cp -a . ${NEW_TARGET_SYSDIR}/temp/rawdisk/
#  		rsync -ah --progress --chown=root:root . ${NEW_TARGET_SYSDIR}/temp/rawdisk/
		echo "完成。"
		umount_temp_rawdisk
		echo "${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.raw 文件创建完成。"
	popd > /dev/null
}

function convert_to_vdisk
{
# 	convert_to_vdisk "${ARCHIVE_DIR}" "${FORMAT}"

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

# 	echo "${HOST_TOOLS_DIR}/bin/qemu-img convert -f raw -O ${VDISK_CONVERT_FORMAT_STR} ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.raw ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.${VDISK_CONVERT_SUFF} -p"
	echo "正在创建 ${VDISK_FORMAT} 格式的磁盘文件..."
	${HOST_TOOLS_DIR}/bin/qemu-img convert -f raw -O ${VDISK_CONVERT_FORMAT_STR} ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.raw ${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.${VDISK_CONVERT_SUFF} -p
	if [ "x$?" == "x0" ]; then
		echo "${VDISK_FORMAT} 磁盘文件创建成功：${NEW_TARGET_SYSDIR}/dist/os/rawdisk/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.${VDISK_CONVERT_SUFF}"
	else
		echo "${VDISK_FORMAT} 磁盘文件创建失败。"
	fi
}


if [ -d ${ARCHIVE_DIR} ]; then
	case "${ARCHIVE_MODE}" in
		squashfs)
			echo "正在使用 ${ARCHIVE_MODE} 方式打包 ${ARCHIVE_DIR} 目录中的文件..."
			if [ -f /usr/bin/mksquashfs ]; then
				MKSQUASHFS=/usr/bin/mksquashfs
			fi
			if [ -f /sbin/mksquashfs ]; then
				MKSQUASHFS=/sbin/mksquashfs
			fi
			mkdir -p ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/
			if [ ! -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs ] || [ "x${FORCE_CREATE}" == "xTRUE" ]; then
				rm -f ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs
				${MKSQUASHFS} ${ARCHIVE_DIR} ${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs -all-root -comp ${ARCHIVE_SQUASHFS_FORMAT}
				echo ""
				echo "${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs 文件创建完成。"
			else
				echo "${NEW_TARGET_SYSDIR}/dist/os/squashfs/${ARCHIVE_OS_NAME}/${ARCHIVE_OS_VERSION}/${ARCHIVE_STEP_NAME}.${ARCHIVE_ARCH_NAME}.squashfs 文件已创建。"
			fi
			;;
		tar)
			echo "正在使用 ${ARCHIVE_MODE} 方式打包 ${ARCHIVE_DIR} 目录中的文件..."
			pushd ${ARCHIVE_DIR} > /dev/null
			mkdir -p ${NEW_TARGET_SYSDIR}/dist/os/tar/
			if [ ! -f ${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.${ARCHIVE_TAR_SUFF} ] || [ "x${FORCE_CREATE}" == "xTRUE" ]; then
				rm -f ${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.${ARCHIVE_TAR_SUFF}
				tar --checkpoint=200 --checkpoint-action=dot --xattrs-include='*' --owner=root --group=root ${ARCHIVE_TAR_FORMAT} -caf ${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.${ARCHIVE_TAR_SUFF} *
				echo ""
				echo "${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.${ARCHIVE_TAR_SUFF} 文件创建完成。"
			else
				echo "${NEW_TARGET_SYSDIR}/dist/os/tar/${ARCHIVE_ARCH_NAME}-${ARCHIVE_OS_NAME}-${ARCHIVE_OS_VERSION}-${ARCHIVE_STEP_NAME}.tar.${ARCHIVE_TAR_SUFF} 文件已创建。"
			fi
			popd > /dev/null
			;;
		pkg)
			echo "对 ${ARCHIVE_DIR} 目录中的文件进行打包..."
			pushd ${ARCHIVE_DIR} > /dev/null
				case "${ARCHIVE_COMP_FORMAT}" in
					tar* | *)
						# 默认使用 tar 进行打包。
						mkdir -p ${NEW_TARGET_SYSDIR}/dist/pkgs/tar/
						if [ ! -f ${NEW_TARGET_SYSDIR}/dist/pkgs/tar/${ARCHIVE_PKG_SET_NAME}.tar.${ARCHIVE_TAR_SUFF} ] || [ "x${FORCE_CREATE}" == "xTRUE" ]; then
							tar --checkpoint=200 --checkpoint-action=dot --xattrs-include='*' --owner=root --group=root ${ARCHIVE_TAR_FORMAT} -caf ${NEW_TARGET_SYSDIR}/dist/pkgs/tar/${ARCHIVE_PKG_SET_NAME}.tar.${ARCHIVE_TAR_SUFF} *
							echo ""
							echo "${NEW_TARGET_SYSDIR}/dist/pkgs/tar/${ARCHIVE_PKG_SET_NAME}.tar.${ARCHIVE_TAR_SUFF} 文件创建完成。"
						else
							echo "${NEW_TARGET_SYSDIR}/dist/pkgs/tar/${ARCHIVE_PKG_SET_NAME}.tar.${ARCHIVE_TAR_SUFF} 文件已创建。"
						fi
						;;
				esac
			popd > /dev/null
			;;
		vdisk)
			echo "正在使用 ${ARCHIVE_MODE} 方式打包 ${ARCHIVE_DIR} 目录中的文件..."
			convert_to_vdisk "${ARCHIVE_DIR}" "${ARCHIVE_COMP_FORMAT}"
			;;
		rawdisk)
			echo "正在使用 ${ARCHIVE_MODE} 方式打包 ${ARCHIVE_DIR} 目录中的文件..."
			convert_to_rawdisk "${ARCHIVE_DIR}"
			;;
		merge)
			echo "正在将 ${ARCHIVE_DIR} 目录内容合并到 ${NEW_TARGET_SYSDIR}/dist/merge/img/ 目录中..."
			cp -a ${ARCHIVE_DIR}/* ${NEW_TARGET_SYSDIR}/dist/merge/img/
			;;
		clearmerge)
			echo "删除 ${NEW_TARGET_SYSDIR}/dist/merge/img/ 目录，并重建。"
			if [ -d ${NEW_TARGET_SYSDIR}/dist/merge/img/ ]; then
				chmod a+w -R ${NEW_TARGET_SYSDIR}/dist/merge/img/
				rm -rf ${NEW_TARGET_SYSDIR}/dist/merge/img/
			fi
			mkdir -p ${NEW_TARGET_SYSDIR}/dist/merge/img/
			;;
		*)
			echo "不支持 ${ARCHIVE_MODE} 的打包模式。"
			exit 7
			;;
	esac

	pushd ${ARCHIVE_DIR} > /dev/null
		
	popd > /dev/null
else
	echo "没有找到 ${ARCHIVE_DIR} 目录，请检查是否指定了正确的路径。"
fi
