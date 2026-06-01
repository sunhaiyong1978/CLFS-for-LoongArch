#!/bin/bash -e

if [ "x${1}" == "x" ]; then
        echo "必须指定一个包路径。"
        exit 1
fi

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


while getopts 'wh' OPT; do
    case $OPT in
	w)
            NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
            NEW_BASE_DIR="${BASE_DIR}"
            SCRIPTS_DIR="${BASE_DIR}/scripts"
            RELEASE_BUILD_MODE=0
	    ;;
        h|?)
            echo "下载目标系统所涉及的源码包和资源文件。"
            echo ""
            echo "用法: ./`basename $0` [选项] [步骤脚本文件]"
            echo "选项:"
            echo "    -h: 当前帮助信息。"
	    echo "    -w: 强制使用主线环境中的脚本文件，不指定该参数将使用 current_branch 中指定的分支环境中的脚本文件，若不存在 current_branch 文件则默认使用主线环境的脚本文件。"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))


export OVERLAY_DIR=${NEW_TARGET_SYSDIR}/overlay/$(cat ${NEW_BASE_DIR}/env/${1%%/*}/overlay.set | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')

source ${NEW_BASE_DIR}/env/function.sh

PACKAGE_FILE=${SCRIPTS_DIR}/step/${1}

if [ ! -f ${PACKAGE_FILE} ]; then
        echo "没有${PACKAGE_FILE}脚本文件。"
        exit 2
fi

echo -n "正在执行${3}..."
TMP_RUN="$(replace_arch_parm "$(cat ${PACKAGE_FILE})")"
TEMP_RUN_DATE_SUFF="$(date +%s%N)"
echo "${TMP_RUN}" > ${NEW_TARGET_SYSDIR}/temp/TEMP-run_${TEMP_RUN_DATE_SUFF}.sh
pushd ${NEW_BASE_DIR} > /dev/null
bash -e -x ${NEW_TARGET_SYSDIR}/temp/TEMP-run_${TEMP_RUN_DATE_SUFF}.sh
popd > /dev/null
#bash -e -x ${PACKAGE_FILE}
if [ "x$?" == "x0" ]; then
	rm ${NEW_TARGET_SYSDIR}/temp/TEMP-run_${TEMP_RUN_DATE_SUFF}.sh
	echo "完成。"
	exit 0
else
	echo "发生了错误，请查看日志文件内容。"
	exit 3
fi

