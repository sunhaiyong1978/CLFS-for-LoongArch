#!/bin/bash

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
	    ;;
        h|?)
            echo "清理调试信息目录。"
            echo ""
            echo "用法: ./`basename $0` [选项] [步骤名称] [需要清理调试信息的目录]"
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
	    echo "    -w: 强制在主线环境中进行清理，不指定该参数将使用 current_branch 指定的分支环境中进行清理，若不存在 current_branch 文件则默认对主线环境进行清理。"
            exit 127
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
#			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行构建。"
		else
#			echo "没有发现 Branch_${RELEASE_VERSION} 目录。"
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


export STRIP_STEP_NAME=""
export STRIP_DIR=""

if [ "x${1}" == "x" ]; then
	echo "没有指定步骤名称!"
	exit 1
fi
STRIP_STEP_NAME="${1}"

if [ "x${2}" == "x" ]; then
	echo "没有指定需要清理调试信息的目录。"
	exit 2
fi
STRIP_DIR="${2}"

echo "清理 ${STRIP_DIR} 目录内文件的调试信息..."
mkdir -p ${NEW_TARGET_SYSDIR}/logs/strip/
# echo "清理 ${STRIP_DIR} 目录内文件的调试信息..." > ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log
# source ${NEW_BASE_DIR}/env/${STRIP_STEP_NAME}/config

if [ -d ${STRIP_DIR} ]; then
	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${STRIP_STEP_NAME}.strip ]; then
		cat ${NEW_TARGET_SYSDIR}/overlaydir/${STRIP_STEP_NAME}.strip | sort | uniq | while read line_strip
		do
			STRIP_SET_DIRECTORY=$(echo "${line_strip}" | awk -F'	' '{ print $1 }')
			if [ "x${STRIP_SET_DIRECTORY}" == "x" ]; then
				echo "没有设置处理目录。"
				exit 3
			fi
			if [ ! -d ${STRIP_DIR}/./${STRIP_SET_DIRECTORY} ]; then
				"警告：${STRIP_DIR}/./${STRIP_SET_DIRECTORY} 目录不存在, 跳过这条处理步骤，继续后面的步骤。"
				continue
			fi
			STRIP_SET_DIRECTORY_DEPTH=$(echo "${line_strip}" | awk -F'	' '{ print $2 }')
			STRIP_SET_FILES=$(echo "${line_strip}" | awk -F'	' '{ print $3 }')
			STRIP_SET_COMMAND=$(echo "${line_strip}" | awk -F'	' '{ print $4 }')
			if [ "x$(echo ${STRIP_SET_COMMAND} | grep "^${NEW_TARGET_SYSDIR}/\(.*\)-strip")" == "x" ]; then
				echo "尝试进行处理的命令 ${STRIP_SET_COMMAND} 不以 ${NEW_TARGET_SYSDIR} 绝对路径开头，或者命令不以strip结尾，不继续进行处理，请检查。"
				exit 5
			fi
			STRIP_SET_COMMAND_PARM=$(echo "${line_strip}" | awk -F'	' '{ print $5 }')
			pushd ${STRIP_DIR} > /dev/null
				case "${STRIP_SET_DIRECTORY_DEPTH}" in
					1)
# 						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。" >> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log
						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。"
# 						RUN_COMMAND="find ${PWD}/./${STRIP_SET_DIRECTORY} -maxdepth ${STRIP_SET_DIRECTORY_DEPTH} -type f -name '"${STRIP_SET_FILES}"' -exec ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} {} 2>> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log ';'"
						RUN_COMMAND="find ${PWD}/./${STRIP_SET_DIRECTORY} -maxdepth ${STRIP_SET_DIRECTORY_DEPTH} -type f -name '"${STRIP_SET_FILES}"' -exec ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} {} ';'"
						set -x
						eval "${RUN_COMMAND}"
						set +x
						;;
					0)
# 						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中及其之下所有目录中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。" >> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log
						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中及其之下所有目录中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。"
# 						RUN_COMMAND="find ${PWD}/./${STRIP_SET_DIRECTORY} -type f -name '"${STRIP_SET_FILES}"' -exec ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} {} 2>> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log ';'"
						RUN_COMMAND="find ${PWD}/./${STRIP_SET_DIRECTORY} -type f -name '"${STRIP_SET_FILES}"' -exec ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} {} ';'"
						set -x
						eval "${RUN_COMMAND}"
						set +x
						;;
					*)
						echo "${PWD}/./${STRIP_SET_DIRECTORY} 设置的目录深度不适用，请使用 0(表示全部目录) 和 1(仅当前目录) 。"
						;;
				esac
			popd > /dev/null
		done
	else
		echo "没有找到 ${NEW_TARGET_SYSDIR}/overlaydir/${STRIP_STEP_NAME}.strip 处理流程文件，将使用默认的清理流程。"
# 		PACKAGE_STEP_NAME=""
# 		if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist ]; then
# 			PACKAGE_STEP_NAME=$(cat ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist)
# 		fi
# 		if [ "x${PACKAGE_STEP_NAME}" == "x" ]; then
# 			PACKAGE_STEP_NAME="target_base"
# 		fi

		STEP_BUILDNAME=""
		if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist ]; then
			source ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist
		fi
		if [ "x${STEP_BUILDNAME}" == "x" ]; then
			STEP_BUILDNAME="target_base"
		fi

		pushd ${STRIP_DIR} > /dev/null
# 			source ${NEW_BASE_DIR}/env/${PACKAGE_STEP_NAME}/config
			source ${NEW_BASE_DIR}/env/${STEP_BUILDNAME}/config
			if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist ]; then
				source ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist
			fi
			for dir_i in $(find -type d -name "lib" -o -type d -name "lib64" -o -tyep d -name "lib32" -o -type d-name "share")
			do
				if [ -d ${dir_i} ]; then
# 					echo "find ${dir_i} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {} ';'" >> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log
# 					find ${dir_i} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {} 2>> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log ';'
# 					echo "find ${dir_i} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'" >> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log
# 					find ${dir_i} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {} 2>> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log ';'

					echo "find ${dir_i} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {} ';'"
					find ${dir_i} -type f -name \*.a -exec ${CROSS_TARGET}-strip --strip-debug {} ';'
					echo "find ${dir_i} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'"
					find ${dir_i} -type f -name \*.so* -exec ${CROSS_TARGET}-strip --strip-unneeded {} ';'
				fi
			done
			for dir_i in $(find -type d -name "bin" -o -type d -name "sbin" -o -type d -name "libexec")
			do
				if [ -d ${dir_i} ]; then
# 					echo "find ${dir_i} -type f -exec ${CROSS_TARGET}-strip --strip-all {} ';'" >> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log
# 					find ${dir_i} -type f -exec ${CROSS_TARGET}-strip --strip-all {} 2>> ${NEW_TARGET_SYSDIR}/logs/strip/strip_${STRIP_STEP_NAME}.log ';'

					echo "find ${dir_i} -type f -exec ${CROSS_TARGET}-strip --strip-all {} ';'"
					find ${dir_i} -type f -exec ${CROSS_TARGET}-strip --strip-all {} ';'
				fi
			done
		popd > /dev/null
	fi
else
	echo "没有找到 ${STRIP_DIR} 目录，请检查是否指定了正确的路径。"
fi
