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
#	    echo "强制指定使用主线环境中进行构建。"
	    ;;
        h|?)
            echo "拆分指定目录。"
            echo ""
            echo "用法: ./`basename $0` [选项] [步骤名称] [需要拆分的目录]"
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
	    echo "    -w: 强制在主线环境中进行拆分，不指定该参数将使用 current_branch 指定的分支环境中进行拆分，若不存在 current_branch 文件则默认对主线环境进行拆分。"
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

export SPLIT_STEP_NAME=""
export SPLIT_DIR=""

if [ "x${1}" == "x" ]; then
	echo "没有指定步骤名称!"
	exit 1
fi
SPLIT_STEP_NAME="${1}"

if [ "x${2}" == "x" ]; then
	echo "没有指定需要拆分的目录。"
	exit 2
fi
SPLIT_DIR="${2}"

echo "拆分 ${SPLIT_DIR} 目录..."
mkdir -p ${NEW_TARGET_SYSDIR}/logs/split/
echo "拆分 ${SPLIT_DIR} 目录..." > ${NEW_TARGET_SYSDIR}/logs/split/split_${SPLIT_STEP_NAME}.log

if [ -d ${SPLIT_DIR} ]; then
	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${SPLIT_STEP_NAME}.split ]; then
		cat ${NEW_TARGET_SYSDIR}/overlaydir/${SPLIT_STEP_NAME}.split | sort | uniq | while read line_split
		do
			SPLIT_PART_NAME=$(echo "${line_split}" | awk -F'	' '{ print $1 }')
			if [ "x${SPLIT_PART_NAME}" == "x" ]; then
				echo "没有设置拆分目标名。"
				exit 3
			fi
			SPLIT_DIRECTORY=$(echo "${line_split}" | awk -F'	' '{ print $2 }')
			if [ ! -d ${SPLIT_DIR}/./${SPLIT_DIRECTORY} ]; then
				"警告：${SPLIT_DIR}/./${SPLIT_DIRECTORY} 目录不存在, 跳过这条处理步骤，继续后面的步骤。"
				continue
			fi
			SPLIT_MATCH_RULE=$(echo "${line_split}" | awk -F'	' '{ print $3 }')
			if [ "x${SPLIT_MATCH_RULE}" == "x" ]; then
				SPLIT_MATCH_RULE="*"
			fi

			mkdir -p ${SPLIT_DIR}.${SPLIT_PART_NAME}/./${SPLIT_DIRECTORY}
			RUN_COMMAND="mv ${SPLIT_DIR}/./${SPLIT_DIRECTORY}/${SPLIT_MATCH_RULE} ${SPLIT_DIR}.${SPLIT_PART_NAME}/./${SPLIT_DIRECTORY}/"
			echo "${RUN_COMMAND}"
#			set -x
			eval ${RUN_COMMAND}
#			set +x
		done
	else
		echo "没有找到 ${NEW_TARGET_SYSDIR}/overlaydir/${SPLIT_STEP_NAME}.split 拆分文件，将使用默认的拆分方式。"
	fi
else
	echo "没有找到 ${SPLIT_DIR} 目录，请检查是否指定了正确的路径。"
fi
