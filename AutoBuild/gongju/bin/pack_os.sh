#!/bin/bash -e

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

declare FORCE_CREATE=FALSE
declare ARCHIVE_MODE="squashfs"
declare ARCHIVE_COMP_FORMAT="xz"
declare OVERLAY_NAME=""
declare KERNEL_CREATE=TRUE
declare KERNEL_ONLY=FALSE
declare HAVE_KERNEL=FALSE
declare HAVE_PKGS=FALSE
declare ALL_IN_ONE=FALSE
declare WORLD_PARM=""

while getopts 'fkpaA:m:c:wh' OPT; do
    case $OPT in
        f)
            FORCE_CREATE=TRUE
            ;;
        k)
            KERNEL_ONLY=TRUE
            HAVE_KERNEL=TRUE
            ;;
	p)
	    HAVE_PKGS=TRUE
	    ;;
	a)
	    ALL_IN_ONE=TRUE
	    ;;
	A)
	    ALL_IN_ONE=TRUE
	    ALL_IN_ONE_DIR=$OPTARG
	    ;;
	m)
            ARCHIVE_MODE=$OPTARG
            ;;
	c)
	    ARCHIVE_COMP_FORMAT=$OPTARG
	    ;;
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    echo "强制指定使用主线环境中进行打包。"
	    ;;
        h|?)
            echo "用法: `basename $0` [选项] [目标名,目标名...]"
            echo "目录名: "
            echo -n "    目前可用的目录名有: "
            for i in $(cat ${NEW_BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
            do
                   echo -n "${i} "
            done
            echo "    不指定目录名将处理所有的目录。"
            echo ""
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
            echo "    -f: 将原有已经完成的打包文件进行重命名，并重新进行目标的打包工作。"
            echo "    -k: 该参数表示处理的目标涵盖内核，当存在指定“[目标名]”时，若指定目标名不在overlaydir_strip中，则将尝试查寻对应名称的内核名，若不指定任何“[目标名]”的情况下将对所有找到的内核进行下一步的处理。"
	    echo "    -p: 该参数标识处理的目标涵盖独立软件包，该参数仅当指定了“[目标名]”时才有效，“[目标名]”在overlaydir_strip和内核名中都不存在时，将继续查寻独立软件包的名称，对符合名字的软件包进行进一步的处理，不指定该参数则不会搜索符合名称的独立软件包。"
	    echo "    -a: 指定该参数后，对所有要处理的 “[目标名]” 中的文件合并到一起，以备进行下一步的处理，合并后的命名将自动设置，如需指定名称请时用 -A <名称> 参数。"
	    echo "    -A <名称>: 该参数需要指定一个名称，该名称是对所有要处理的 “[目标名]” 中的文件合并到一起后的名称，该参数设置后将自动设置 -a 参数。"
            echo "    -m <模式名>: 设置打包模式，目前可用的打包模式名有 squashfs、tar、merge 和 rawdisk 。"
	    echo "    -c <压缩格式>: 设置打包时使用的压缩格式，目前可以指定的压缩格式有 gzip、xz、zstd、lz4 和 lzo。"
	    echo "    -w: 强制在主线环境中进行打包，不指定该参数将使用 current_branch 指定的分支环境中进行打包，若不存在 current_branch 文件则默认对主线环境进行打包。"

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
			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行打包。"
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


case "x${ARCHIVE_MODE}" in
	xsquashfs | xtar | xrawdisk | xmerge | xvdisk)
		;;
	*)
		echo "${ARCHIVE_MODE} 打包模式指定错误，目前只支持 squashfs 、 tar 、 merge 和 rawdisk 模式。"
		exit 1
		;;
esac

case "x${ARCHIVE_MODE}" in
        xsquashfs | xtar )
		case "x${ARCHIVE_COMP_FORMAT}" in
			xgzip | xxz | xzstd | xlz4 | xlzo )
				;;
			*)
				echo "${ARCHIVE_COMP_FORMAT} 压缩格式指定错误，目前只支持 gzip、xz、zstd、lz4 和 lzo 格式。"
				exit 1
				;;
		esac
		;;
	vdisk)
		case "${ARCHIVE_COMP_FORMAT}" in
			qcow2 | vdi | vhdx)
				;;
			*)
				echo "${ARCHIVE_COMP_FORMAT} 格式指定错误，目前只支持 qcow2、vdi 、vhdx 格式。"
				;;
		esac
		;;
	*)
		;;
esac

SAVE_ARCHIVE_MODE="${ARCHIVE_MODE}"

if [ "x${ALL_IN_ONE}" == "xTRUE" ]; then
	ARCHIVE_MODE="merge"
fi

if [ "x${1}" != "x" ]; then
	OVERLAY_NAME_ALL="${1}"
fi


#				DISTRO_NAME=$(grep -r "^DISTRO_NAME=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
#				if [ "x${DISTRO_NAME}" == "x" ]; then
#					echo "无法获取操作系统名称，无法继续，请编辑env/distro.info文件，并增加DISTRO_NAME的定义。"
#					exit 3
#				fi
#				DISTRO_ARCH=$(grep -r "^DISTRO_ARCH=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
#				if [ "x${DISTRO_ARCH}" == "x" ]; then
#					echo "缺少架构名称，无法继续，请编辑env/distro.info文件，并增加DISTRO_ARCH的定义。"
#					exit 3
#				fi
#				DISTRO_VERSION=$(grep -r "^DISTRO_VERSION=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
#				if [ "x${DISTRO_VERSION}" == "x" ]; then
#					echo "缺少系统的版本号，无法继续，请编辑env/distro.info文件，并增加DISTRO_VERSION的定义。"
#					exit 3
#				fi
#				if [ "x${ARCHIVE_MODE}" == "x" ]; then
#					ARCHIVE_MODE=$(grep -r "^DISTRO_ARCHIVE_MODE=" env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
#					if [ "x${ARCHIVE_MODE}" == "x" ]; then
#						ARCHIVE_MODE=$(grep -r "^DEFAULT=" env/archive | tail -n1 | awk -F'=' '{ print $2 }')
#						if [ "x${ARCHIVE_MODE}" == "x" ]; then
#							echo "缺少打包系统方式的设置，请编辑env/distro.info文件，并增加DISTRO_ARCHIVE_MODE的定义,当前将默认设置为squashfs。"
#							ARCHIVE_MODE=squashfs
#						fi
#					fi
#				fi


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
if [ "x${ARCHIVE_MODE}" == "x" ]; then
	ARCHIVE_MODE=$(grep -r "^DISTRO_ARCHIVE_MODE=" ${NEW_BASE_DIR}/env/distro.info | tail -n1 | awk -F'=' '{ print $2 }')
	if [ "x${ARCHIVE_MODE}" == "x" ]; then
		ARCHIVE_MODE=$(grep -r "^DEFAULT=" ${NEW_BASE_DIR}/env/archive | tail -n1 | awk -F'=' '{ print $2 }')
		if [ "x${ARCHIVE_MODE}" == "x" ]; then
			echo "缺少打包系统方式的设置，请编辑 ${NEW_BASE_DIR}/env/distro.info 文件，并增加DISTRO_ARCHIVE_MODE的定义,当前将默认设置为squashfs。"
			ARCHIVE_MODE=squashfs
		fi
	fi
fi

if [ "x${ARCHIVE_MODE}" == "xmerge" ]; then
	tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_TARGET_SYSDIR}/build "clear_merge" "clearmerge" "none" "${DISTRO_NAME}" "${DISTRO_VERSION}" "${DISTRO_ARCH}"
fi

if [ "x${OVERLAY_NAME_ALL}" == "x" ]; then
	if [ "x${KERNEL_CREATE}" == "xTRUE" ]; then
		KERNEL_VERSION=$(cat ${NEW_TARGET_SYSDIR}/common_files/linux-kernel.version)
		if [ "x${KERNEL_VERSION}" != "x" ]; then
        		KERNEL_LIST="$(ls ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION})"
			if [ "x$?" == "x0" ] && [ "x${KERNEL_LIST}" != "x" ]; then
				for kernel_dir in $(ls ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION})
				do
					echo "正在处理 ${kernel_dir} 内核..."
					if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
						tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/img "kernel_${kernel_dir}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						if [ "x${ALL_IN_ONE}" == "xTRUE" ]; then
							tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/merge_boot "kernel_${kernel_dir}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						fi
					else
						tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/img "kernel_${kernel_dir}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						if [ "x${ALL_IN_ONE}" == "xTRUE" ]; then
							tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${kernel_dir}/merge_boot "kernel_${kernel_dir}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						fi
					fi
				done
			else
                		echo "发现编译内核的版本信息，但未找到对应的内核文件，无法继续！请检查 ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION} 目录中是否存放有内核目录。"
		                exit 6
        		fi
		else
			echo "没有发现构建内核版本的信息，无法打包内核，请确认是否完成内核的编译。"
			exit 7
		fi
	fi
	if [ "x${KERNEL_ONLY}" == "xFALSE" ]; then
		if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip ]; then
			OVERLAY_DIR_LIST=$(find ${NEW_BASE_DIR}/workbase/overlaydir/ -maxdepth 1 -type f -name "*.dist" | awk -F'/' '{ print $NF }' | sed "s@\.dist\$@@g")
			if [ "x${OVERLAY_DIR_LIST}" == "x" ]; then
				echo "没有发现任何需要进行处理的目录。"
				exit 1
			fi

#			for i in $(cat ${NEW_BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
			for i in ${OVERLAY_DIR_LIST}
			do
				RELEASE_SUFF=""
				if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${i}.released ]; then
					RELEASE_SUFF=".update"
				fi
				echo "正在处理 ${i}${RELEASE_SUFF} 中的文件..."
				if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} ]; then
	
					STEP_NAME=""
					if [ -f ${NEW_BASE_DIR}/env/${i}.info ]; then
						STEP_NAME=$(grep -r "^$i_NAME=" ${NEW_BASE_DIR}/env/${i}.info | tail -n1 | awk -F'=' '{ print $2 }')
					fi
					if [ "x${STEP_NAME}" == "x" ]; then
						STEP_NAME=${i}
					fi

					if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
						tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} "${STEP_NAME}${RELEASE_SUFF}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${i}.split | awk -F' ' '{ print $1 }' | sort | uniq)
						do
							if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j ]; then
								tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j "${STEP_NAME}${RELEASE_SUFF}.$j" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
							fi
						done
					else
						tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF} "${STEP_NAME}${RELEASE_SUFF}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${i}.split | awk -F' ' '{ print $1 }' | sort | uniq)
						do
							if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j ]; then
								tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j "${STEP_NAME}${RELEASE_SUFF}.$j" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
							fi
						done
					fi
				else
					echo "警告：${NEW_BASE_DIR}/workbase/overlaydir_strip/ 目录中没有 $i${RELEASE_SUFF} 目录，跳过！"
				fi
			done
		else
			echo "没有发现可以用来打包的系统目录，请检查${NEW_BASE_DIR}/workbase/overlaydir_strip目录是否存在，你可以通过strip_os.sh脚本生成该目录。"
			exit 1
		fi
		YONGBAO_MERGE_NAME="merge_all";
	fi
else
# 	for OVERLAY_NAME in $(echo ${OVERLAY_NAME_ALL} | tr ',' ' ')
# 	do
# 		if [ "x${KERNEL_ONLY}" == "xTRUE" ]; then
# 			KERNEL_VERSION=$(cat ${NEW_TARGET_SYSDIR}/common_files/linux-kernel.version)
# 			if [ "x${KERNEL_VERSION}" != "x" ]; then
# 				if [ -d ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME} ]; then
# 					echo "打包 ${OVERLAY_NAME} 内核..."
# 					if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
# 						tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME}/img "kernel_${OVERLAY_NAME}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
# 					else
# 						tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME}/img "kernel_${OVERLAY_NAME}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
# 					fi
# 				else
# 					echo "没有发现 ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME} 目录，不能对${OVERLAY_NAME} 内核进行打包。"
# # 		        	        exit 6
# 	        		fi
# 			else
# 				echo "没有发现构建内核版本的信息，无法打包内核，请确认是否完成内核的编译。"
# 				exit 7
# 			fi
# 			exit 0
# 		fi
# 	done

	YONGBAO_MERGE_NAME="merge";
	for NAME_STR in $(echo ${OVERLAY_NAME_ALL} | tr ',' ' ')
	do
		OVERLAY_NAME=$(echo ${NAME_STR} | awk -F':' '{ print $1}')
		NAME_VERSION=$(echo ${NAME_STR} | awk -F':' '{ print $2}')
		if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME} ]; then
			RELEASE_SUFF=""
			if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${i}.released ]; then
				RELEASE_SUFF=".update"
			fi
			echo "正在处理 ${OVERLAY_NAME}${RELEASE_SUFF} 中的文件..."
			if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} ]; then

				STEP_NAME=""
				if [ -f ${NEW_BASE_DIR}/env/${OVERLAY_NAME}.info ]; then
					STEP_NAME=$(grep -r "^${OVERLAY_NAME}_NAME=" ${NEW_BASE_DIR}/env/${OVERLAY_NAME}.info | tail -n1 | awk -F'=' '{ print $2 }')
				fi
				if [ "x${STEP_NAME}" == "x" ]; then
					STEP_NAME=${OVERLAY_NAME}
				fi

				if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
					tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} "${STEP_NAME}${RELEASE_SUFF}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
					if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split ]; then
						for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split | awk -F' ' '{ print $1 }' | sort | uniq)
						do
							if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j ]; then
								tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j "${STEP_NAME}${RELEASE_SUFF}.$j" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
							fi
						done
					fi
				else
					tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} "${STEP_NAME}${RELEASE_SUFF}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
					if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split ]; then
						for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split | awk -F' ' '{ print $1 }' | sort | uniq)
						do
							if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j ]; then
								tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j "${STEP_NAME}${RELEASE_SUFF}.$j" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
							fi
						done
					fi
				fi
				YONGBAO_MERGE_NAME="${YONGBAO_MERGE_NAME}_${OVERLAY_NAME}"
				continue;
			else
				echo "${NEW_BASE_DIR}/workbase/overlaydir_strip 中没有发现 ${OVERLAY_NAME}${RELEASE_SUFF} 目录，跳过。"
			fi
		fi

		if [ "x${HAVE_KERNEL}" == "xTRUE" ]; then
			KERNEL_VERSION=$(cat ${NEW_TARGET_SYSDIR}/common_files/linux-kernel.version)
			if [ "x${KERNEL_VERSION}" != "x" ]; then
				if [ -d ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME} ]; then
					echo "正在处理 ${OVERLAY_NAME} 内核..."
					if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
						tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME}/img "kernel_${OVERLAY_NAME}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						if [ "x${ALL_IN_ONE}" == "xTRUE" ]; then
							tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME}/merge_boot "kernel_${OVERLAY_NAME}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						fi
					else
						tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME}/img "kernel_${OVERLAY_NAME}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						if [ "x${ALL_IN_ONE}" == "xTRUE" ]; then
							tools/pack_archive_dir.sh ${WORLD_PARM} ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME}/merge_boot "kernel_${OVERLAY_NAME}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
						fi
					fi
					YONGBAO_MERGE_NAME="${YONGBAO_MERGE_NAME}_${OVERLAY_NAME}"
					continue;
				else
					echo "即没有在 ${NEW_BASE_DIR}/workbase/overlaydir_strip 中没有发现 ${OVERLAY_NAME}${RELEASE_SUFF} 目录，也没有发现 ${NEW_TARGET_SYSDIR}/dist/os/linux-kernel/${KERNEL_VERSION}/${OVERLAY_NAME} 目录，不能对指定的 ${OVERLAY_NAME} 进行打包。"
	        		fi
			else
				echo "没有在 ${NEW_BASE_DIR}/workbase/overlaydir_strip 中没有发现 ${OVERLAY_NAME}${RELEASE_SUFF} 目录，也没有发现任何构建内核版本的信息，无法打包 ${OVERLAY_NAME} ，请确认是否完成内核的编译。"
			fi
		fi

		if [ "x${HAVE_PKGS}" == "xTRUE" ]; then
			if [ "x${NAME_VERSION}" == "x" ]; then
				if [ -d ${BASE_DIR}/import_pkgs/${OVERLAY_NAME} ]; then
					for j in foo $(find ${BASE_DIR}/import_pkgs/${OVERLAY_NAME}/ -mindepth 1 -maxdepth 1 -type d)
					do
						GET_PKG_VERSION=$(echo "$(basename ${j})" | grep -v "_bak\." | grep -v "foo" | sort -V  | tail -n1)
						if [ "x${GET_PKG_VERSION}" != "x" ]; then
							if [ "x${ALL_IN_ONE}" == "xTRUE" ]; then
								tools/pack_archive_dir.sh ${WORLD_PARM} ${BASE_DIR}/import_pkgs/${OVERLAY_NAME}/${GET_PKG_VERSION}/root "${OVERLAY_NAME}-${NAME_VERSION}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
							fi
						fi
					done
				fi
			else
				if [ -d ${BASE_DIR}/import_pkgs/${OVERLAY_NAME}/${NAME_VERSION} ]; then
					if [ "x${ALL_IN_ONE}" == "xTRUE" ]; then
						tools/pack_archive_dir.sh ${WORLD_PARM} -f ${BASE_DIR}/import_pkgs/${OVERLAY_NAME}/${NAME_VERSION}/root "${OVERLAY_NAME}-${NAME_VERSION}" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
					fi
				fi
			fi
			continue;
		fi


#		if [ "x${OVERLAY_NAME}" != "x" ]; then
#			if [ "x${i}" != "x${OVERLAY_NAME}" ]; then
#				continue
#			fi
#		fi
	done
fi


if [ "x${ALL_IN_ONE}" == "xTRUE" ]; then
	ARCHIVE_MODE=${SAVE_ARCHIVE_MODE}

	case "x${ARCHIVE_MODE}" in
		xsquashfs | xtar | xrawdisk | xvdisk)
			tools/pack_archive_dir.sh ${WORLD_PARM} -f ${NEW_TARGET_SYSDIR}/dist/merge/img "${YONGBAO_MERGE_NAME}_custom" ${ARCHIVE_MODE} ${ARCHIVE_COMP_FORMAT} ${DISTRO_NAME} ${DISTRO_VERSION} ${DISTRO_ARCH}
			;;
		xmerge)
			echo "合并后的目录在 ${NEW_TARGET_SYSDIR}/dist/merge/img "
			;;
		*)
			echo "${ARCHIVE_MODE} 打包模式指定错误，目前只支持 squashfs 、 tar 、 merge 和 rawdisk 模式。"
			exit 1
			;;
	esac

fi
