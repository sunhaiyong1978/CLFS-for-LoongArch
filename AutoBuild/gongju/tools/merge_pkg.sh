#!/bin/bash -e

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

declare FORCE_CREATE=FALSE
declare OVERLAY_NAME=""
declare OVERLAY_PATH=""
declare ALL_RE_PATH=""

declare KERNEL_CREATE=TRUE
declare KERNEL_ONLY=FALSE
declare HAVE_KERNEL=FALSE
declare HAVE_PKGS=FALSE
declare ALL_IN_ONE=FALSE
declare WORLD_PARM=""

while getopts 'fP:wh' OPT; do
    case $OPT in
        f)
            FORCE_CREATE=TRUE
            ;;
# 	P)
# 	    ALL_RE_PATH=$OPTARG
# 	    ;;
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    echo "强制指定使用主线环境中进行打包。"
	    ;;
        h|?)
# 		tools/merge_pkg.sh desk_app lbrowser:3.4.2039.0
            echo "用法: `basename $0` [选项] [合并目标名:目录] [目标名:版本:[+|-|/]目录,目标名...]"
#             echo "目录名: "
#             echo -n "    目前可用的目录名有: "
#             for i in $(cat ${NEW_BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
#             do
#                    echo -n "${i} "
#             done
            echo ""
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
            echo "    -f: 强制创建合并目录。"
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


if [ "x${1}" != "x" ]; then
	OVERLAY_NAME="$(echo "${1}" | awk -F':' '{ print $1 }')"
	OVERLAY_PATH="$(echo "${1}" | awk -F':' '{ print $2 }')"
fi

if [ "x${OVERLAY_NAME}" == "x" ]; then
	echo "没有指定进行合并的组件名，无法继续，请指定存在于 ${NEW_BASE_DIR}/workbase/overlaydir_strip/ 内的组件名称。"
	exit 1
fi

if [ "x${2}" != "x" ]; then
	PKGS_NAME_ALL="${2}"
fi

if [ "x${PKGS_NAME_ALL}" == "x" ]; then
	echo "没有指定任何需要合并的独立软件包，无法继续。"
	exit 2
fi


OVERLAY_FULL_PATH=""

if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME} ]; then
	RELEASE_SUFF=""
	if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${i}.released ]; then
		RELEASE_SUFF=".update"
	fi
	if [ ! -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} ]; then
		mkdir -p ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}
	fi
	OVERLAY_FULL_PATH=${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}
else
	RELEASE_SUFF=""
	if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${i}.released ]; then
		RELEASE_SUFF=".update"
	fi
	if [ "x${FORCE_CREATE}" == "xTRUE" ]; then
		echo "没有发现 ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} 目录，将进行创建..."
		mkdir -p ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}
	else
		echo "没有发现 ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} 目录，无法继续合并，可使用 -c 参数进行创建。"
		exit 3
	fi
	OVERLAY_FULL_PATH=${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}
fi


function pkg_merge_to_overlaydir
{
# pkg_merge_to_overlaydir "${OVERLAY_FULL_PATH}" "${OVERLAY_ADD_PATH}" "${BASE_DIR}/import_pkgs/${PKG_NAME}/${GET_PKG_VERSION}/" "${PKG_STRIP_PATH}"
# OVERLAY_FULL_PATH=${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}

	MERGE_DEST_DIR="${1}"
	if [ "x${2}" != "x" ]; then
		MERGE_DEST_DIR="${1}/${2}"
	fi
	MERGE_SOURCE_DIR="${3}"
	if [ "x${4}" != "x" ]; then
		MERGE_SOURCE_DIR="${3}/root/${4}"
	else
		MERGE_SOURCE_DIR="${3}/root/"
	fi

	if [ -d ${1} ]; then
		mkdir -p ${MERGE_DEST_DIR}

		if [ ! -d ${MERGE_SOURCE_DIR} ]; then
			echo "${MERGE_SOURCE_DIR} 目录不存在，无法继续。"
			return 2
		fi
		echo -n "正在将 ${MERGE_SOURCE_DIR} 合并到 ${MERGE_DEST_DIR} ..."
		pushd ${MERGE_SOURCE_DIR} > /dev/null
# 			echo "tar -cvf - . | tar -xvf - -C ${MERGE_DEST_DIR}/"
			tar -cf - . | tar -xf - -C ${MERGE_DEST_DIR}/
		popd > /dev/null
		echo "完成！"
	else
		echo "没有发现 ${1} 目录，无法继续。"
		return 1
	fi
	return 0
}


for NAME_STR in $(echo ${PKGS_NAME_ALL} | tr ',' ' ')
do
	PKG_NAME=$(echo ${NAME_STR} | awk -F':' '{ print $1}')
	PKG_VERSION="NULL"
	PKG_STRIP_PATH=""
	OVERLAY_ADD_PATH="${OVERLAY_PATH}"
	for RE_STR in $(echo ${NAME_STR#*:} | tr ':' ' ')
	do
		case "${RE_STR:0:1}" in
			"+")
				OVERLAY_ADD_PATH="${OVERLAY_ADD_PATH}$(echo "/"${RE_STR:1} | sed "s@\.\./@@g" | sed "s@//@@g")"
				;;
			"-")
				PKG_STRIP_PATH="$(echo "/"${RE_STR:1} | sed "s@\.\./@@g" | sed "s@//@@g")"
				;;
			"/")
				OVERLAY_ADD_PATH="$(echo "/"${RE_STR:1} | sed "s@\.\./@@g" | sed "s@//@@g")"
				;;
			*)
				PKG_VERSION=${RE_STR}
				;;
		esac
	done

# 	if [ "x${PKG_RE_PATH}" == "x" ]; then
# 		PKG_RE_PATH=${ALL_RE_PATH}
# 	fi
# 	if [ "x${PKG_RE_PATH}" != "x" ]; then
# 		PKG_RE_PATH=$(echo "/"${PKG_RE_PATH} | sed "s@\.\./@@g" | sed "s@//@@g")
# 	fi

	if [ "x${PKG_VERSION}" == "xNULL" ]; then
		if [ -d ${BASE_DIR}/import_pkgs/${PKG_NAME} ]; then
			for j in foo $(find ${BASE_DIR}/import_pkgs/${PKG_NAME}/ -mindepth 1 -maxdepth 1 -type d)
			do
				GET_PKG_VERSION=$(echo "$(basename ${j})" | grep -v "_bak\." | grep -v "foo" | sort -V  | tail -n1)
				if [ "x${GET_PKG_VERSION}" != "x" ]; then
					pkg_merge_to_overlaydir "${OVERLAY_FULL_PATH}" "${OVERLAY_ADD_PATH}" "${BASE_DIR}/import_pkgs/${PKG_NAME}/${GET_PKG_VERSION}/" "${PKG_STRIP_PATH}"
				fi
			done
		fi
	else
		if [ -d ${BASE_DIR}/import_pkgs/${PKG_NAME}/${PKG_VERSION} ]; then
			pkg_merge_to_overlaydir "${OVERLAY_FULL_PATH}" "${OVERLAY_ADD_PATH}" "${BASE_DIR}/import_pkgs/${PKG_NAME}/${PKG_VERSION}/" "${PKG_STRIP_PATH}"
		fi
	fi

	if [ "x$?" != "x0" ]; then
		echo "${PKG_NAME} 合并错误，请检查。"
		exit 3
	fi
done
