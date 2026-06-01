#!/bin/bash -e

export BASE_DIR="${PWD}"
export NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"

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


declare OPT_SET_STR=""
declare OPT_SET_ENV=""
declare SINGLE_PACKAGE=0
declare DATA_SUFF=""
declare AUTO_SET_OVERLAY_DIR=0
declare SET_OVERLAY_DIR=""
declare AUTO_SET_PARENT_DIR=0
declare SET_PARENT_DIR=""
declare OPT_SET_PARENT_DIR=""
declare SET_CROSSTOOLS_DIR=""
declare WORLD_PARM=""

while getopts 'e:sS:O:C:wh?' OPT; do
    case $OPT in
	e)
	    OPT_SET_ENV=$OPTARG
	    ;;
	s)
	    SINGLE_PACKAGE=1
	    ;;
	S)
	    SET_OVERLAY_DIR=$OPTARG
	    ;;
	O)
	    SET_PARENT_DIR=$OPTARG
	    ;;
	C)
	    SET_CROSSTOOLS_DIR=$OPTARG
	    ;;
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    SCRIPTS_DIR="${BASE_DIR}/scripts"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    ;;
        h|?)
            echo "进入步骤制作环境。"
            echo ""
            echo "用法: ./`basename $0` [选项] [步骤组/软件包]"
            echo "步骤组/软件包:"
            echo "    用来指定编译范围，通常一个步骤会包含多个软件包，可以单独指定步骤名或者软件包名，当指定的软件包名在不同的步骤中都存在时，需要指定步骤名以确认需要编译的软件包步骤。"
            echo "    例如:boot/linux，代表了名为“boot”的步骤组内的linux这个软件包编译的步骤。"
            echo "    例如:boot，代表了名为“boot”的步骤组。"
            echo "    例如:linux，如果没有“linux”这个名称的步骤组，则会自动查询所有步骤组中是否存在linux这个软件包所对应的步骤，如果存在多个则会提示用户进行选择，如果仅存在一个则会开始制作该软件包的步骤，若找不到则会提示错误。"
            echo "    不指定步骤组/软件包时代表全部步骤都进行制作。"
            echo "选项:"
            echo "    -h: 当前帮助信息。"
            echo "    -s: 软件包会在workbase/packages目录里对应名称的目录中安装一份文件。"
            echo "    -e <变量名=变量,变量名=变量,...>: 设置编译过程中传递给编译步骤的变量设置。"
            echo "    -S <目录名>: 构建过程中默认安装到sysroot目录中的文件将安装到指定目录中。"
            echo "    -O <目录名>: 构建过程中设置用于OverlayFS的目录，当需要指定多个目录时使用“,”符号进行分隔，特殊名称ORIG代表编译的软件包所在组设置的目录，目录优先级从后往前。"
	    echo "    -C <目录名>: 构建过程中设置Cross-Tools的目录，该目录将替代cross-tools目录。"
	    echo "    -w: 强制设置使用主线环境的软件包编译的步骤"
            exit 127
    esac
done
shift $(($OPTIND - 1))


if [ "x${1}" == "x" ]; then
        echo "必须指定一个步骤组或者软件包代表的路径。"
        exit 1
fi

export PACKAGE_NAME="foo"

function get_overlay_dirname
{
	declare OVERLAY_DIR=""

	OVERLAY_DIR=$(cat ${1} | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
	echo "${OVERLAY_DIR}"
}


function fn_overlay_temp_fix_run
{
	if [ "x${1}" == "x" ]; then
		return
	fi
	declare STEP_STAGE="${1}"
	if [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}/overlay_temp_fix_run ]; then
		echo "执行${STEP_STAGE}的临时修改脚本……"
		set +e
		tools/run_package_script.sh ${WORLD_PARM} ${STEP_STAGE}/overlay_temp_fix_run >${NEW_TARGET_SYSDIR}/logs/overlay_temp_fix_run_${STEP_STAGE}_0000.log 2>&1
		if [ "x$?" != "x0" ]; then
			echo "临时修改脚本执行错误，可查看 ${NEW_TARGET_SYSDIR}/logs/overlay_temp_fix_run_${STEP_STAGE}_0000.log 获取更详细的内容。"
			exit -3
		fi
		set -e
	fi
}

function fn_package_temp_fix_run
{
	if [ "x${1}" == "x" ]; then
		return
	fi
	declare STEP_STAGE="${1}"
	if [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}.tempfix ]; then
		echo "执行${STEP_STAGE}的临时修改脚本……"
		set +e
		tools/run_package_script.sh ${WORLD_PARM} ${STEP_STAGE}.tempfix >${NEW_TARGET_SYSDIR}/logs/temp_fix_run_$(echo ${STEP_STAGE} | sed "s@/@_@g")_0000.log 2>&1
		if [ "x$?" != "x0" ]; then
			echo "临时修改脚本执行错误，可查看 ${NEW_TARGET_SYSDIR}/logs/temp_fix_run_$(echo ${STEP_STAGE} | sed "s@/@_@g")_0000.log 获取更详细的内容。"
			exit -3
		fi
		set -e
	fi
}


function overlay_mount
{
	declare LOWERDIR_LIST
	declare OVERLAY_PARENT_LIST
	declare OVERLAY_DIR=""
	declare USE_OVERLAY_DIR=""

	declare OVERLAY_TEMP_FIX="${3}"
	echo "准备 ${1} 步骤的目录..."

	if [ "x${AUTO_SET_PARENT_DIR}" == "x1" ]; then
		SET_PARENT_DIR=""
		AUTO_SET_PARENT_DIR=0
	fi


#	LOWERDIR_LIST="${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir"
	LOWERDIR_LIST=""
	if [ -f ${2} ]; then
		OVERLAY_DIR=$(get_overlay_dirname ${2})
	else
		OVERLAY_DIR=""
	fi


# 	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.released ]; then
#		SET_OVERLAY_DIR="${OVERLAY_DIR}.update"
		if [ "x${SET_PARENT_DIR}" == "x" ]; then
			if [ "x${OPT_SET_PARENT_DIR}" == "x" ]; then
				SET_PARENT_DIR="ORIG"
			else
				SET_PARENT_DIR="${OPT_SET_PARENT_DIR}"
			fi
			AUTO_SET_PARENT_DIR=1
		else
			AUTO_SET_PARENT_DIR=0
		fi
echo "SET_OVERLAY_DIR: ${SET_OVERLAY_DIR}"
	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.released ]; then
		if [ "x${SET_OVERLAY_DIR}" == "x" ] || [ "x${SET_OVERLAY_DIR}" == "x${OVERLAY_DIR}.update" ]; then
			if [ x"$(echo ",${SET_PARENT_DIR}," | grep ",ORIG,")" != "x" ]; then
				SET_PARENT_DIR="${SET_PARENT_DIR},${OVERLAY_DIR}"
			fi
		fi
	fi
#	fi

echo "SET_PARENT_DIR: ${SET_PARENT_DIR}"

	if [ -f ${2} ]; then
		OVERLAY_PARENT_LIST=$(cat ${2} | grep "parent_dirs=" | head -n1 | gawk -F'=' '{ print $2 }')
	else
		OVERLAY_PARENT_LIST=""
	fi
	if [ "x${OVERLAY_PARENT_LIST}" != "x" ]; then
		for i in ${OVERLAY_PARENT_LIST}
		do
			if [ ! -d ${NEW_TARGET_SYSDIR}/overlaydir/${i} ]; then
				mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${i}
			fi
				# ${LOWERDIR_LIST}:${NEW_TARGET_SYSDIR}/overlaydir/${i}
			if [ "x${LOWERDIR_LIST}" == "x" ]; then
				LOWERDIR_LIST="${NEW_TARGET_SYSDIR}/overlaydir/${i}"
				if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${i}.released ]; then
					if [ -d ${NEW_TARGET_SYSDIR}/overlaydir/${i}.update ]; then
						LOWERDIR_LIST="${NEW_TARGET_SYSDIR}/overlaydir/${i}.update:${NEW_TARGET_SYSDIR}/overlaydir/${i}"
					fi
				fi
			else
				LOWERDIR_LIST="${NEW_TARGET_SYSDIR}/overlaydir/${i}:${LOWERDIR_LIST}"
				if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${i}.released ]; then
					if [ -d ${NEW_TARGET_SYSDIR}/overlaydir/${i}.update ]; then
						LOWERDIR_LIST="${NEW_TARGET_SYSDIR}/overlaydir/${i}.update:${LOWERDIR_LIST}"
					fi
				fi
			fi
#			LOWERDIR_LIST=${NEW_TARGET_SYSDIR}/overlaydir/${i}:${LOWERDIR_LIST}
		done
	fi

	ONLY_PARENT_DIR=0
	LOWERDIR_SET_LIST=""
	if [ "x${SET_PARENT_DIR}" != "x" ]; then
		for i in $(echo "${SET_PARENT_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^-]@@g")
		do
			if [ "x${i}" == "xNULL" ]; then
				continue;
			fi
			if [ "x${i}" == "xORIG" ] || [ "x${i}" == "xORIG_PARENT" ]; then
				if [ "x${LOWERDIR_SET_LIST}" == "x" ]; then
					LOWERDIR_SET_LIST="${LOWERDIR_LIST}"
				else
					LOWERDIR_SET_LIST="${LOWERDIR_LIST}:${LOWERDIR_SET_LIST}"
				fi
				if [ "x${i}" == "xORIG_PARENT" ]; then
					ONLY_PARENT_DIR=1
				fi
			else
				if [ ! -d ${NEW_TARGET_SYSDIR}/overlaydir/${i} ]; then
					mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${i}
				fi
				if [ "x${LOWERDIR_SET_LIST}" == "x" ]; then
					LOWERDIR_SET_LIST="${NEW_TARGET_SYSDIR}/overlaydir/${i}"
				else
					LOWERDIR_SET_LIST="${NEW_TARGET_SYSDIR}/overlaydir/${i}:${LOWERDIR_SET_LIST}"
				fi
				if [ "x${i}" != "x${OVERLAY_DIR}" ] && [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${i}.released ]; then
					mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${i}.update
					LOWERDIR_SET_LIST="${NEW_TARGET_SYSDIR}/overlaydir/${i}.update:${LOWERDIR_SET_LIST}"
				fi
			fi
		done
		LOWERDIR_LIST="${LOWERDIR_SET_LIST}"
	fi
	if [ "x${LOWERDIR_LIST}" == "x" ]; then
		LOWERDIR_LIST="${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir"
	else
		LOWERDIR_LIST="${LOWERDIR_LIST}:${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir"
	fi

# echo "LOWERDIR_LIST: ${LOWERDIR_LIST}"

	if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
		mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${SET_OVERLAY_DIR}
		USE_OVERLAY_DIR="${NEW_TARGET_SYSDIR}/overlaydir/${SET_OVERLAY_DIR}:"
	else
		if [ "x${OVERLAY_DIR}" == "x" ]; then
			mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${1}
			OVERLAY_DIR=${1}
		fi

		mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}
		USE_OVERLAY_DIR="${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}:"
	fi
	sync

	if [ "x${USE_OVERLAY_DIR}" == "x" ]; then
		echo "没有可挂载的sysroot ?"
		exit -3
	fi

	if [ "x${ONLY_PARENT_DIR}" == "x1" ] && [ "x${SINGLE_PACKAGE}" == "x1" ]; then
		USE_OVERLAY_DIR=""
	fi

	if [ "x${OVERLAY_TEMP_FIX}" == "x1" ]; then
		if [ -f ${SCRIPTS_DIR}/step/${1}/${PACKAGE_NAME}.tempfix ] || [ -f ${SCRIPTS_DIR}/step/${1}/overlay_temp_fix_run ]; then
			if [ -d ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME} ]; then
				mv ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}{,.$(date +%Y%m%d%H%M%S)}
			fi
			if [ -d ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change ]; then
				mv ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change{,.$(date +%Y%m%d%H%M%S)}
			fi
			mkdir -p ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}
			mkdir -p ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change
			sync
#			sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}:${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			sudo mount -t overlay overlay -o lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			if [ "x$?" != "x0" ]; then
				echo "挂载sysroot错误！"
				echo "sudo mount -t overlay overlay -o lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				exit -2
			fi
			if [ -f ${SCRIPTS_DIR}/step/${1}/${PACKAGE_NAME}.tempfix ]; then
				fn_package_temp_fix_run "${1}/${PACKAGE_NAME}"
			else
				fn_overlay_temp_fix_run "${1}"
			fi
			overlay_umount
			overlay_umount_cross_tools
			sync
		fi
	fi




	if [ "x${SINGLE_PACKAGE}" == "x1" ]; then
		if [ -f ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME} ] || [ -L ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME} ]; then
			mv ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}{,.bak$(date +%Y%m%d%H%M%S)}
		fi
		if [ -d ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST ]; then
			mv ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST{,.bak$(date +%Y%m%d%H%M%S)}
		fi
		if [ -d ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST.${DATA_SUFF} ]; then
			mv ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST.${DATA_SUFF}{,.bak$(date +%Y%m%d%H%M%S)}
		fi
		mkdir -p ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST.${DATA_SUFF}
		ln -sf DEST.${DATA_SUFF} ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST
		sync

	        if ([ "x${OVERLAY_TEMP_FIX}" == "x1" ] && [ -f ${SCRIPTS_DIR}/step/${1}/overlay_temp_fix_run ]) || [ -f ${SCRIPTS_DIR}/step/${1}/${PACKAGE_NAME}.tempfix ]; then
			sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			if [ "x$?" != "x0" ]; then
				echo "挂载sysroot错误！"
				echo "sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				exit -2
			fi
		else
			sudo mount -t overlay overlay -o lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			if [ "x$?" != "x0" ]; then
				echo "挂载sysroot错误！"
				echo "sudo mount -t overlay overlay -o lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}/DEST,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				exit -2
			fi
		fi
	else
		if ([ "x${OVERLAY_TEMP_FIX}" == "x1" ] && [ -f ${SCRIPTS_DIR}/step/${1}/overlay_temp_fix_run ]) || [ -f ${SCRIPTS_DIR}/step/${1}/${PACKAGE_NAME}.tempfix ]; then
			echo "sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
			sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			if [ "x$?" != "x0" ]; then
				echo "挂载sysroot错误！"
				echo "sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				exit -2
			fi
		else
			USE_OVERLAY_DIR="${USE_OVERLAY_DIR:0:-1}"
			if [ "x${OVERLAY_TEMP_FIX}" != "x2" ]; then  # 除了final_run之外的步骤
				echo "sudo mount -t overlay overlay -o lowerdir=${LOWERDIR_LIST},upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				sudo mount -t overlay overlay -o lowerdir=${LOWERDIR_LIST},upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
				if [ "x$?" != "x0" ]; then
					echo "挂载sysroot错误！"
					echo "sudo mount -t overlay overlay -o lowerdir=${LOWERDIR_LIST},upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
					exit -2
				fi
			else  # final_run步骤
				sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir,upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
				if [ "x$?" != "x0" ]; then
					echo "挂载sysroot错误！"
					echo "sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir,upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
					exit -2
				fi
			fi
		fi
	fi






#	if [ "x${OVERLAY_TEMP_FIX}" == "x1" ]; then
#		if [ -f scripts/step/${1}/${PACKAGE_NAME}.tempfix ] || [ -f scripts/step/${1}/overlay_temp_fix_run ]; then
# #			sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}:${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
#		  echo "sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}:${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
#			sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}:${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
#			if [ "x$?" != "x0" ]; then
#				echo "挂载sysroot错误！"
#				echo "sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}:${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
#				exit -2
#			fi
#		fi
#	else
# #		sudo mount -t overlay overlay -o lowerdir=${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
#  	  echo "sudo mount -t overlay overlay -o lowerdir=${LOWERDIR_LIST},upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
#		sudo mount -t overlay overlay -o lowerdir=${LOWERDIR_LIST},upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
#		if [ "x$?" != "x0" ]; then
#			echo "挂载sysroot错误！"
#			echo "sudo mount -t overlay overlay -o lowerdir=${LOWERDIR_LIST},upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
#			exit -2
#		fi
#	fi

}

function overlay_umount
{
	sudo umount -R ${NEW_TARGET_SYSDIR}/sysroot
	if [ "x$?" != "x0" ]; then
		echo "卸载sysroot错误！"
		echo "sudo umount -R ${NEW_TARGET_SYSDIR}/sysroot"
		exit -2
	fi
	sync
}

function overlay_umount_cross_tools
{
	while mount | grep "on ${NEW_TARGET_SYSDIR}/cross-tools type " > /dev/null
	do
		sudo umount -R ${NEW_TARGET_SYSDIR}/cross-tools
		if [ "x$?" != "x0" ]; then
			echo "卸载cross-tools错误！"
			echo "sudo umount -R ${NEW_TARGET_SYSDIR}/cross-tools"
			exit -2
		fi
		sync
	done
}

function set_build_env
{
        declare -a SET_ENV
        declare SET_COUNT=0
        declare SET_STR="${2}"
        declare -a USE_ENV=(${1})
        declare USE_ENV_COUNT=${#USE_ENV[@]}

        for i in $(echo "${SET_STR}" | tr "," "\\n")
        do
                SET_ENV[${SET_COUNT}]=${i}
                ((SET_COUNT++))
        done

        for i in ${SET_ENV[*]}
        do
                USE_ENV[${USE_ENV_COUNT}]=${i}
                ((USE_ENV_COUNT++))
        done
        echo "${USE_ENV[@]}"
}


STEP_STAGE=$(echo ${1} | awk -F'/' '{ print $1 }')
STEP_PACKAGE=$(echo ${1} | awk -F'/' '{ print $2 }')

if [ "x${STEP_PACKAGE}" == "x" ]; then
	if [ ! -d ${SCRIPTS_DIR}/step/${STEP_STAGE} ]; then
		echo "没有${STEP_STAGE}组对应的环境。"
		exit 2
	fi
else
	PACKAGE_FILE=${SCRIPTS_DIR}/step/${1}

	if [ ! -f ${PACKAGE_FILE} ]; then
		echo "没有${PACKAGE_FILE}脚本文件。"
		exit 2
	fi
	PACKAGE_NAME=${STEP_PACKAGE}
fi


while mount | grep "overlay on ${NEW_TARGET_SYSDIR}/sysroot type " > /dev/null
do
	echo "卸载已挂载的目录 ${NEW_TARGET_SYSDIR}/sysroot ..."
	overlay_umount
done

while mount | grep "on ${NEW_TARGET_SYSDIR}/cross-tools type " > /dev/null
do
	echo "卸载已挂载的目录 ${NEW_TARGET_SYSDIR}/cross-tools ..."
	overlay_umount_cross_tools
done

SET_CROSSTOOLS_DIR=$(echo ${SET_CROSSTOOLS_DIR} | sed "s@[^[:alnum:]\|^\.\|^_\|^-]@@g")
if [ "x${SET_CROSSTOOLS_DIR}" != "x" ] && [ "x${SET_CROSSTOOLS_DIR}" != "xcross-tools" ]; then
	echo "设置了临时 cross-tools 目录，将使用 ${SET_CROSSTOOLS_DIR} 目录作为 cross-tools目录"
	mkdir -p ${NEW_TARGET_SYSDIR}/${SET_CROSSTOOLS_DIR}
	sudo mount --bind ${NEW_TARGET_SYSDIR}/${SET_CROSSTOOLS_DIR} ${NEW_TARGET_SYSDIR}/cross-tools
fi


declare -a USE_SET_ENV
declare USE_SET_ENV_COUNT=0

USE_SET_ENV=($(set_build_env "" "${OPT_SET_ENV}"))
USE_SET_ENV_COUNT=${#USE_SET_ENV[@]}

echo -n "" > ${NEW_TARGET_SYSDIR}/set_env.conf
for set_env in ${USE_SET_ENV[*]}
do
	ENV_KEY=$(echo ${set_env} | awk -F'=' '{ print $1 }')
	ENV_VALUE=$(echo ${set_env} | awk -F'=' '{ print $2 }')
	echo "export YONGBAO_SET_ENV_${ENV_KEY}=${ENV_VALUE}" >> ${NEW_TARGET_SYSDIR}/set_env.conf
done
echo "" > ${NEW_TARGET_SYSDIR}/package_env.conf



if [ "x${AUTO_SET_OVERLAY_DIR}" == "x1" ]; then
	SET_OVERLAY_DIR=""
	AUTO_SET_OVERLAY_DIR=0
fi


if [ "x${OPT_SET_PARENT_DIR}" != "x" ]; then
	echo "${PACKAGE_NAME} 设置了临时上级目录: ${OPT_SET_PARENT_DIR} 。"
fi
ORIG_OVERLAY_DIR=""
if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ]; then
	ORIG_OVERLAY_DIR=$(get_overlay_dirname ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set)
	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${ORIG_OVERLAY_DIR}.released ]; then
 		if [ "x${SET_OVERLAY_DIR}" == "x" ]; then
 			SET_OVERLAY_DIR="${ORIG_OVERLAY_DIR}.update"
 			AUTO_SET_OVERLAY_DIR=1
 		else
			AUTO_SET_OVERLAY_DIR=0
  		fi
 	fi
else
 	AUTO_SET_OVERLAY_DIR=0
fi


declare STEP_OVERLAY_TEMP_FIX=0
if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ] || [ "x${SET_PARENT_DIR}" != "x" ]; then
	if [ "x${PACKAGE_NAME}" != "xfinal_run" ]; then
		if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ]; then
			STEP_OVERLAY_TEMP_FIX="$(cat ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set | grep "temp_fix=" | tail -n1 | awk -F'=' '{ print $2 }')"
		else
			STEP_OVERLAY_TEMP_FIX=0
		fi
		if [ "x${STEP_PACKAGE}" != "x" ]; then
			if [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}/${STEP_PACKAGE}.tempfix ]; then
				STEP_OVERLAY_TEMP_FIX=1
			fi
		fi
		overlay_mount ${STEP_STAGE} ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set "${STEP_OVERLAY_TEMP_FIX}"
	else
		overlay_mount ${STEP_STAGE} ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set "2"
	fi
# else
#	if [ "x${PACKAGE_NAME}" != "xfinal_run" ]; then
#		if [ "x${STEP_PACKAGE}" != "x" ]; then
#			if [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}/${STEP_PACKAGE}.tempfix ]; then
#				STEP_OVERLAY_TEMP_FIX=1
#			fi
#		fi
#		overlay_mount ${STEP_STAGE} ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set "${STEP_OVERLAY_TEMP_FIX}"
#	else
#		overlay_mount ${STEP_STAGE} ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set "2"
#	fi
fi




if [ "x${STEP_PACKAGE}" != "x" ]; then
	for i in $(cat ${PACKAGE_FILE} | grep "^source " | sed "s@^source @@g")
	do
		if [ -f $i ]; then
	        	source $i
		else
			echo "找不到$i文件！"
			exit 3
		fi
	done
	source ${NEW_BASE_DIR}/env/${STEP_STAGE}/config
	source ${NEW_BASE_DIR}/env/distro.info
	source ${NEW_BASE_DIR}/env/function.sh
	source ${NEW_TARGET_SYSDIR}/set_env.conf
if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/custom ]; then
	source ${NEW_BASE_DIR}/env/${STEP_STAGE}/custom
fi
	export STEP_BUILDNAME=${STEP_STAGE}
	export STEP_PACKAGENAME=${STEP_PACKAGE}
	export PACKAGE_VERSION=$(cat ${PACKAGE_FILE} | grep "^export PACKAGE_VERSION=" | head -n1 | awk -F'=' '{ print $2 }')
	eval "export RESOURCEDIR=$(cat ${PACKAGE_FILE} | grep "^export RESOURCEDIR=" | head -n1 | awk -F'=' '{ print $2 }')"
else
	source ${NEW_BASE_DIR}/env/${STEP_STAGE}/config
	source ${NEW_BASE_DIR}/env/distro.info
	source ${NEW_BASE_DIR}/env/function.sh
	source ${NEW_TARGET_SYSDIR}/set_env.conf
if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/custom ]; then
	source ${NEW_BASE_DIR}/env/${STEP_STAGE}/custom
fi
	export STEP_BUILDNAME=${STEP_STAGE}
	export STEP_PACKAGENAME=foo
	export PACKAGE_VERSION=
	export RESOURCEDIR=${NEW_TARGET_SYSDIR}/files/base_support/foo//
fi
export

PACKAGE_SCRIPT_BODY=""
if [ "x${STEP_PACKAGE}" != "x" ]; then
	PACKAGE_SCRIPT_BODY="$(cat ${PACKAGE_FILE})"
fi

cd ${BUILD_DIRECTORY}
export PS1='\u:\w\$ '

if [ "x${STEP_PACKAGE}" != "x" ]; then
	echo -e "\e[32m以下是 ${STEP_STAGE}/${STEP_PACKAGE} 制作脚本的内容：\e[0m"
	echo "${PACKAGE_SCRIPT_BODY}"
fi

if [ "x${USE_SET_ENV_COUNT}" != "x0" ]; then
echo ""
echo -e "\e[33m当前设置的调试环境中定义了转换变量，该变量的使用可能会需要用到一些自定义命令，这些命令定义在 ${BASE_DIR}/env/function.sh 中，请使用以下命令使得这些自定义命令得以生效。\e[0m"
echo -e "\e[32msource ${NEW_BASE_DIR}/env/function.sh\e[0m"
echo -e "\e[32msource ${NEW_TARGET_SYSDIR}/set_env.conf\e[0m"
if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/custom ]; then
	echo -e "\e[32msource ${NEW_BASE_DIR}/env/${STEP_STAGE}/custom\e[0m"
fi
echo ""
fi

bash 

while mount | grep "overlay on ${NEW_TARGET_SYSDIR}/sysroot type " > /dev/null
do
	echo "卸载已挂载的目录 ${NEW_TARGET_SYSDIR}/sysroot ..."
	overlay_umount
done

