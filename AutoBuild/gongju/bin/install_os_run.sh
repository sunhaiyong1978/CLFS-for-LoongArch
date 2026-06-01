#!/bin/bash -e

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"
declare WORLD_PARM=""


while getopts 'wh' OPT; do
    case $OPT in
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    echo "强制指定使用主线环境中进行构建。"
	    ;;
        h|?)
            echo "说明：将首次运行脚本安装到系统中。"
            echo "用法: ./`basename $0`"
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
	    echo "    -w: 强制在主线环境中进行安装文件，不指定该参数将使用 current_branch 指定的分支环境中安装文件，若不存在 current_branch 文件则默认对主线环境进行安装文件。"
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
			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行安装文件。"
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

declare OVERLAY_DIR=""

if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip ]; then
	if [ -d ${NEW_TARGET_SYSDIR}/scripts/os_first_run/ ]; then
#		for dir in $(find ${NEW_TARGET_SYSDIR}/scripts/os_first_run/ -name "*.run" | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_first_run/@@g" | awk -F'.' '{ print $1 }' | sort | uniq)
		for dir_overlay in $(find ${NEW_TARGET_SYSDIR}/scripts/os_first_run/ -name "*.run" | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_first_run/@@g" | awk -F'.' '{ print $1 "." $2 }' | sort | uniq)
		do
			dir=$(echo ${dir_overlay} | awk -F'.' '{ print $1 }')
			if [ ! -f ${NEW_BASE_DIR}/env/${dir}/overlay.set ]; then
				echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
				exit 1
			fi
			OVERLAY_DIR=$(echo ${dir_overlay} | awk -F'.' '{ print $2 }')
			if [ "x${OVERLAY_DIR}" == "x" ]; then
				OVERLAY_DIR=$(cat ${NEW_BASE_DIR}/env/${dir}/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }')
			fi
			if [ "x${OVERLAY_DIR}" == "x" ]; then
				echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
				exit 1
			fi
			if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_DIR}.released ]; then
				continue;
			fi
			if [ ! -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/first-run.d/ ]; then
				mkdir -pv ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/first-run.d/
			fi
#			for run_file in $(ls ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${dir}.*.run | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_first_run/${dir}\.@@g" | awk -F'.' '{ print $1 }')
			for run_file in $(ls ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${dir_overlay}.*.run | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_first_run/${dir_overlay}\.@@g" | awk -F'.' '{ print $1 }')
			do
#				echo -n "正在安装${dir}.${run_file}.run文件到 ${OVERLAY_DIR}/etc/first-run.d/50-$(date +%Y%m%d%H%M%S)-${dir}_${run_file}.sh ..."
#				cat ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${dir}.${run_file}.run > ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/first-run.d/50-${run_file}_${dir}_$(date +%Y%m%d%H%M%S).sh
				echo -n "正在安装${dir_overlay}.${run_file}.run文件到 ${OVERLAY_DIR}/etc/first-run.d/50-${run_file}_${dir_overlay}.sh ..."
				cat ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${dir_overlay}.${run_file}.run > ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/first-run.d/50-${run_file}_${dir_overlay}.sh
				echo "完成！"
			done
		done
	fi

	if [ -d ${NEW_TARGET_SYSDIR}/scripts/os_start_run/ ]; then
		for dir_overlay in $(find ${NEW_TARGET_SYSDIR}/scripts/os_start_run/ -name "*.run" | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_start_run/@@g" | awk -F'.' '{ print $1 "." $2 }' | sort | uniq)
		do
			dir=$(echo ${dir_overlay} | awk -F'.' '{ print $1 }')
			if [ ! -f ${NEW_BASE_DIR}/env/${dir}/overlay.set ]; then
				echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
				exit 1
			fi
			OVERLAY_DIR=$(echo ${dir_overlay} | awk -F'.' '{ print $2 }')
			if [ "x${OVERLAY_DIR}" == "x" ]; then
				OVERLAY_DIR=$(cat ${NEW_BASE_DIR}/env/${dir}/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }')
			fi
			if [ "x${OVERLAY_DIR}" == "x" ]; then
				echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
				exit 1
			fi

			if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_DIR}.released ]; then
				continue;
			fi

			if [ ! -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/start-run.d/ ]; then
				mkdir -pv ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/start-run.d/
			fi
			for run_file in $(ls ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${dir_overlay}.*.run | sed "s@${NEW_TARGET_SYSDIR}/scripts/os_start_run/${dir_overlay}\.@@g" | awk -F'.' '{ print $1 }')
			do
#				echo -n "正在安装${dir}.${run_file}.run文件到 ${OVERLAY_DIR}/etc/start-run.d/50-$(date +%Y%m%d%H%M%S)-${dir}_${run_file}.sh ..."
#				cat ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${dir}.${run_file}.run > ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/start-run.d/50-${run_file}_${dir}_$(date +%Y%m%d%H%M%S).sh
				echo -n "正在安装${dir_overlay}.${run_file}.run文件到 ${OVERLAY_DIR}/etc/start-run.d/50-${run_file}_${dir_overlay}.sh ..."
				cat ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${dir_overlay}.${run_file}.run > ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}/etc/start-run.d/50-${run_file}_${dir_overlay}.sh
				echo "完成！"
			done
		done
	fi


	if [ -d ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/ ]; then
		for dir_overlay in $(find ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/ -name "*.run" | sed "s@${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/@@g" | awk -F'.' '{ print $1 "." $2 }' | sort | uniq)
		do
			dir=$(echo ${dir_overlay} | awk -F'.' '{ print $1 }')
			if [ ! -f ${NEW_BASE_DIR}/env/${dir}/overlay.set ]; then
				echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
				exit 1
			fi
			OVERLAY_DIR=$(echo ${dir_overlay} | awk -F'.' '{ print $2 }')
			if [ "x${OVERLAY_DIR}" == "x" ]; then
				OVERLAY_DIR=$(cat ${NEW_BASE_DIR}/env/${dir}/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }')
			fi
			if [ "x${OVERLAY_DIR}" == "x" ]; then
				echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
				exit 1
			fi
			if [ ! -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_DIR}.released ]; then
				continue;
			fi
			if [ ! -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}.update/etc/first-run.d/ ]; then
				mkdir -pv ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}.update/etc/first-run.d/
			fi
			for run_file in $(ls ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/${dir_overlay}.*.run | sed "s@${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/${dir_overlay}\.@@g" | awk -F'.' '{ print $1 }')
			do
#				echo -n "正在安装${dir}.${run_file}.run文件到 ${OVERLAY_DIR}.update/etc/first-run.d/51-$(date +%Y%m%d%H%M%S)-${dir}_${run_file}.sh ..."
#				cat ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/${dir}.${run_file}.run > ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}.update/etc/first-run.d/51-${run_file}_${dir}_$(date +%Y%m%d%H%M%S).sh

				echo -n "正在安装${dir_overlay}.${run_file}.run文件到 ${OVERLAY_DIR}.update/etc/first-run.d/51-${run_file}_${dir_overlay}.sh ..."
				cat ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/${dir_overlay}.${run_file}.run > ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}.update/etc/first-run.d/51-${run_file}_${dir_overlay}.sh
				echo "完成！"
			done
		done
	fi

	if [ -d ${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/ ]; then
		for dir_overlay in $(find ${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/ -name "*.run" | sed "s@${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/@@g" | awk -F'.' '{ print $1 "." $2 }' | sort | uniq)
		do
			dir=$(echo ${dir_overlay} | awk -F'.' '{ print $1 }')
			if [ ! -f ${NEW_BASE_DIR}/env/${dir}/overlay.set ]; then
				echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
				exit 1
			fi
			OVERLAY_DIR=$(echo ${dir_overlay} | awk -F'.' '{ print $2 }')
			if [ "x${OVERLAY_DIR}" == "x" ]; then
				OVERLAY_DIR=$(cat ${NEW_BASE_DIR}/env/${dir}/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }')
			fi
			if [ "x${OVERLAY_DIR}" == "x" ]; then
				echo "${dir} 组没有定义overlay目录，无法安装其中软件包相关的首次启动执行脚本。"
				exit 1
			fi

			if [ ! -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_DIR}.released ]; then
				continue;
			fi

			if [ ! -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}.update/etc/start-run.d/ ]; then
				mkdir -pv ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}.update/etc/start-run.d/
			fi
			for run_file in $(ls ${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/${dir_overlay}.*.run | sed "s@${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/${dir_overlay}\.@@g" | awk -F'.' '{ print $1 }')
			do
#				echo -n "正在安装${dir_overlay}.${run_file}.run文件到 ${OVERLAY_DIR}.update/etc/start-run.d/51-$(date +%Y%m%d%H%M%S)-${dir}_${run_file}.sh ..."
#				cat ${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/${dir_overlay}.${run_file}.run > ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}.update/etc/start-run.d/51-${run_file}_${dir_overlay}_$(date +%Y%m%d%H%M%S).sh
				echo -n "正在安装${dir_overlay}.${run_file}.run文件到 ${OVERLAY_DIR}.update/etc/start-run.d/51-${run_file}_${dir_overlay}.sh ..."
				cat ${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/${dir_overlay}.${run_file}.run > ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_DIR}.update/etc/start-run.d/51-${run_file}_${dir_overlay}.sh
				echo "完成！"
			done
		done
	fi

else
	echo "没有发现可以用来打包的系统目录，请检查${NEW_BASE_DIR}/workbase/overlaydir_strip目录是否存在，你可以通过strip_os.sh脚本生成该目录。"
	exit 1
fi
