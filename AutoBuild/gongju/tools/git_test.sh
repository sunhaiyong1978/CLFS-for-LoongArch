#!/bin/bash -e
BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"
declare RET_VALUE=0

if [ -f ${BASE_DIR}/current_branch ]; then
        RELEASE_VERSION="$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
        if [ -d ${BASE_DIR}/Branch_${RELEASE_VERSION} ]; then
                NEW_TARGET_SYSDIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/workbase"
                NEW_BASE_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}"
                RELEASE_BUILD_MODE=1
#                echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行构建。"
        else
#                echo "没有发现 Branch_${RELEASE_VERSION} 目录。"
                NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
                NEW_BASE_DIR="${BASE_DIR}"
                RELEASE_BUILD_MODE=0
        fi
else
        NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
        NEW_BASE_DIR="${BASE_DIR}"
        RELEASE_BUILD_MODE=0
fi

declare SET_DEST_DIR=""
while getopts 'd:wh' OPT; do
    case $OPT in
        d)
            SET_DEST_DIR=$OPTARG
            ;;
	w)
            NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
            NEW_BASE_DIR="${BASE_DIR}"
            RELEASE_BUILD_MODE=0
	    ;;
        h|?)
            echo "用法: `basename $0` [选项] 软件包名 软件版本 GIT地址 分支名 提交号 更新方式"
	    exit 0
	    ;;
    esac
done
shift $(($OPTIND - 1))

declare GIT_DIR=${NEW_BASE_DIR}/downloads/sources/git
if [ "x${SET_DEST_DIR}" == "x" ]; then
	declare DEST_DIR=${NEW_BASE_DIR}/downloads/sources/files/
else
	declare DEST_DIR=${SET_DEST_DIR}
fi

if [ "x${1}" == "x" ]; then
	exit 1
fi
PKG_NAME=${1}

if [ "x${2}" == "x" ]; then
	exit 2
fi
if [ "x${2}" == "x-" ]; then
	PKG_VERSION=""
else
	PKG_VERSION="-${2}"
fi

if [ "x${3}" == "x" ]; then
	exit 3
fi
PKG_URL=${3}
#if [ "x${PKG_URL##*\.}" != "xgit" ]; then
#	exit 3
#fi

PKG_GIT_INFO=${4}

PKG_BRANCH=""
PKG_COMMIT=""
PKG_BRANCH=$(echo ${PKG_GIT_INFO} | awk -F'|' '{ print $1}')
# PKG_COMMIT=${5}
PKG_COMMIT=$(echo ${PKG_GIT_INFO} | awk -F'|' '{ print $2}')

if [ "x${PKG_COMMIT}" == "x" ]; then
	PKG_COMMIT="HEAD"
else
	echo "0"
	exit 0
fi

# PKG_UPDATE_MODE=${6}
PKG_UPDATE_MODE=""
PKG_UPDATE_MODE=$(echo ${PKG_GIT_INFO} | awk -F'|' '{ print $3}')
if [ "x${PKG_UPDATE_MODE}" == "x" ]; then
	PKG_UPDATE_MODE="手工"
fi


if [ ! -f ${NEW_BASE_DIR}/downloads/sources/hash/${1}-${2}.gitinfo.hash ]; then
	echo "1"
	exit 5
else
	PKG_SUBMODULE=$(echo ${PKG_GIT_INFO} | awk -F'|' '{ print $4}')
	PKG_FORMAT=$(echo ${PKG_GIT_INFO} | awk -F'|' '{ print $5}')
# 	if [ "x$(echo -n "${PKG_BRANCH}|${PKG_COMMIT}|${PKG_UPDATE_MODE}|${PKG_SUBMODULE}|${PKG_FORMAT}" | md5sum | cut -d ' ' -f 1)" != "x$(cat ${NEW_BASE_DIR}/downloads/sources/hash/${1}-${2}.gitinfo.hash)" ]; then
	if [ "x$(echo -n "${PKG_GIT_INFO}" | md5sum | cut -d ' ' -f 1)" != "x$(cat ${NEW_BASE_DIR}/downloads/sources/hash/${1}-${2}.gitinfo.hash)" ]; then
		echo "1"
		exit 6
	fi
fi

MODIFY_TIME=0
TIME_DIFF=0
DAYS_DIFF=0

case "x${PKG_UPDATE_MODE}" in
	x手工 | xManual)
		echo "0"
		exit 0
		;;
	x每次 | xEverytime)
		RET_VALUE="1"
		;;
	*)
		if [ -f ${DEST_DIR}/${PKG_NAME}${PKG_VERSION}_git.commit ]; then
			CURRENT_month=$(date +%Y%m)
			CURRENT_day=$(date +%Y%m%d)
			CURRENT_week=$(date +%Y%V)  # %V表示ISO周数
			CURRENT_allday=$(($(date +%s) / 86400))

# 			echo "stat -c %Y ${DEST_DIR}/${PKG_NAME}${PKG_VERSION}_git.commit"
			MODIFY_TIME=$(stat -c %Y ${DEST_DIR}/${PKG_NAME}${PKG_VERSION}_git.commit)
			FILE_month=$(date -d "@$MODIFY_TIME" +%Y%m)
			FILE_day=$(date -d "@$MODIFY_TIME" +%Y%m%d)
			FILE_week=$(date -d "@$MODIFY_TIME" +%Y%V)
			FILE_allday=$((MODIFY_TIME / 86400))

			case "x${PKG_UPDATE_MODE}" in
				x每日 | xEveryDay)
					RET_VALUE="$(( FILE_day < CURRENT_day ? 1 : 0))"
					;;
				x每周 | xEveryWeek)
					RET_VALUE="$(( FILE_week < CURRENT_week ? 1 : 0))"
					;;
				x每月 | xEveryMonth)
					RET_VALUE="$(( FILE_month < CURRENT_month ? 1 : 0))"
					;;
				*)
					if [[ ${PKG_UPDATE_MODE} =~ ^[0-9]+$ ]]; then
						RET_VALUE="$(( (CURRENT_allday - FILE_allday) > PKG_UPDATE_MODE ? 1 : 0))"
					else
						echo "0"
						exit 0
					fi
					;;
			esac
		else
			echo "1"
			exit 0
		fi
		;;
esac

if [ "x${RET_VALUE}" == "x0" ]; then
	echo "0"
	exit 0
fi


# case "x${PKG_UPDATE_MODE}" in
# 	x每天 | xEveryday)
# 		if [ $DAYS_DIFF -gt 1 ]; then
# 			
# 		fi
# 		;;
# 	*)
# 		;;
# esac


# mkdir -p ${GIT_DIR}
# pushd ${GIT_DIR} > /dev/null

# pwd
# echo "${PKG_NAME}${PKG_VERSION}_git.commit"

if [ ! -f ${DEST_DIR}/${PKG_NAME}${PKG_VERSION}_git.commit ]; then
	echo "1"
else
	if [ "x${PKG_BRANCH}" != "x" ]; then
		GET_GIT_COMMIT=$(git ls-remote ${PKG_URL} -b "${PKG_BRANCH}" | awk '{ print $1 }')
	else
		GET_GIT_COMMIT=$(git ls-remote ${PKG_URL} HEAD | awk '{ print $1 }')
	fi
#  	echo "cat ${DEST_DIR}/${PKG_NAME}${PKG_VERSION}_git.commit | awk -F'COMMIT=' '{ print $2 }'"
# 	echo "${GET_GIT_COMMIT}"
	if [ "x${GET_GIT_COMMIT}" == "x" ] || [ "x$(cat ${DEST_DIR}/${PKG_NAME}${PKG_VERSION}_git.commit | awk -F'COMMIT=' '{ print $2 }')" == "x${GET_GIT_COMMIT}" ]; then
		echo "0"
	else
		echo "1"
	fi
fi

# popd > /dev/null
exit 0
