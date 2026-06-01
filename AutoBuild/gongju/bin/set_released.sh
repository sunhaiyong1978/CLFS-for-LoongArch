#!/bin/bash -e

export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"

declare FORCE_COPY=FALSE
declare OVERLAY_NAME=""

while getopts 'fh' OPT; do
    case $OPT in
        f)
            FORCE_COPY=TRUE
            ;;
        h|?)
            echo "对目标系统去掉二进制文件的调试符信息。"
            echo ""
            echo "用法: ./`basename $0` [选项] [目录名]"
            echo "目录名: "
            echo -n "    目前可用的目录名有: "
            for i in $(cat ${BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
            do
                   echo -n "${i} "
            done
            echo "    不指定目录名将处理所有的目录。"
            echo ""
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
            echo "    -f: 将原有目录进行重命名，并重新进行目标系统的调试符清理工作。"
            exit 0
            ;;
    esac
done
shift $(($OPTIND - 1))

if [ "x${1}" != "x" ]; then
	OVERLAY_NAME="${1}"
fi

if [ -d ${BASE_DIR}/workbase/overlaydir/ ]; then
	if [ -d ${BASE_DIR}/workbase/overlaydir_strip ] && [ "x${OVERLAY_NAME}" == "x" ]; then
		if [ "x${FORCE_COPY}" == "xTRUE" ]; then
			mv ${BASE_DIR}/workbase/overlaydir_strip{,.$(date +%Y%m%d%H%M%S)}
		else
			echo "已发现存在 ${BASE_DIR}/workbase/overlaydir_strip/ 目录，程序将继续处理该目录中的内容，如果需要更新处理目录的内容，请使用-f参数重新执行命令。"
			exit 2
		fi
	fi
	mkdir -p ${BASE_DIR}/workbase/overlaydir_strip
else
	echo "没有发现可以清理的系统目录，请检查${BASE_DIR}/workbase/overlaydir目录是否存在，并确认是否使用build.sh制作了系统。"
	exit 1
fi

if [ "x${OVERLAY_NAME}" == "x" ]; then
#	for i in $(cat ${BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
	OVERLAY_DIR_LIST=$(find ${BASE_DIR}/workbase/overlaydir/ -maxdepth 1 -type f -name "*.dist" | awk -F'/' '{ print $NF }' | sed "s@\.dist\$@@g")
	if [ "x${OVERLAY_DIR_LIST}" == "x" ]; then
		echo "没有发现任何需要进行处理的目录。"
		exit 1
	fi
	for i in ${OVERLAY_DIR_LIST}
	do
		RELEASE_SUFF=""
		if [ -f ${BASE_DIR}/workbase/overlaydir/${i}.released ]; then
			RELEASE_SUFF=".update"
		fi
		echo "清理 $i${RELEASE_SUFF} 目录内的文件..."
		if [ -d ${BASE_DIR}/workbase/overlaydir/${i}${RELEASE_SUFF} ]; then
			if [ ! -d ${BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} ]; then
				cp -a ${BASE_DIR}/workbase/overlaydir{,_strip}/${i}${RELEASE_SUFF}
			else
				if [ "x${FORCE_COPY}" == "xTRUE" ]; then
					echo "当前 ${BASE_DIR}/workbase/overlaydir_strip/ 目录中已存在 ${i}${RELEASE_SUFF} 目录,备份目录，并重新复制。"
					mv ${BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF}{,.$(date +%Y%m%d%H%M%S)}
					if [ -f ${BASE_DIR}/workbase/overlaydir/${i}.split ]; then
						for j in $(cat ${BASE_DIR}/workbase/overlaydir/${i}.split | awk -F' ' '{ print $1 }' | sort | uniq)
						do
							if [ -d ${BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j ]; then
								mv ${BASE_DIR}/workbase/overlaydir_strip/$i${RELEASE_SUFF}.$j{,.$(date +%Y%m%d%H%M%S)}
							fi
						done
					fi

					cp -a ${BASE_DIR}/workbase/overlaydir{,_strip}/${i}${RELEASE_SUFF}
				fi
			fi
#			STEP_NAME=$(grep -r "overlay_dir=$i" env/*/overlay.set | head -n1 | awk -F'/' '{ print $2 }')
#			tools/strip_step.sh ${STEP_NAME} ${BASE_DIR}/workbase/overlaydir_strip/$i || true
			tools/strip_step.sh ${i} ${BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} || true

			tools/split_step.sh ${i} ${BASE_DIR}/workbase/overlaydir_strip/${i}${RELEASE_SUFF} || true
		else
			echo "${BASE_DIR}/workbase/overlaydir 中没有发现 $i${RELEASE_SUFF} 目录，跳过。"
		fi

	done
else
	RELEASE_SUFF=""
	if [ -f ${BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.released ]; then
		RELEASE_SUFF=".update"
	fi
	if [ -d ${BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME} ]; then
		echo "清理 ${OVERLAY_NAME}${RELEASE_SUFF} 目录内的文件..."
		if [ ! -d ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} ]; then
			cp -a ${BASE_DIR}/workbase/overlaydir{,_strip}/${OVERLAY_NAME}${RELEASE_SUFF}
		else
			if [ "x${FORCE_COPY}" == "xTRUE" ]; then
				echo "当前 ${BASE_DIR}/workbase/overlaydir_strip/ 目录中已存在 ${OVERLAY_NAME}${RELEASE_SUFF} 目录,备份目录，并重新复制。"
				mv ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}{,.$(date +%Y%m%d%H%M%S)}
				if [ -f ${BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split ]; then
					for j in $(cat ${BASE_DIR}/workbase/overlaydir/${OVERLAY_NAME}.split | awk -F' ' '{ print $1 }' | sort | uniq)
					do
						if [ -d ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j ]; then
							mv ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF}.$j{,.$(date +%Y%m%d%H%M%S)}
						fi
					done
				fi
				cp -a ${BASE_DIR}/workbase/overlaydir{,_strip}/${OVERLAY_NAME}${RELEASE_SUFF}
			fi
		fi
		tools/strip_step.sh ${OVERLAY_NAME} ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} || true
		tools/split_step.sh ${OVERLAY_NAME} ${BASE_DIR}/workbase/overlaydir_strip/${OVERLAY_NAME}${RELEASE_SUFF} || true
	else
		echo "${BASE_DIR}/workbase/overlaydir 中没有发现 ${OVERLAY_NAME}${RELEASE_SUFF} 目录，跳过。"
	fi
#	if [ "x${i}" != "x${OVERLAY_NAME}" ]; then
#		continue
#	fi
fi
