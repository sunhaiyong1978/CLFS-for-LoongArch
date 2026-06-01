#!/bin/bash

BASE_DIR="${PWD}"
declare ADD_MISS_FILE=0
declare SET_CURRENT_FORCE=0
declare DATE_SUFF="$(date +%Y%m%d%H%M%S)"

while getopts 'ash' OPT; do
	case $OPT in
		a)
			ADD_MISS_FILE=1
			;;
		s)
			SET_CURRENT_FORCE=1
			;;
		h|?)
			echo "用法: `basename $0` [-a] [-s] 版本名 "
			echo "  -a: 当指定的分支目录已经存在时，本参数会补充一些分支相关的信息文件（文件不存在的情况）。"
			echo "  -s: 当存在 current_branch (当前指定分支) 文件时，如不设置本参数，将不会修改其内容。当指定分支目录已存在且尝试使用本参数时需与 -a 参数同时使用。"
			exit 0
			;;
	esac
done
shift $(($OPTIND - 1))

VERSION_NAME=""
if [ "x${1}" == "x" ]; then
	echo "未指定版本名，使用当前 env/distro.info 中 DISTRO_VERSION 作为版本名。"
else
	VERSION_NAME="$(echo ${1} | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
fi
echo "VERSION_NAME=${VERSION_NAME}"
if [ "x${VERSION_NAME}" == "x" ]; then
	VERSION_NAME="$(cat env/distro.info | grep "^DISTRO_VERSION=" | awk -F'=' '{ print $2 }' | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
fi


if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME} ]; then
	echo -n "创建 Branch_${VERSION_NAME} 目录..."
	mkdir -p Branch_${VERSION_NAME}/
	mkdir -p Branch_${VERSION_NAME}/sync/
	echo "完成。"
	echo "为自建分支 Branch_${VERSION_NAME} 创建信息文件..."
	if [ ! -f ${BASE_DIR}/Branch_${VERSION_NAME}/branch_message ]; then
		echo -n "创建分支说明文件..."
		echo "自建分支 Branch_${VERSION_NAME}" > ${BASE_DIR}/Branch_${VERSION_NAME}/branch_message
		echo "完成！"
	fi
	if [ ! -f ${BASE_DIR}/Branch_${VERSION_NAME}/sync/branch_stamp ]; then
		echo -n "创建分支时间戳文件..."
		echo "${DATE_SUFF}" > ${BASE_DIR}/Branch_${VERSION_NAME}/sync/branch_stamp
		echo "完成！"
	fi

	ENV_DIR=${BASE_DIR}/Branch_${VERSION_NAME}/env
	SCRIPTS_DIR=${BASE_DIR}/Branch_${VERSION_NAME}/scripts
	FILES_DIR=${BASE_DIR}/Branch_${VERSION_NAME}/files
	SOURCES_DIR=${BASE_DIR}/Branch_${VERSION_NAME}/sources


	if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/env ]; then
		cp -a ${BASE_DIR}/env ${BASE_DIR}/Branch_${VERSION_NAME}/
	fi
	if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/scripts ]; then
		cp -a ${BASE_DIR}/scripts ${BASE_DIR}/Branch_${VERSION_NAME}/
	fi
	if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/files ]; then
		cp -a ${BASE_DIR}/files ${BASE_DIR}/Branch_${VERSION_NAME}/
	fi
	if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/sources ]; then
		cp -a ${BASE_DIR}/sources ${BASE_DIR}/Branch_${VERSION_NAME}/
	fi
	if [ ! -d ${BASE_DIR}/Branch_${VERSION_NAME}/docs ]; then
		cp -a ${BASE_DIR}/docs ${BASE_DIR}/Branch_${VERSION_NAME}/
	fi
	if [ ! -f ${BASE_DIR}/Branch_${VERSION_NAME}/step ]; then
		cp -a ${BASE_DIR}/step ${BASE_DIR}/Branch_${VERSION_NAME}/
		cp -a ${BASE_DIR}/step ${BASE_DIR}/Branch_${VERSION_NAME}/step.orig
	fi
	if [ ! -f ${BASE_DIR}/Branch_${VERSION_NAME}/info_set ]; then
		cp -a ${BASE_DIR}/info_set ${BASE_DIR}/Branch_${VERSION_NAME}/
	fi

	mkdir -p ${BASE_DIR}/Branch_${VERSION_NAME}/downloads/sources/{files,hash}
	mkdir -p ${BASE_DIR}/Branch_${VERSION_NAME}/logs
else
	if [ "x${ADD_MISS_FILE}" == "x1" ]; then
		mkdir -p Branch_${VERSION_NAME}/sync/
		echo "Branch_${VERSION_NAME} 目录已存在，仅对确实的信息文件进行补充..."
		if [ ! -f ${BASE_DIR}/Branch_${VERSION_NAME}/branch_message ]; then
			echo -n "创建分支说明文件..."
			echo "自建分支 Branch_${VERSION_NAME}" > ${BASE_DIR}/Branch_${VERSION_NAME}/branch_message
			echo "完成！"
		fi
		if [ ! -f ${BASE_DIR}/Branch_${VERSION_NAME}/sync/branch_stamp ]; then
			echo -n "创建分支时间戳文件..."
			echo "${DATE_SUFF}" > ${BASE_DIR}/Branch_${VERSION_NAME}/sync/branch_stamp
			echo "完成！"
		fi
# 		exit 0
	else
		echo "Branch_${VERSION_NAME} 目录已存在，不能继续创建，请移除后重新执行当前命令。"
 		exit -2
	fi
fi


if [ -f ${BASE_DIR}/current_branch ]; then
	if [ "x${SET_CURRENT_FORCE}" != "x1" ]; then
		echo "当前 current_branch 已经存在，指定版本名为“$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")”，请使用 -s 参数进行强制更新，或手工进行修改。"
		exit 0
	fi
fi
echo "${VERSION_NAME}" > ${BASE_DIR}/current_branch
echo "current_branch 文件内容已更新。"
exit 0
