#!/bin/bash -e
BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

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
            echo "用法: `basename $0` [选项] 软件包名 软件版本 GIT地址 分支名 提交号 是否存在子模块 源码格式"
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

PKG_BRANCH=""
PKG_BRANCH=${4}

PKG_COMMIT=""
PKG_COMMIT=${5}
if [ "x${PKG_COMMIT}" == "x" ]; then
	PKG_COMMIT="HEAD"
fi

PKG_SUBMODULE=""
PKG_SUBMODULE=${6}
if [ "x${PKG_SUBMODULE}" == "x" ]; then
	PKG_SUBMODULE="0"
fi

PKG_FORMAT=""
PKG_FORMAT=${7}
if [ "x${PKG_FORMAT}" == "x" ]; then
	PKG_FORMAT="source"
fi


if [ "x${GIT_DIR}" == "x" ]; then
	GIT_DIR=${NEW_BASE_DIR}/downloads/sources/git
	DEST_DIR=${NEW_BASE_DIR}/downloads/sources/files/
else
	GIT_DIR=${NEW_BASE_DIR}/downloads/sources/resource_git/${PKG_NAME}/
fi
mkdir -p ${GIT_DIR}
echo "pushd ${GIT_DIR}"
pushd ${GIT_DIR}
if [ ! -d "${PKG_NAME}${PKG_VERSION}_git" ]; then
	if [ "x${PKG_BRANCH}" != "x" ]; then
		echo "git clone --depth 1 ${PKG_URL} ${PKG_NAME}${PKG_VERSION}_git -b ${PKG_BRANCH}"
		git clone --depth 1 ${PKG_URL} ${PKG_NAME}${PKG_VERSION}_git -b "${PKG_BRANCH}"
	else
		echo "git clone --depth 1 ${PKG_URL} ${PKG_NAME}${PKG_VERSION}_git"
		git clone --depth 1 ${PKG_URL} ${PKG_NAME}${PKG_VERSION}_git
	fi
fi

if [ "x${PKG_COMMIT}" != "x" ]; then
	echo "git --git-dir=${PKG_NAME}${PKG_VERSION}_git/.git fetch --depth 1 origin ${PKG_COMMIT}"
	git --git-dir=${PKG_NAME}${PKG_VERSION}_git/.git fetch --depth 1 origin ${PKG_COMMIT}
fi

echo "COMMIT=$(git --git-dir=${PKG_NAME}${PKG_VERSION}_git/.git rev-parse ${PKG_COMMIT})" > ${PKG_NAME}${PKG_VERSION}_git.commit

if [ "x${PKG_SUBMODULE}" == "x1" ]; then
	pushd ${PKG_NAME}${PKG_VERSION}_git
		echo "git checkout ${PKG_COMMIT}"
		git checkout ${PKG_COMMIT}
		echo "git submodule init"
		git submodule init
		echo "git submodule update --depth 1"
		git submodule update --depth 1
		echo "git submodule foreach git submodule init"
		git submodule foreach git submodule init
		echo "git submodule foreach git submodule update --depth 1"
		git submodule foreach git submodule update --depth 1
	popd
fi

if [ "x${PKG_FORMAT}" != "xsource" ]; then
	echo "x${PKG_FORMAT}"
	case "x${PKG_FORMAT}" in
		xrpm)
			pushd ${PKG_NAME}${PKG_VERSION}_git
				mkdir -pv SOURCES
 				find . -maxdepth 1 -type f -exec mv '{}' SOURCES/ ';'
				mkdir -pv SPECS
 				mv SOURCES/*.spec SPECS
			popd
			;;
		*)
			;;
	esac
fi

if [ "x${PKG_SUBMODULE}" == "x1" ] || [ "x${PKG_FORMAT}" == "xrpm" ]; then
	echo "tar -czf ${PKG_NAME}${PKG_VERSION}_git.tar.gz ${PKG_NAME}${PKG_VERSION}_git"
	tar -czf ${PKG_NAME}${PKG_VERSION}_git.tar.gz ${PKG_NAME}${PKG_VERSION}_git
else
	echo "git --git-dir=${PKG_NAME}${PKG_VERSION}_git/.git archive --format=tar --output ${PKG_NAME}${PKG_VERSION}_git.tar --prefix=${PKG_NAME}${PKG_VERSION}_git/  ${PKG_COMMIT}"
	git --git-dir=${PKG_NAME}${PKG_VERSION}_git/.git archive --format=tar --output ${PKG_NAME}${PKG_VERSION}_git.tar --prefix=${PKG_NAME}${PKG_VERSION}_git/  ${PKG_COMMIT}
	echo "gzip -9 ${PKG_NAME}${PKG_VERSION}_git.tar"
	gzip -9 ${PKG_NAME}${PKG_VERSION}_git.tar
fi

mkdir -p ${DEST_DIR}
mv ${GIT_DIR}/${PKG_NAME}${PKG_VERSION}_git.tar.gz ${DEST_DIR}
cp ${PKG_NAME}${PKG_VERSION}_git.commit ${DEST_DIR}/
popd

exit 0
