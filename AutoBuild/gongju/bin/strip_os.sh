#!/bin/bash -e

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"


declare DO_STRIP=TRUE
declare FORCE_COPY=FALSE
declare OVERLAY_NAME=""
declare WORLD_PARM=""

while getopts 'fnwh' OPT; do
    case $OPT in
        f)
            FORCE_COPY=TRUE
            ;;
        n)
            DO_STRIP=FALSE
            ;;
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    echo "强制指定使用主线环境中进行构建。"
	    ;;
        h|?)
            echo "对目标系统去掉二进制文件的调试符信息。"
            echo ""
            echo "用法: ./`basename $0` [选项] [目录名]"
            echo "目录名: "
            echo -n "    目前可用的目录名有: "
            for i in $(cat ${NEW_BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
            do
                   echo -n "${i} "
            done
            echo "    不指定目录名将处理所有的目录。"
            echo ""
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
            echo "    -f: 将原有目录进行重命名，并重新进行目标系统的调试符清理工作。"
            echo "    -n: 不进行调试符清理工作。"
	    echo "    -w: 强制在主线环境中进行清理，不指定该参数将使用 current_branch 指定的分支环境中进行清理，若不存在 current_branch 文件则默认对主线环境进行清理。"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

if [ "x${1}" != "x" ]; then
	OVERLAY_NAME="${1}"
fi

if [ "x${WORLD_PARM}" == "x" ]; then
	if [ -f ${BASE_DIR}/current_branch ]; then
		RELEASE_VERSION="$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
		if [ -d ${BASE_DIR}/Branch_${RELEASE_VERSION} ]; then
			NEW_TARGET_SYSDIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/workbase"
			NEW_BASE_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}"
			RELEASE_BUILD_MODE=1
			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行清理。"
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


if [ -d ${NEW_BASE_DIR}/workbase/overlaydir/ ]; then
	if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip ] && [ "x${OVERLAY_NAME}" == "x" ]; then
		if [ "x${FORCE_COPY}" == "xTRUE" ]; then
			mv ${NEW_BASE_DIR}/workbase/overlaydir_strip{,.$(date +%Y%m%d%H%M%S)}
		else
# 			echo "已发现存在 ${NEW_BASE_DIR}/workbase/overlaydir_strip/ 目录，程序将继续处理该目录中的内容，如果需要更新处理目录的内容，请使用-f参数重新执行命令。"
			echo "已发现存在 ${NEW_BASE_DIR}/workbase/overlaydir_strip/ 目录，程序将不再继续其中的目录，如果需要更新处理目录的内容，请使用-f参数重新执行命令，或者指定其中具体要处理的目录。"
			exit 2
		fi
	fi
	mkdir -p ${NEW_BASE_DIR}/workbase/overlaydir_strip
else
	echo "没有发现可以清理的系统目录，请检查${NEW_BASE_DIR}/workbase/overlaydir目录是否存在，并确认是否使用build.sh制作了系统。"
	exit 1
fi

mkdir -p ${NEW_TARGET_SYSDIR}/logs/{strip,split,final_fix}

if [ "x${OVERLAY_NAME}" == "x" ]; then
#	for i in $(cat ${NEW_BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
	OVERLAY_DIR_LIST=$(find ${NEW_BASE_DIR}/workbase/overlaydir/ -maxdepth 1 -type f -name "*.dist" | awk -F'/' '{ print $NF }' | sed "s@\.dist\$@@g")
	if [ "x${OVERLAY_DIR_LIST}" == "x" ]; then
		echo "没有发现任何需要进行处理的目录。"
		exit 1
	fi
	for i in ${OVERLAY_DIR_LIST}
	do
		RELEASE_SUFF=""
		if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${i}.released ]; then
			RELEASE_SUFF=".update"
		fi
		echo "清理 $i${RELEASE_SUFF} 目录内的文件..."
		if [ -d ${NEW_BASE_DIR}/workbase/overlaydir/${i}${RELEASE_SUFF} ]; then
			if [ ! -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} ]; then
				cp -a ${NEW_BASE_DIR}/workbase/overlaydir{,_strip}/${i}${RELEASE_SUFF}
			else
				if [ "x${FORCE_COPY}" == "xTRUE" ]; then
					echo "当前 ${NEW_BASE_DIR}/workbase/overlaydir_strip/ 目录中已存在 ${i}${RELEASE_SUFF} 目录,备份目录，并重新复制。"
					mv ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF}{,.$(date +%Y%m%d%H%M%S)}
					if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${i}.split ]; then
						for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${i}.split | awk -F' ' '{ print $1 }' | sort | uniq)
						do
							if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j ]; then
								mv ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j{,.$(date +%Y%m%d%H%M%S)}
							fi
						done
					fi

					cp -a ${NEW_BASE_DIR}/workbase/overlaydir{,_strip}/${i}${RELEASE_SUFF}
				fi
			fi
#			STEP_NAME=$(grep -r "overlay_dir=$i" ${NEW_BASE_DIR}/env/*/overlay.set | head -n1 | awk -F'/' '{ print $2 }')
#			tools/strip_step.sh ${STEP_NAME} ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i || true
			if [ "x${DO_STRIP}" == "xTRUE" ]; then
				echo -n "开始进行去除调试信息的步骤..."
				tools/strip_step.sh ${WORLD_PARM} ${i} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} > ${NEW_TARGET_SYSDIR}/logs/strip/strip_${i}.log 2>&1 || true
				echo " 过程记录在 ${NEW_TARGET_SYSDIR}/logs/strip/strip_${i}.log"
			fi
			echo -n "开始进行目标系统运行准备处理步骤..."
			tools/final_step.sh ${WORLD_PARM} ${i} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} > ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${i}.log 2>&1 || true
			echo " 过程记录在 ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${i}.log"
			echo -n "开始进行拆分组件的步骤..."
			tools/split_step.sh ${WORLD_PARM} ${i} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} > ${NEW_TARGET_SYSDIR}/logs/split/split_${i}.log 2>&1 || true
			echo " 过程记录在 ${NEW_TARGET_SYSDIR}/logs/split/split_${i}.log"
		else
			echo "${NEW_BASE_DIR}/workbase/overlaydir 中没有发现 $i${RELEASE_SUFF} 目录，跳过。"
		fi

	done
else
	RELEASE_SUFF=""
	if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.released ]; then
		RELEASE_SUFF=".update"
	fi
	if [ -d ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME} ]; then
		echo "清理 ${OVERLAY_NAME}${RELEASE_SUFF} 目录内的文件..."
		if [ ! -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} ]; then
			cp -a ${NEW_BASE_DIR}/workbase/overlaydir{,_strip}/${OVERLAY_NAME}${RELEASE_SUFF}
		else
			if [ "x${FORCE_COPY}" == "xTRUE" ]; then
				echo "当前 ${NEW_BASE_DIR}/workbase/overlaydir_strip/ 目录中已存在 ${OVERLAY_NAME}${RELEASE_SUFF} 目录,备份目录，并重新复制。"
				mv ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}{,.$(date +%Y%m%d%H%M%S)}
				if [ -f ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split ]; then
					for j in $(cat ${NEW_BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split | awk -F' ' '{ print $1 }' | sort | uniq)
					do
						if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j ]; then
							mv ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j{,.$(date +%Y%m%d%H%M%S)}
						fi
					done
				fi
				cp -a ${NEW_BASE_DIR}/workbase/overlaydir{,_strip}/${OVERLAY_NAME}${RELEASE_SUFF}
			fi
		fi
		if [ "x${DO_STRIP}" == "xTRUE" ]; then
			echo -n "开始进行去除调试信息的步骤..."
			tools/strip_step.sh ${WORLD_PARM} ${OVERLAY_NAME} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} > ${NEW_TARGET_SYSDIR}/logs/strip/strip_${OVERLAY_NAME}${RELEASE_SUFF}.log 2>&1 || true
			echo " 过程记录在 ${NEW_TARGET_SYSDIR}/logs/strip/strip_${OVERLAY_NAME}${RELEASE_SUFF}.log"
		fi
		echo -n "开始进行目标系统运行准备处理步骤..."
		tools/final_step.sh ${WORLD_PARM} ${OVERLAY_NAME} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} > ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${OVERLAY_NAME}${RELEASE_SUFF}.log 2>&1 || true
		echo " 过程记录在 ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${OVERLAY_NAME}${RELEASE_SUFF}.log"
		echo -n "开始进行拆分组件的步骤..."
		tools/split_step.sh ${WORLD_PARM} ${OVERLAY_NAME} ${NEW_BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} > ${NEW_TARGET_SYSDIR}/logs/split/split_${OVERLAY_NAME}${RELEASE_SUFF}.log 2>&1 || true
		echo " 过程记录在 ${NEW_TARGET_SYSDIR}/logs/split/split_${OVERLAY_NAME}${RELEASE_SUFF}.log"
	else
		echo "${NEW_BASE_DIR}/workbase/overlaydir 中没有发现 ${OVERLAY_NAME}${RELEASE_SUFF} 目录，跳过。"
	fi
#	if [ "x${i}" != "x${OVERLAY_NAME}" ]; then
#		continue
#	fi
fi
