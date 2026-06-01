#!/bin/bash -e

EXPORT_SHOW=1
EXPORT_ENV_VAR=0


export BASE_DIR="${PWD}"
export NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
export SCRIPTS_DIR="${BASE_DIR}/scripts"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

if [ -f ${BASE_DIR}/current_branch ]; then
	RELEASE_VERSION="$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
	if [ -d ${BASE_DIR}/Branch_${RELEASE_VERSION} ]; then
		NEW_TARGET_SYSDIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/workbase"
		SCRIPTS_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/scripts"
		NEW_BASE_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}"
		RELEASE_BUILD_MODE=1
#		echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行构建。"
	else
#		echo "没有发现 Branch_${RELEASE_VERSION} 目录。"
		NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
		NEW_BASE_DIR="${BASE_DIR}"
		SCRIPTS_DIR="${BASE_DIR}/scripts"
		RELEASE_BUILD_MODE=0
	fi
else
	NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	NEW_BASE_DIR="${BASE_DIR}"
	SCRIPTS_DIR="${BASE_DIR}/scripts"
	RELEASE_BUILD_MODE=0
fi

while getopts 'newh' OPT; do
    case $OPT in
        n)
            EXPORT_SHOW=0
            ;;
	w)
            NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
            NEW_BASE_DIR="${BASE_DIR}"
            SCRIPTS_DIR="${BASE_DIR}/scripts"
            RELEASE_BUILD_MODE=0
	    ;;
        e)
            EXPORT_ENV_VAR=1
            ;;
        h|?)
            echo "用法: `basename $0` [-nwe] 步骤名/软件包名"
            echo "选项:"
            echo "    -h: 当前帮助信息。"
            echo "    -n: 输出环境变量的内容。"
            echo "    -e: 提换环境变量到脚本内容中。"
	    echo "    -w: 强制显示主线环境中的脚本文件，不指定该参数将显示 current_branch 中指定的分支环境中的脚本文件，若不存在 current_branch 文件则默认显示主线环境的脚本文件。"
	    exit 0
	    ;;
    esac
done
shift $(($OPTIND - 1))

if [ "x${1}" == "x" ]; then
        echo "必须指定一个包路径。"
        exit 1
fi

if [ "x${2}" == "x" ]; then
	SUFF=""
else
	if [ "x${2:0:1}" == "x." ]; then
		SUFF="${2}"
	else
		SUFF=".${2}"
	fi
fi

source ${NEW_BASE_DIR}/env/function.sh

PACKAGE_FILE=${SCRIPTS_DIR}/step/${1}

if [ ! -f ${PACKAGE_FILE} ]; then
	echo "没有${PACKAGE_FILE}脚本文件。"
	exit 2
fi

for i in $(cat ${PACKAGE_FILE} | grep "^source " | sed "s@^source @@g")
do
	if [ -f $i ]; then
	        source $i
	else
		echo "找不到$i文件！"
		exit 3
	fi
done

SHOW_BODY="$(cat ${PACKAGE_FILE}${SUFF})"
if [ "x${EXPORT_SHOW}" == "x1" ]; then
	export

	for i in $(export | awk -F' ' '{ print $3 }' | awk -F'=' '{ print $1 }')
	do
		case ${i} in
			PWD)
				continue;
				;;
			*)
				SHOW_BODY="$(echo "${SHOW_BODY}" | sed "s@\${${i}}@#%%%#${i}#***#@g")"
				;;
		esac
	done
fi

if [ "x${EXPORT_ENV_VAR}" == "x0" ]; then
	SHOW_BODY="$(echo "${SHOW_BODY}" | sed "s@\${@#{@g")"

	SHOW_BODY="$(echo "${SHOW_BODY}" | sed -e "s@#%%%#@\${@g" -e "s@#\*\*\*#@}@g")"
fi

SHOW_BODY="$(replace_arch_parm "$(echo "${SHOW_BODY}")")"

pushd ${NEW_BASE_DIR} > /dev/null
envsubst <<< "${SHOW_BODY}" | sed "s@#{@\${@g"
popd > /dev/null

