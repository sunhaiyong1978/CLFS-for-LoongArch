#!/bin/bash

# tools/import_pkg.sh <软件包文件>

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

export ARCHIVE_STEP_NAME=""
export ARCHIVE_DIR=""


declare FORCE_IMPORT=FALSE
declare LIST_PKGS=FALSE
declare ARCHIVE_PKG_SET_NAME="foo"
declare TAR_STRIP_COMPONENTS=1
declare WORLD_PARM=""

while getopts 'flt:wn:h' OPT; do
    case $OPT in
        f)
            FORCE_IMPORT=TRUE
            ;;
	l)
	    LIST_PKGS=TRUE
	    ;;
	t)
	    TAR_STRIP_COMPONENTS=$OPTARG
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
            echo "用法: `basename $0` [选项] 软件包文件名 软件包名称 软件包版本 软件包打包方式"
	    echo ""
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
	    echo "    -l: 显示已经导入的软件包名称和版本，无需其它参数。"
	    echo "    -t <数字>: 用来设置在解压tar类型包时使用的的 --strip-components 参数设置的数字，默认设置为 1 。"
	    echo "    -w: 强制在主线环境中进行打包，不指定该参数将使用 current_branch 指定的分支环境中进行打包，若不存在 current_branch 文件则默认对主线环境进行打包。"
	    echo "    -n <名称>: 设置打包文件的保存名称，该参数仅在第4个参数设置为 "pkg" 时才有效。"
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


if [ "x${LIST_PKGS}" == "xTRUE" ]; then
	if [ -d ${BASE_DIR}/import_pkgs ]; then
		echo "查寻导入软件包："
		for i in $(find ${BASE_DIR}/import_pkgs/ -mindepth 1 -maxdepth 1 -type d)
		do
			echo "$(basename ${i})"
			for j in foo $(find ${i} -mindepth 1 -maxdepth 1 -type d)
			do
				if [ "$(echo "$(basename ${j})" | grep -v "_bak\." | grep -v "foo")" != "" ]; then
					echo "    $(basename ${j})"
				fi
			done
		done
	fi
	if [ -d ${NEW_BASE_DIR}/dist/pkgs/ ]; then
		echo "查寻构建独立软件包："
		if [ -d ${NEW_BASE_DIR}/dist/pkgs/tar ]; then
			for i in $(find ${NEW_BASE_DIR}/dist/pkgs/ -mindepth 1 -maxdepth 1 -type f)
			do
				echo "$(basename ${i})"
			done
		fi
	fi
	exit 0
fi

if [ "x${1}" == "x" ]; then
	echo "没有指定需要导入的软件包文件。"
	exit 1
fi
PKG_ARCHIVE_FILE_FULLPATH="${1}"

PKG_ARCHIVE_FILE=$(basename ${PKG_ARCHIVE_FILE_FULLPATH})

if [ ! -f ${PKG_ARCHIVE_FILE} ]; then
	echo "没有找到 ${PKG_ARCHIVE_FILE} 文件，请检查文件输入是否正确。"
	exit 1
fi

if [ "x${2}" == "x" ]; then
	echo "没有指定需要导入的软件包名称。"
	exit 2
fi
PKG_ARCHIVE_FILE_NAME=${2}

if [ "x${3}" == "x" ]; then
	echo "没有指定需要导入的软件包版本。"
	exit 3
fi
PKG_ARCHIVE_FILE_VERSION=${3}

if [ "x${4}" == "x" ]; then
	echo "没有指定需要导入的软件包的包格式，目前支持 tar.gz、tar.xz、tgz 、rpm、deb。"
	exit 4
fi
PKG_ARCHIVE_FILE_SUFF=${4}

case "${PKG_ARCHIVE_FILE_SUFF}" in
	tar.* | tgz | rpm | deb )
		;;
	*)
		echo "尚未支持 ${PKG_ARCHIVE_FILE_SUFF} 格式的导入。"
		exit 5
		;;
esac


mkdir -p ${BASE_DIR}/import_pkgs
IMPORT_PKGS_DIR=${BASE_DIR}/import_pkgs

if [ -d ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/ ]; then
	if [ "x${FORCE_IMPORT}" == "xFALSE" ]; then
		echo "软件包及对应的版本已存在，请检查是否重复导入，如需强制导入，请时用 -f 参数。"
		exit 5
	else
		mv ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}{,_bak.$(date +%s%N)}
	fi
fi

mkdir -p ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/{pkg,info,temp,root}

cp -a ${PKG_ARCHIVE_FILE_FULLPATH} ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/pkg/

case "${PKG_ARCHIVE_FILE_SUFF}" in
	tar.* | tgz)
		tar x --strip-components=${TAR_STRIP_COMPONENTS} -f ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/pkg/${PKG_ARCHIVE_FILE} -C ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/root/
		;;
	rpm)
		rpm2cpio ${PKG_ARCHIVE_FILE} > ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/root/${PKG_ARCHIVE_FILE_NAME}.cpio
		if [ "x$?" != "x0" ]; then
			echo "${PKG_ARCHIVE_FILE} 文件格式错误！"
			exit 6
		fi
		pushd ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/root > /dev/null
			cpio -idv < ${PKG_ARCHIVE_FILE_NAME}.cpio 2>&1 1>/dev/null
			rm -f ${PKG_ARCHIVE_FILE_NAME}.cpio
		popd > /dev/null
		;;
	deb)
		pushd ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/temp > /dev/null
			ar x ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/pkg/${PKG_ARCHIVE_FILE}
			if [ "x$?" != "x0" ]; then
				echo "${PKG_ARCHIVE_FILE} 文件格式错误！"
				exit 6
			fi
			tar xf data.tar.* -C ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/root/
			rm -f ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/temp/*
		popd > /dev/null
		;;
	flatpak)
		echo "尚未支持 ${PKG_ARCHIVE_FILE_SUFF} "
		;;
esac

echo "${PKG_ARCHIVE_FILE}|${PKG_ARCHIVE_FILE_NAME}|${PKG_ARCHIVE_FILE_VERSION}|${PKG_ARCHIVE_FILE_SUFF}" > ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION}/info/pkg.info

echo "${PKG_ARCHIVE_FILE} 文件已导入到 ${IMPORT_PKGS_DIR}/${PKG_ARCHIVE_FILE_NAME}/${PKG_ARCHIVE_FILE_VERSION} 中。"
