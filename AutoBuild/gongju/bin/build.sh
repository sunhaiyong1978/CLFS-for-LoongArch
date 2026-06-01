#!/bin/bash

# echo $(realpath "$0")
# if [ -f $(dirname $(realpath "$0"))/ZZ.version ]; then
# 	if [ "x$(cat $(dirname $(realpath "$0"))/ZZ.version)" == "x1.0" ]; then
# 		if [ -f $(dirname $(realpath "$0"))/build.sh.v1.0 ]; then
# 			echo "切换到 $(dirname $(realpath "$0"))/build.sh.v1.0 执行任务。"
# 			$(dirname $(realpath "$0"))/build.sh.v1.0 $@
# 			exit $?
# 		else
# 			echo "错误：没有对应的执行命令 build.sh.v1.0 ，无法继续执行。"
# 			exit 254
# 		fi
# 	fi
# fi

declare FULL_COMMAND="$0 $@"
BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"
declare NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"

declare ARCH_NAME="loongarch64"

declare FORCE_BUILD=0
declare FORCE_ALL_BUILD=0
declare OPT_SET_STR=""
declare OPT_SET_ENV=""
declare ONLY_BUILD=0
declare REQUIRES_BUILD=0
declare GROUP_IN_BUILD=0
declare SINGLE_PACKAGE=0
declare SINGLE_PACKAGE_TAR="none"
declare FORCE_ALL_DOWNLOAD=0
declare EXPORT_STEP=0
declare DATA_SUFF=""
declare SOURCE_STEP_FILE="${NEW_BASE_DIR}/step"
declare INDEX_STEP_FILE="${NEW_TARGET_SYSDIR}/step.index"
declare SET_INDEX_STEP_FILE=""
declare SET_STEP_FILE=""
declare INDEX_MD5SUM_FILE="step.md5sum"
declare AUTO_SET_OVERLAY_DIR=0
declare SET_OVERLAY_DIR=""
declare AUTO_SET_PARENT_DIR=0
declare SET_PARENT_DIR=""
declare USER_SET_PARENT_DIR=""
declare OPT_SET_PARENT_DIR=""
declare OPT_SET_OVERLAY_DIR=""
declare BUILD_PACKAGE_CHECK=0
declare USE_PROXY_DOWNLOAD=""
declare WORLD_PARM=""
declare USE_PREV_INDEX_FILE=0
declare SET_CROSSTOOLS_DIR=""
declare CROSSTOOLS_DIR_EXT=""
declare BUILD_ERROR_LIMITE=1
declare BUILD_ERROR_COUNT=1

while getopts 'fao:rgsP:de:xi:S:O:C:K:tpwch' OPT; do
    case $OPT in
        f)
            FORCE_BUILD=1
            ;;
        a)
            FORCE_ALL_BUILD=1
            ;;
	o)
	    OPT_SET_STR=$OPTARG
	    ;;
	r)
	    REQUIRES_BUILD=1
	    ;;
	g)
	    REQUIRES_BUILD=1
	    GROUP_IN_BUILD=1
	    ;;
	s)
	    SINGLE_PACKAGE=1
	    ;;
	P)
	    SINGLE_PACKAGE_TAR=$OPTARG
	    ;;
        d)
            FORCE_ALL_DOWNLOAD=1
            ;;
	e)
	    OPT_SET_ENV=$OPTARG
	    ;;
	x)
	    EXPORT_STEP=1
	    ;;
	i)
	    SET_STEP_FILE=$OPTARG
	    ;;
	S)
	    SET_OVERLAY_DIR=$OPTARG
	    ;;
	O)
	    USER_SET_PARENT_DIR=$OPTARG
	    ;;
	C)
	    SET_CROSSTOOLS_DIR=$OPTARG
	    ;;
	t)
	    BUILD_PACKAGE_CHECK=1
	    ;;
	p)
	    USE_PROXY_DOWNLOAD="-p"
	    ;;
# 	D)
#	    case "x${OPTARG}" in
#		x0)
#		    BUILD_ERROR_MODE="0"
#		    ;;
#		x1)
#		    BUILD_ERROR_MODE="1"
#		    ;;
#		*)
#		    BUILD_ERROR_MODE=""
#		    ;;
#	    esac
#	    ;;
	K)
	    if [[ ${OPTARG} =~ ^[0-9]+$ ]]; then
		    case "x${OPTARG}" in
			x0)
				BUILD_ERROR_LIMITE=0
				BUILD_ERROR_COUNT=1
				;;
			x1)
				BUILD_ERROR_LIMITE=1
				BUILD_ERROR_COUNT=1
				;;
			*)
				BUILD_ERROR_LIMITE=2
				BUILD_ERROR_COUNT=${OPTARG}
				;;
		    esac
	    else
		echo -e "\e[031m错误：-K 参数后必须指定一个数字！\e[0m"
		exit 127
	    fi
	    ;;
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    SCRIPTS_DIR="${BASE_DIR}/scripts"
	    SOURCES_DIR="${BASE_DIR}/sources"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    echo "强制指定使用主线环境中进行构建。"
	    SOURCE_STEP_FILE="${BASE_DIR}/step"
	    INDEX_STEP_FILE="${NEW_TARGET_SYSDIR}/step.index"
	    ;;
	c)
	    USE_PREV_INDEX_FILE=1
	    ;;
        h|?)
            echo "目标系统构建命令。"
            echo ""
            echo "用法: ./`basename $0` [选项] [步骤组/软件包]"
            echo "步骤组/软件包:"
            echo "    用来指定编译范围，通常一个步骤会包含多个软件包，可以单独指定步骤名或者软件包名，当指定的软件包名在不同的步骤中都存在时，需要指定步骤名以确认需要编译的软件包步骤。"
            echo "    例如:boot/linux，代表了名为“boot”的步骤组内的linux这个软件包编译的步骤。"
            echo "    例如:boot，代表了名为“boot”的步骤组内全部的步骤。"
            echo "    例如:linux，如果没有“linux”这个名称的步骤组，则会自动查询所有步骤组中是否存在linux这个软件包所对应的步骤，如果存在多个则会提示用户进行选择，如果仅存在一个则会开始制作该软件包的步骤，若找不到则会提示错误。"
            echo "    不指定步骤组/软件包时代表全部步骤都进行制作。"
            echo "选项:"
            echo "    -h: 当前帮助信息。"
            echo "    -d: 强制编译前先检查并下载需要的软件源码包及资源文件。"
            echo "    -o <标记,标记,...>: 设置编译标记参数（符合标记参数的软件包才会进行编译）"
            echo "    -s: 软件包会在workbase/packages目录里对应名称的目录中安装一份文件。"
            echo "    -P <tar> : 该参数仅在 -s 参数设置时有效，对在workbase/packages目录里安装的软件包进行打包，指定打包格式支持tar。"
            echo "    -r: 根据指定的编译步骤或软件包，搜寻依赖的相关软件包和步骤组一起进行编译。"
            echo "    -g: 根据指定的编译步骤或软件包，搜寻依赖的相关软件包和步骤组，然后从组中的第一个步骤开始进行编译直到指定的编译步骤或软件包为止。"
            echo "    -f: 强制执行指定的编译步骤。该参数必须指定编译步骤或软件包才有效。"
            echo "    -a: 强制编译所有的软件包步骤。与-f参数配合，用来在不指定任何软件包时强制编译所有满足标记参数设置的软件包。"
            echo "    -e <变量名=变量,变量名=变量,...>: 设置编译过程中传递给编译步骤的变量设置。"
            echo "    -x: 导出需要执行的step文件内容。"
            echo "    -i: 设置指定的步骤文件（.step）或步骤索引文件(.index)。"
            echo "    -S <目录名>: 构建过程中默认安装到sysroot目录中的文件将安装到指定目录中。"
            echo "    -O <目录名>: 构建过程中设置用于OverlayFS的目录，当需要指定多个目录时使用“,”符号进行分隔，特殊名称ORIG代表编译的软件包所在组设置的目录，目录优先级从后往前。"
            echo "    -C <目录名>: 构建过程中设置Cross-Tools的目录，该目录将替代cross-tools目录。"
            echo "    -t: 对构建过程中编译的软件判断当构建目标架构与当前架构相同时进行编译测试过程（需要软件包脚本目录中存在 check 后缀名的测试定义文件）。"
	    echo "    -p: 在构建过程中对需要下载软件包时使用proxy.set文件中的设置。"
	    echo "    -w: 强制使用主线环境中的构建，不指定该参数将使用 current_branch 中指定的分支环境中进行构建，若不存在 current_branch 文件则默认使用主线环境构建。"
	    echo "    -c: 构建过程按照上一次分析产生的步骤进行，单独使用该参数等同于使用 -i ${NEW_TARGET_SYSDIR}/step.index ，注意该参数不与 -o -r -g -i -s 参数共用。"
	    echo "    -K <错误数>: 指定在构建过程中出现错误的步骤数上限，当达到该指定数时构建过程终止并现实构建错误步骤，若未达到指定错误步骤上限将继续构建后续步骤，在构建结束后打印存在错误的步骤列表。不指定该参数将按照默认的上限进行处理，默认上限为1，即遇到错误步骤即停止。"
	    echo "        错误数: 0，不设上限，表示无论多少错误数都不会停止构建过程，直到构建完成为止，构建结束后打印错误步骤。"
	    echo "        错误数: 1，出现错误步骤即立刻停止构建过程，显示相关的信息。"
	    echo "        错误数: 2以上，指定错误步骤的上限，达到该限制时将立刻停止构建过程，并显示所有错误步骤。"
            exit 127
    esac
done
shift $(($OPTIND - 1))

if [ "x${WORLD_PARM}" == "x" ]; then
	if [ -f ${BASE_DIR}/current_branch ]; then
		RELEASE_VERSION="$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
		if [ -d ${BASE_DIR}/Branch_${RELEASE_VERSION} ]; then
			NEW_TARGET_SYSDIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/workbase"
			SCRIPTS_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/scripts"
			SOURCES_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}/sources"
			NEW_BASE_DIR="${BASE_DIR}/Branch_${RELEASE_VERSION}"
			RELEASE_BUILD_MODE=1
			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行构建。"
		else
			echo "没有发现 Branch_${RELEASE_VERSION} 目录。"
			NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
			NEW_BASE_DIR="${BASE_DIR}"
			SCRIPTS_DIR="${BASE_DIR}/scripts"
			SOURCES_DIR="${BASE_DIR}/sources"
			RELEASE_BUILD_MODE=0
		fi
	else
		NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
		NEW_BASE_DIR="${BASE_DIR}"
		SCRIPTS_DIR="${BASE_DIR}/scripts"
		SOURCES_DIR="${BASE_DIR}/sources"
		RELEASE_BUILD_MODE=0
	fi
fi
SOURCE_STEP_FILE="${NEW_BASE_DIR}/step"


export BUILD_PACKAGE_CHECK=${BUILD_PACKAGE_CHECK}


export YONGBAO_BUILD_UUID="$(date +%s%N)"
# echo "YONGBAO_BUILD_UUID: ${YONGBAO_BUILD_UUID}"


if [ "x${SINGLE_PACKAGE}" != "x1" ]; then
	if [ "x${USE_PREV_INDEX_FILE}" == "x1" ]; then
		if [ "x${SET_STEP_FILE##*.}" != "xindex" ]; then
			if [ -f ${NEW_TARGET_SYSDIR}/step.index.temp ]; then
				SET_STEP_FILE=${NEW_TARGET_SYSDIR}/step.index
			else
				echo "没有发现上次执行时保留下来的分析文件 ${NEW_TARGET_SYSDIR}/step.index，无法按照上次的步骤进行构建，请进行一次常规的构建分析后再使用 -c 参数。"
				exit 126
			fi
		fi
	fi
fi

if [ "x${SET_STEP_FILE}" != "x" ]; then
	case "x${SET_STEP_FILE##*.}" in
		"xindex")
			SOURCE_STEP_FILE="${NEW_BASE_DIR}/step"
			SET_INDEX_STEP_FILE="${SET_STEP_FILE}"
			;;
		"xstep")
			SOURCE_STEP_FILE="${SET_INDEX_STEP_FILE}"
			SET_INDEX_STEP_FILE=""
			;;
		*)
			echo "指定的步骤或索引文件必须以step或者index作为后缀名。"
			exit 2
			;;
	esac
fi

if [ ! -f "${SOURCE_STEP_FILE}" ]; then
	echo "没有发现脚本文件，请检查当前目录是否存在 ${SOURCE_STEP_FILE} 文件。"
	exit 127
fi

if [ "x${SINGLE_PACKAGE_TAR}" != "xnone" ] && [ "x${SINGLE_PACKAGE_TAR}" != "x" ]; then
	if [ "x${SINGLE_PACKAGE}" != "x1" ]; then
		echo "-P 参数仅在设置 -s 参数时才有效果。"
		exit 125
	fi
	case ${SINGLE_PACKAGE_TAR} in
		tar | none)
			;;
		*)
			echo "-P 参数仅支持设置：tar 、none"
			exit 125
			;;
	esac
fi


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



function get_all_set_env_expr
{
        declare -a SET_ENV
        declare -a DEFAULT_ENV
        declare SET_COUNT=0
        declare TEMP_COUNT=0
        declare GET_ENV_VALUE=""
        declare SET_STR="${1}"
        declare -a USE_ENV=("")
        declare USE_ENV_COUNT=${#USE_ENV[@]}

        for i in $(echo "${SET_STR}" | tr ";" "\\n")
        do
                if [ "x${i:0:1}" == "x%" ]; then
	                SET_ENV[${SET_COUNT}]=$(echo ${i:1} | awk -F'=' '{ print $1 }')
	                DEFAULT_ENV[${SET_COUNT}]=$(echo ${i:1} | awk -F'=' '{ print $2 }' | sed "s@[^?\|^[:alnum:]\|^[:space:]\|^_\|^-]@@g")
        	        ((SET_COUNT++))
		fi
        done
	if [ "x${SET_COUNT}" == "x0" ]; then
		echo ""
		return
	fi

        for i in ${SET_ENV[*]}
        do
		case "${i}" in
			PARENT | OVERLAY | VERSION )
				((TEMP_COUNT++))
				continue
				;;
			*)
				;;
		esac
		FINAL_ENV_VALUE=""
		GET_ENV_VALUE=""
		GET_ENV_VALUE="$(cat ${NEW_TARGET_SYSDIR}/temp/set_env_${YONGBAO_BUILD_UUID}.conf | grep "^export YONGBAO_SET_ENV_${i}=" | awk -F'=' '{ print $2 }')"
		if [ "x${GET_ENV_VALUE}" != "x" ] || [ "x${DEFAULT_ENV[${TEMP_COUNT}]}" != "x" ]; then
			if [ "x${GET_ENV_VALUE}" != "x" ]; then
# 		                USE_ENV[${USE_ENV_COUNT}]="${i}=${GET_ENV_VALUE}"
				FINAL_ENV_VALUE="${GET_ENV_VALUE}"
			fi
			if [ "x${DEFAULT_ENV[${TEMP_COUNT}]}" != "x" ]; then
				if [ "x${DEFAULT_ENV[${TEMP_COUNT}]:0:1}" == "x?" ]; then
# 					if [ "x${USE_ENV[${USE_ENV_COUNT}]}" == "x" ]; then
# 						USE_ENV[${USE_ENV_COUNT}]="${i}=${DEFAULT_ENV[${TEMP_COUNT}]:1}"
# 					fi
					if [ "x${GET_ENV_VALUE}" == "x" ]; then
						FINAL_ENV_VALUE="${DEFAULT_ENV[${TEMP_COUNT}]:1}"
					fi
				else
# 					USE_ENV[${USE_ENV_COUNT}]="${i}=${DEFAULT_ENV[${TEMP_COUNT}]}"
					FINAL_ENV_VALUE="${DEFAULT_ENV[${TEMP_COUNT}]}"
				fi
			else
				FINAL_ENV_VALUE=""
			fi
			case "x${FINAL_ENV_VALUE}" in
				"xHOST_ARCH")
					FINAL_ENV_VALUE="$(uname -m)"
					;;
				"xTARGET_ARCH")
					FINAL_ENV_VALUE="${ARCH_NAME}"
					;;
				"x")
					case "x${i}" in
						xhost)
							FINAL_ENV_VALUE="$(uname -m)"
							;;
						xtarget)
							FINAL_ENV_VALUE="${ARCH_NAME}"
							;;
						xvendor)
							FINAL_ENV_VALUE="unknown"
							;;
						*)
							;;
					esac
					;;
				*)
					;;
			esac
			USE_ENV[${USE_ENV_COUNT}]="${i}=${FINAL_ENV_VALUE}"
        		((USE_ENV_COUNT++))
		else
			case "x${i}" in
				xhost)
 					FINAL_ENV_VALUE="$(uname -m)"
					;;
				xtarget)
					FINAL_ENV_VALUE="${ARCH_NAME}"
					;;
				xvendor)
					FINAL_ENV_VALUE="unknown"
					;;
				*)
					FINAL_ENV_VALUE=""
					;;
			esac
			USE_ENV[${USE_ENV_COUNT}]="${i}=${FINAL_ENV_VALUE}"
        		((USE_ENV_COUNT++))
		fi
        	((TEMP_COUNT++))
        done
	echo $(IFS=' '; echo "${USE_ENV[*]}")
}


function test_filter_str
{
	declare FILTER_FILE="${1}"
	declare TEST_STR="${2}"
	declare RET_STR="0"
	declare GET_ENV_VALUE=""
	TEST_KEY=$(echo ${TEST_STR} | awk -F'=' '{ print $1 }')
	TEST_VALUE=$(echo "${TEST_STR}" | awk -F'=' '{ print $2 }')
	if [ "x${TEST_VALUE:0:1}" == "x?" ]; then
		TEST_VALUE_OPT=1
	else
		TEST_VALUE_OPT=0
	fi
	TEST_VALUE=$(echo "${TEST_STR}" | awk -F'=' '{ print $2 }' | sed "s@\&@,@g" | sed "s@^\?@@g")
	case "x${TEST_VALUE}" in
		"xHOST_ARCH")
			TEST_VALUE=$(uname -m)
			;;
		"xTARGET_ARCH")
			TEST_VALUE=${ARCH_NAME}
			;;
		"*")
			;;
	esac
	FILTER_STR="$(cat ${FILTER_FILE} | grep "^${TEST_KEY}=" | awk -F'=' '{ print $2 }')"

	GET_ENV_VALUE="$(cat ${NEW_TARGET_SYSDIR}/temp/set_env_${YONGBAO_BUILD_UUID}.conf | grep "^export YONGBAO_SET_ENV_${TEST_KEY}=" | awk -F'=' '{ print $2 }')"

	if [ "x${TEST_VALUE}" == "x" ] && [ "x${GET_ENV_VALUE}" == "x" ]; then
		case "x${TEST_KEY}" in
			"xhost")
				TEST_VALUE=$(uname -m)
				;;
			"xtarget")
				TEST_VALUE=${ARCH_NAME}
				;;
			*)
				;;
		esac
	fi

#	if [ "x${TEST_VALUE}" == "x" ] && [ "x${GET_ENV_VALUE}" == "x" ]; then
#		echo "0"
#		return
#	fi
	if [ "x${FILTER_STR}" != "x" ]; then
		for i in $(echo "${FILTER_STR}")
		do
#			echo "GET_ENV_VALUE=${GET_ENV_VALUE}  TEST_VALUE=${TEST_VALUE} i=${i:1}"
			case "x${i:0:1}" in
				"x!")
					if [ "x${i:1}" == "x${GET_ENV_VALUE}" ]; then
						echo "1"
						return;
					fi
					if [ "x${i:1}" == "x${TEST_VALUE}" ]; then
						echo "x${i:1}  test x${TEST_VALUE}" >> /tmp/a.log
						echo "1"
						return;
					fi
					RET_STR="0"
					;;
				*)
					if [ "x${TEST_VALUE_OPT}" == "x1" ]; then
						if [ "x${GET_ENV_VALUE}" != "x" ]; then
							if [ "x${i}" == "x${GET_ENV_VALUE}" ]; then
								RET_STR="0"
								break;
							else
								RET_STR="1"
							fi
						else
							if [ "x${i}" == "x${TEST_VALUE}" ]; then
								RET_STR="0"
								break;
							else
								RET_STR="1"
							fi
						fi
					else
						if [ "x${i}" == "x${TEST_VALUE}" ]; then
							RET_STR="0"
							break;
						else
							RET_STR="1"
						fi
					fi

# 					if [ "x${i}" == "x${TEST_VALUE}" ]; then
# 						RET_STR="0"
# 						break;
# 					else
# 						if [ "x${i}" == "x${GET_ENV_VALUE}" ]; then
# 							RET_STR="0"
# 							break;
# 						else
# 							RET_STR="1"
# 						fi
# 					fi
					;;
			esac
		done
	else
		echo "0"
		return
	fi
	echo "${RET_STR}"
}

# 对设置的参数与parmfilter文件中定义的内容进行测试
# 0 表示通过测试
# 1 表示未通过测试
function test_filter_form_opt
{
        declare SET_STR="${1}"

        for i in $(echo "${SET_STR}" | tr ";" "\\n")
        do
                if [ "x${i:0:1}" == "x%" ]; then
			case "x$(echo ${i:1} | awk -F'=' '{ print $1 }')" in
				"xOVERLAY" | "xPARENT" | "xVERSION")
					continue;
					;;
				*)
#					echo "test_filter_str ${2} ${i:1}"
#					test_filter_str "${2}" "${i:1}"
					if [ "x$(test_filter_str "${2}" "${i:1}")" == "x1" ]; then
						echo "1"
						return;
					fi
					continue;
					;;
			esac
		fi
        done
	echo "0"
}


function set_overlay_dir_form_opt
{
        declare SET_STR="${1}"

        for i in $(echo "${SET_STR}" | tr ";" "\\n")
        do
                if [ "x${i:0:1}" == "x%" ]; then
			case "x$(echo ${i:1} | awk -F'=' '{ print $1 }')" in
				"xOVERLAY")
					echo "$(echo ${i:1} | awk -F'=' '{ print $2 }' | sed "s@\&@,@g")"
					return;
					;;
				*)
					;;
			esac
		fi
        done
	echo ""
}

function set_parent_dir_form_opt
{
        declare SET_STR="${1}"

        for i in $(echo "${SET_STR}" | tr ";" "\\n")
        do
                if [ "x${i:0:1}" == "x%" ]; then
			case "x$(echo ${i:1} | awk -F'=' '{ print $1 }')" in
				"xPARENT")
					echo "$(echo ${i:1} | awk -F'=' '{ print $2 }' | sed "s@\&@,@g")"
					return;
					;;
				*)
					;;
			esac
		fi
        done
	echo ""
}

function set_version_index_form_opt
{
        declare SET_STR="${1}"

        for i in $(echo "${SET_STR}" | tr ";" "\\n")
        do
                if [ "x${i:0:1}" == "x%" ]; then
			case "x$(echo ${i:1} | awk -F'=' '{ print $1 }')" in
				"xVERSION")
					echo "$(echo ${i:1} | awk -F'=' '{ print $2 }' | sed "s@\&@,@g" | sed "s@[^?\|\.\|^[:alnum:]\|^[:space:]\|^_\|^-]@@g")"
					return;
					;;
				*)
					;;
			esac
		fi
        done
	echo ""
}


function get_unset_env_for_package
{
	echo "" > ${NEW_TARGET_SYSDIR}/temp/package_unset_${YONGBAO_BUILD_UUID}.conf

	for i in $(cat ${NEW_TARGET_SYSDIR}/temp/set_env_${YONGBAO_BUILD_UUID}.conf | grep "^export YONGBAO_SET_ENV_" | awk -F' YONGBAO_SET_ENV_' '{ print $2 }')
	do
		if [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.parmfilter ]; then
#			echo "test_filter_form_opt %${i} ${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.parmfilter"
#			echo "$(test_filter_form_opt "%${i}" "${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.parmfilter" )"
			if [ "x$(test_filter_form_opt "%${i}" "${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.parmfilter" )" == "x1" ]; then
				echo "unset YONGBAO_SET_ENV_$(echo ${i} | awk -F'=' '{ print $1 }')" >> ${NEW_TARGET_SYSDIR}/temp/package_unset_${YONGBAO_BUILD_UUID}.conf
			fi
		fi
	done
}


function get_all_can_set_env_str
{
        declare -a SET_ENV
        declare -a DEFAULT_ENV
        declare SET_COUNT=0
        declare TEMP_COUNT=0
        declare GET_ENV_VALUE=""
        declare SET_STR="${1}"
        declare -a USE_ENV=("")
        declare USE_ENV_COUNT=${#USE_ENV[@]}

        for i in $(echo "${SET_STR}" | tr ";" "\\n")
        do
                if [ "x${i:0:1}" == "x%" ]; then
			case "x$(echo ${i:1} | awk -F'=' '{ print $1 }')" in
#				"xPARENT")
				"xOVERLAY" | "xPARENT" | "xVERSION")
					continue
					;;
				*)
					;;
			esac

# 	                SET_ENV[${SET_COUNT}]=${i:1}
	                SET_ENV[${SET_COUNT}]=$(echo ${i:1} | awk -F'=' '{ print $1 }')
	                DEFAULT_ENV[${SET_COUNT}]=$(echo ${i:1} | awk -F'=' '{ print $2 }' | sed "s@\.@_@g" | sed "s@[^?\|^[:alnum:]\|^[:space:]\|^_\|^-]@@g")
        	        ((SET_COUNT++))
		fi
        done


	echo "" > ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf

        for i in ${SET_ENV[*]}
        do
		FINAL_ENV_VALUE=""
		GET_ENV_VALUE=""
		GET_ENV_VALUE="$(cat ${NEW_TARGET_SYSDIR}/temp/set_env_${YONGBAO_BUILD_UUID}.conf | grep "^export YONGBAO_SET_ENV_${i}=" | awk -F'=' '{ print $2 }')"
		if [ "x${DEFAULT_ENV[${TEMP_COUNT}]}" != "x" ]; then
			if [ "x${DEFAULT_ENV[${TEMP_COUNT}]:0:1}" == "x?" ]; then
				if [ "x${GET_ENV_VALUE}" != "x" ]; then
# 			                USE_ENV[${USE_ENV_COUNT}]=${GET_ENV_VALUE}
# 					echo "export YONGBAO_SET_ENV_${i}=${GET_ENV_VALUE}" >> ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf
					FINAL_ENV_VALUE="${GET_ENV_VALUE}"
				else
# 					USE_ENV[${USE_ENV_COUNT}]=${DEFAULT_ENV[${TEMP_COUNT}]:1}
# 					echo "export YONGBAO_SET_ENV_${i}=${DEFAULT_ENV[${TEMP_COUNT}]:1}" >> ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf
					FINAL_ENV_VALUE="${DEFAULT_ENV[${TEMP_COUNT}]:1}"
				fi
			else
# 				USE_ENV[${USE_ENV_COUNT}]=${DEFAULT_ENV[${TEMP_COUNT}]}
# 				echo "export YONGBAO_SET_ENV_${i}=${DEFAULT_ENV[${TEMP_COUNT}]}" >> ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf
				FINAL_ENV_VALUE="${DEFAULT_ENV[${TEMP_COUNT}]}"
			fi
		fi
		case "x${FINAL_ENV_VALUE}" in
			xHOST_ARCH)
				FINAL_ENV_VALUE="$(uname -m)"
				;;
			xTARGET_ARCH)
				FINAL_ENV_VALUE="${ARCH_NAME}"
				;;
			x)
				case "x${i}" in
					xhost)
						FINAL_ENV_VALUE="$(uname -m)"
						;;
					xtarget)
						FINAL_ENV_VALUE="${ARCH_NAME}"
						;;
					xvendor)
						FINAL_ENV_VALUE="unknown"
						;;
					*)
						;;
				esac
				;;
			*)
				;;
		esac
		if [ "x${FINAL_ENV_VALUE}" != "x" ]; then
			USE_ENV[${USE_ENV_COUNT}]="${FINAL_ENV_VALUE}"
			echo "export YONGBAO_SET_ENV_${i}=${FINAL_ENV_VALUE}" >> ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf
		fi
        	((USE_ENV_COUNT++))
        	((TEMP_COUNT++))

#		if [ "x${GET_ENV_VALUE}" != "x" ] || [ "x${DEFAULT_ENV[${TEMP_COUNT}]}" != "x" ]; then
#			if [ "x${GET_ENV_VALUE}" != "x" ]; then
#		                USE_ENV[${USE_ENV_COUNT}]=${GET_ENV_VALUE}
#			fi
#			if [ "x${DEFAULT_ENV[${TEMP_COUNT}]}" != "x" ]; then
#				if [ "x${DEFAULT_ENV[${TEMP_COUNT}]:0:1}" == "x?" ]; then
#					if [ "x${USE_ENV[${USE_ENV_COUNT}]}" == "x" ]; then
#						USE_ENV[${USE_ENV_COUNT}]=${DEFAULT_ENV[${TEMP_COUNT}]:1}
#						echo "export YONGBAO_SET_ENV_${i}=${DEFAULT_ENV[${TEMP_COUNT}]:1}" >> ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf
#					fi
#				else
#					USE_ENV[${USE_ENV_COUNT}]=${DEFAULT_ENV[${TEMP_COUNT}]}
#					echo "export YONGBAO_SET_ENV_${i}=${DEFAULT_ENV[${TEMP_COUNT}]}" >> ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf
#				fi
#			fi
#        		((USE_ENV_COUNT++))
#		fi
#        	((TEMP_COUNT++))
        done
	echo $(IFS=_; echo "${USE_ENV[*]}")
}

function get_can_set_status_file
{
        declare SET_STR="${1}"

        declare -a SET_ENV
        declare -a DEFAULT_ENV
        declare SET_COUNT=0
        declare TEMP_COUNT=0
        declare GET_ENV_VALUE=""
        declare -a USE_ENV=("")
        declare USE_ENV_COUNT=${#USE_ENV[@]}

        for i in $(echo "${SET_STR}" | tr ";" "\\n")
        do
                if [ "x${i}" == "xnone_status" ]; then
			echo "0"
			return
		fi
        done
	echo "1"
}

function format_package_env_to_string
{
	# echo "export YONGBAO_SET_ENV_${i}=${GET_ENV_VALUE}" >> ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf
	if [ -f ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf ]; then
		echo "$(grep "^export YONGBAO_SET_ENV_" ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf | sed "s/export YONGBAO_SET_ENV_//g" | sed -z "s@\n@,@g" | sed "s@,\$@@g")"
	else
		echo ""
	fi
}

function create_date_suff
{
	if [ ! -f ${NEW_TARGET_SYSDIR}/datetime_stemp ]; then
		DATA_SUFF="$(date +%Y%m%d%H%M%S)"
		echo -n "${DATA_SUFF}" > ${NEW_TARGET_SYSDIR}/datetime_stemp
	else
		DATA_SUFF="$(cat ${NEW_TARGET_SYSDIR}/datetime_stemp)"
	fi
}

function remove_date_suff
{
	rm -f ${NEW_TARGET_SYSDIR}/datetime_stemp
}

function get_true_overlay_dirname
{
	declare OVERLAY_DIR=""
	if [ "x${OPT_SET_OVERLAY_DIR}" == "x" ]; then
		if [ -f ${1} ]; then
			OVERLAY_DIR=$(cat ${1} | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
		else
			OVERLAY_DIR=""
		fi
	else
		OVERLAY_DIR=$(echo "${OPT_SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

	echo "${OVERLAY_DIR}"
}


function get_overlay_dirname
{
	declare OVERLAY_DIR=""

	if [ "x${OPT_SET_OVERLAY_DIR}" == "x" ]; then
		OVERLAY_DIR=$(cat ${1} | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
	else
		OVERLAY_DIR=$(echo "${OPT_SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

# 	if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
	if [ "x${SET_OVERLAY_DIR}" != "x" ] && [ "x${AUTO_SET_OVERLAY_DIR}" == "x0" ]; then
		OVERLAY_DIR=$(echo "${SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi
	echo "${OVERLAY_DIR}"
}

function fn_run_tempfix_file
{
	if [ "x${1}" == "x" ]; then
		return
	fi
	echo "${1}"
	declare STEP_STAGE="${1}"
	if [ -f ${SCRIPTS_DIR}/step/${1} ]; then
		echo -n "执行${STEP_STAGE}的临时修改脚本……"
		tools/run_package_script.sh ${WORLD_PARM} ${1} >${NEW_TARGET_SYSDIR}/logs/overlay_tempfix_file_$(basename ${STEP_STAGE})_0000.log 2>&1
		if [ "x$?" != "x0" ]; then
			echo "临时修改脚本执行错误，可查看 ${NEW_TARGET_SYSDIR}/logs/overlay_tempfix_file_$(basename ${STEP_STAGE})_0000.log 获取更详细的内容。"
			exit -3
		fi
		echo "完成。"
	fi
}

function fn_overlay_temp_fix_run
{
	if [ "x${1}" == "x" ]; then
		return
	fi
	declare STEP_STAGE="${1}"
	if [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}/overlay_temp_fix_run ]; then
		echo -n "执行${STEP_STAGE}的临时修改脚本……"
		tools/run_package_script.sh ${WORLD_PARM} ${STEP_STAGE}/overlay_temp_fix_run >${NEW_TARGET_SYSDIR}/logs/overlay_temp_fix_run_${STEP_STAGE}_0000.log 2>&1
		if [ "x$?" != "x0" ]; then
			echo "临时修改脚本执行错误，可查看 ${NEW_TARGET_SYSDIR}/logs/overlay_temp_fix_run_${STEP_STAGE}_0000.log 获取更详细的内容。"
			exit -3
		fi
		echo "完成。"
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
# 		OVERLAY_DIR=$(get_true_overlay_dirname ${2})
	else
		OVERLAY_DIR=""
	fi

#	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.released ]; then
		if [ "x${SET_PARENT_DIR}" == "x" ]; then
			if [ "x${OPT_SET_PARENT_DIR}" == "x" ]; then
# #				SET_PARENT_DIR="ORIG,${OVERLAY_DIR}"
				SET_PARENT_DIR="ORIG"
			else
# #				SET_PARENT_DIR="$(echo ",${OPT_SET_PARENT_DIR}," | sed "s@,ORIG,@,ORIG,${OVERLAY_DIR},@g")"
				SET_PARENT_DIR="${OPT_SET_PARENT_DIR}"
			fi
			AUTO_SET_PARENT_DIR=1
		else
			AUTO_SET_PARENT_DIR=0
		fi
# #		SET_PARENT_DIR="$(echo ",${SET_PARENT_DIR}," | sed "s@,ORIG,@,ORIG,${OVERLAY_DIR},@g")"
	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.released ]; then
		if [ "x${SET_OVERLAY_DIR}" == "x" ] || [ "x${SET_OVERLAY_DIR}" == "x${OVERLAY_DIR}.update" ]; then
			if [ x"$(echo ",${SET_PARENT_DIR}," | grep ",ORIG,")" != "x" ]; then
				SET_PARENT_DIR="${SET_PARENT_DIR},${OVERLAY_DIR}"
			fi
		fi
 	fi
# 	fi

# echo "Parent Dir: ${SET_PARENT_DIR}"

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
		for i in $(echo "${SET_PARENT_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
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
#			echo "设置${i} : ${LOWERDIR_SET_LIST}"
		done
		LOWERDIR_LIST="${LOWERDIR_SET_LIST}"
	fi
	if [ "x${LOWERDIR_LIST}" == "x" ]; then
		LOWERDIR_LIST="${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir"
	else
		LOWERDIR_LIST="${LOWERDIR_LIST}:${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir"
	fi
	
# echo "LOWERDIR_LIST: ${LOWERDIR_LIST}"

# echo "SET_OVERLAY_DIR: ${SET_OVERLAY_DIR}"
# echo "OVERLAY_DIR: ${OVERLAY_DIR}"

	if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
#		if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${i}.released ]; then
#			mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${SET_OVERLAY_DIR}.update
#			USE_OVERLAY_DIR="${NEW_TARGET_SYSDIR}/overlaydir/${SET_OVERLAY_DIR}.update:"
#			LOWERDIR_SET_LIST="${NEW_TARGET_SYSDIR}/overlaydir/${SET_OVERLAY_DIR}:${LOWERDIR_SET_LIST}"
#		else
			mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${SET_OVERLAY_DIR}
			USE_OVERLAY_DIR="${NEW_TARGET_SYSDIR}/overlaydir/${SET_OVERLAY_DIR}:"
#		fi
	else
		if [ "x${OVERLAY_DIR}" == "x" ]; then
			mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${1}
			OVERLAY_DIR=${1}
		fi

		if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.released ]; then
			mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.update
			USE_OVERLAY_DIR="${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.update:"
			LOWERDIR_SET_LIST="${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}:${LOWERDIR_SET_LIST}"
		else
			mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}
			USE_OVERLAY_DIR="${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}:"
		fi
	fi
	sync

	if [ "x${USE_OVERLAY_DIR}" == "x" ]; then
		echo "没有可挂载的sysroot ?"
		exit -3
	fi

	if [ "x${ONLY_PARENT_DIR}" == "x1" ] && [ "x${SINGLE_PACKAGE}" == "x1" ]; then
		USE_OVERLAY_DIR=""
	fi

# echo "USE_OVERLAY_DIR: ${USE_OVERLAY_DIR}"

	if ([ "x${OVERLAY_TEMP_FIX}" == "x1" ] && [ -f ${SCRIPTS_DIR}/step/${1}/overlay_temp_fix_run ]) || [ -f ${SCRIPTS_DIR}/step/${1}/${PACKAGE_NAME}.tempfix ]; then
		if [ -d ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME} ]; then
			mv ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}{,.$(date +%Y%m%d%H%M%S)}
		fi
		if [ -d ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change ]; then
			mv ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change{,.$(date +%Y%m%d%H%M%S)}
		fi
		mkdir -p ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}
		mkdir -p ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change
		sync
		sudo mount -t overlay overlay -o index=off,lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
		if [ "x$?" != "x0" ]; then
			echo "挂载sysroot错误！"
			echo "sudo mount -t overlay overlay -o index=off,lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
			exit -2
		fi
		if [ ! -f ${SCRIPTS_DIR}/step/${1}/${PACKAGE_NAME}.tempfix ]; then
			fn_overlay_temp_fix_run "${1}"
		else
			fn_run_tempfix_file "${1}/${PACKAGE_NAME}.tempfix"
		fi
		overlay_umount
		sync
#		sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
#		if [ "x$?" != "x0" ]; then
#			echo "挂载sysroot错误！"
#			echo "sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
#			exit -2
#		fi
	fi

	if [ "x${SINGLE_PACKAGE}" == "x1" ]; then
		if [ -f ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV} ] || [ -L ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV} ]; then
			mv ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}{,.bak$(date +%Y%m%d%H%M%S)}
		fi
		if [ -d ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST ]; then
			mv ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST{,.bak$(date +%Y%m%d%H%M%S)}
		fi
		if [ -d ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST.${DATA_SUFF} ]; then
			mv ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST.${DATA_SUFF}{,.bak$(date +%Y%m%d%H%M%S)}
		fi
		mkdir -p ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST.${DATA_SUFF}
		mkdir -p ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/.workerdir
		ln -sf DEST.${DATA_SUFF} ${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST
		sync

	        if ([ "x${OVERLAY_TEMP_FIX}" == "x1" ] && [ -f ${SCRIPTS_DIR}/step/${1}/overlay_temp_fix_run ]) || [ -f ${SCRIPTS_DIR}/step/${1}/${PACKAGE_NAME}.tempfix ]; then
#		if [ "x${OVERLAY_TEMP_FIX}" == "x1" ] && [ -f ${SCRIPTS_DIR}/step/${1}/overlay_temp_fix_run ]; then
# 			sudo mount -t overlay overlay -o index=off,lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			sudo mount -t overlay overlay -o index=off,lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST,workdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			if [ "x$?" != "x0" ]; then
				echo "挂载sysroot错误！"
# 				echo "sudo mount -t overlay overlay -o index=off,lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				echo "sudo mount -t overlay overlay -o index=off,lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST,workdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				exit -2
			fi
		else
# 			sudo mount -t overlay overlay -o index=off,lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			sudo mount -t overlay overlay -o index=off,lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST,workdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			if [ "x$?" != "x0" ]; then
				echo "挂载sysroot错误！"
# 				echo "sudo mount -t overlay overlay -o index=off,lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				echo "sudo mount -t overlay overlay -o index=off,lowerdir=${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/DEST,workdir=${NEW_TARGET_SYSDIR}/packages/${1}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				exit -2
			fi
		fi
	else
#		mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}
#		sync
		if ([ "x${OVERLAY_TEMP_FIX}" == "x1" ] && [ -f ${SCRIPTS_DIR}/step/${1}/overlay_temp_fix_run ]) || [ -f ${SCRIPTS_DIR}/step/${1}/${PACKAGE_NAME}.tempfix ]; then
#		if [ "x${OVERLAY_TEMP_FIX}" == "x1" ] && [ -f ${SCRIPTS_DIR}/step/${1}/overlay_temp_fix_run ]; then
#			if [ -d ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME} ]; then
#				mv ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}{,.$(date +%Y%m%d%H%M%S)}
#			fi
#			if [ -d ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change ]; then
#				mv ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change{,.$(date +%Y%m%d%H%M%S)}
#			fi
#			mkdir -p ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}
#			mkdir -p ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change
#			sync
#			sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}:${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
#			if [ "x$?" != "x0" ]; then
#				echo "挂载sysroot错误！"
#				echo "sudo mount -t overlay overlay -o lowerdir=${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}:${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change,workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
#				exit -2
#			fi
#			fn_overlay_temp_fix_run "${1}"
#			overlay_umount
#			sync
			sudo mount -t overlay overlay -o index=off,lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
			if [ "x$?" != "x0" ]; then
				echo "挂载sysroot错误！"
				echo "sudo mount -t overlay overlay -o index=off,lowerdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME}.change:${USE_OVERLAY_DIR}${LOWERDIR_LIST},upperdir=${NEW_TARGET_SYSDIR}/temp/temp_overlay/${1}/${PACKAGE_NAME},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
				exit -2
			fi
		else
			USE_OVERLAY_DIR="${USE_OVERLAY_DIR:0:-1}"
			if [ "x${OVERLAY_TEMP_FIX}" != "x2" ]; then  # 除了final_run之外的步骤
				sudo mount -t overlay overlay -o index=off,lowerdir=${LOWERDIR_LIST},upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
				if [ "x$?" != "x0" ]; then
					echo "挂载sysroot错误！"
					echo "sudo mount -t overlay overlay -o index=off,lowerdir=${LOWERDIR_LIST},upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
					exit -2
				fi
			else  # final_run步骤
				sudo mount -t overlay overlay -o index=off,lowerdir=${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir,upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot
				if [ "x$?" != "x0" ]; then
					echo "挂载sysroot错误！"
					echo "sudo mount -t overlay overlay -o index=off,lowerdir=${NEW_TARGET_SYSDIR}/overlaydir/.lowerdir,upperdir=${USE_OVERLAY_DIR},workdir=${NEW_TARGET_SYSDIR}/overlaydir/.workerdir ${NEW_TARGET_SYSDIR}/sysroot"
					exit -2
				fi
			fi
		fi
	fi
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
	sudo umount -R ${NEW_TARGET_SYSDIR}/cross-tools
	if [ "x$?" != "x0" ]; then
		echo "卸载cross-tools错误！"
		echo "sudo umount -R ${NEW_TARGET_SYSDIR}/cross-tools"
		exit -2
	fi
	sync
}

function get_string_stepname
{
        echo $(echo "${1}" | grep -o "[^:#%/]\{0,\}/" || echo "NULL") | head -n1 | sed "s@/@@g"
}

function get_string_pkgname
{
        echo $(echo "${1}" | grep -o "\(^[^/]\{1,\}$\|/\{1\}[^/]\{1,\}\)" || echo "NULL") | head -n1 | sed "s@/@@g"
}

function format_step_str
{
	declare STEPNAME=$(get_string_stepname "${1}")
	declare STEP_PKGNAME=$(get_string_pkgname "${1}")
	if [ "x${STEPNAME}" == "xNULL" ] && [ "x${STEP_PKGNAME}" == "xNULL" ]; then
		# 没有设置指定编译步骤
		echo ""
		return;
	fi
	if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" == "xNULL" ]; then
		# 设置了指定编译组
		FIND_STEP=$(find ${SCRIPTS_DIR}/step -maxdepth 1 -type d -name "${STEPNAME}"  | sed "s@${SCRIPTS_DIR}/step/@@g" )
		if [ "x${FIND_STEP}" != "x" ]; then
                        # 已找到指定步骤组：${FIND_STEP}
			echo "${FIND_STEP}/"
		else
                        # 没有找到指定的步骤组。
			echo "NULL"
		fi
		return;
	fi
	if [ "x${STEPNAME}" == "xNULL" ] && [ "x${STEP_PKGNAME}" != "xNULL" ]; then
		# 设置了指定编译包，但没有明确指定是哪个组里的包
		FIND_FILE=$(find ${SCRIPTS_DIR}/step -type f -name ${STEP_PKGNAME} | sed "s@${SCRIPTS_DIR}/step/@@g")
		if [ "x$(echo "${FIND_FILE}" | head -n1 )" != "x$(echo "${FIND_FILE}" | tail -n1 )" ]; then
			# 发现存在多个指定名字的软件包，请明确其指定具体所属步骤组，以下为找出的列表供参考
			echo "${FIND_FILE}"
		else
			if [ "x${FIND_FILE}" == "x" ]; then
				# 没有找到指定的软件包，尝试使用步骤组的名字来查找……
				echo $(format_step_str "${STEP_PKGNAME}/")
			else
				# 已找到指定名字软件包及其所属步骤组
				echo "$(find ${SCRIPTS_DIR}/step -name "${STEP_PKGNAME}" | sed "s@${SCRIPTS_DIR}/step/@@g")"
			fi
		fi
		return;
	fi
	if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" != "xNULL" ]; then
		# 指定了具体编译组中具体的包
		if [ -f ${SCRIPTS_DIR}/step/${STEPNAME}/${STEP_PKGNAME} ]; then
			# 已找到指定步骤组和软件包
			echo "${STEPNAME}/${STEP_PKGNAME}"
		else
			# 没有找到指定的步骤组及软件包，请检查指定的步骤组和软件包是否存在。
			echo "NULL"
		fi
		return;
	fi
	echo ""
	return;
}

function get_require
{
	declare STEPNAME=""
	STEPNAME=${1}
	declare STEP_LISTS="${2}"
	if [ ! -f ${NEW_BASE_DIR}/env/${STEPNAME}/overlay.set ]; then
		echo ""
		return;
	fi
	declare STEP_OVERLAY_NAME="$(cat ${NEW_BASE_DIR}/env/${STEPNAME}/overlay.set | grep "overlay_dir=" | tail -n1 | awk -F'=' '{ print $2 }')"
	declare STEP_PARENT_NAME="$(cat ${NEW_BASE_DIR}/env/${STEPNAME}/overlay.set | grep "parent_dirs=" | tail -n1 | awk -F'=' '{ print $2 }')"
	declare STEP_REQUIRES_NAME="$(cat ${NEW_BASE_DIR}/env/${STEPNAME}/overlay.set | grep "requires=" | tail -n1 | awk -F'=' '{ print $2 }')"

	if [ "x${STEP_OVERLAY_NAME}" != "x" ]; then
		for step_dir in $(grep -r "overlay_dir=${STEP_OVERLAY_NAME}" ${NEW_BASE_DIR}/env/* | sed "s@${NEW_BASE_DIR}/env@@g" | awk -F'/' '{ print $2 }')
		do
			if [[ "${STEP_LISTS}" != *" ${step_dir} "* ]]; then
				STEP_LISTS="${STEP_LISTS} ${step_dir} "
			fi
		done
	fi
	
	if [ "x${STEP_PARENT_NAME}" != "x" ]; then
		for parent_name in $(echo ${STEP_PARENT_NAME} | tr ',' '\n')
		do
			for step_dir in $(grep -r "overlay_dir=${parent_name}" ${NEW_BASE_DIR}/env/* | sed "s@${NEW_BASE_DIR}/env@@g" | awk -F'/' '{ print $2 }')
			do
				if [[ "${STEP_LISTS}" != *" ${step_dir} "* ]]; then
					STEP_LISTS="${STEP_LISTS} ${step_dir} "
				fi
			done
		done
	fi

	if [ "x${STEP_REQUIRES_NAME}" != "x" ]; then
		for require_name in $(echo ${STEP_REQUIRES_NAME} | tr ',' '\n')
		do
			if [ -f ${NEW_BASE_DIR}/env/${require_name}/config ]; then
				STEP_LISTS="${STEP_LISTS} ${require_name} "
			fi
		done
	fi

	echo "${STEP_LISTS}"
	return;
}

function get_requires
{
	declare STEPNAME=""
	STEPNAME="${1}"
	declare STEP_LISTS="${2}"

	if [ "x${STEPNAME}" == "x" ]; then
		echo ""
		return
	fi

	if [ ! -f ${NEW_BASE_DIR}/env/${STEPNAME}/overlay.set ]; then
		echo ""
		return;
	fi


	declare OLD_STEP_LISTS=""
	STEP_LISTS="${STEP_LISTS} ${1} "

	while [ "x$(echo "${STEP_LISTS}" | tr " " "\\n" | sort | uniq | grep -v "^$")" != "x$(echo "${OLD_STEP_LISTS}" | tr " " "\\n" | sort | uniq | grep -v "^$")" ]
	do
		OLD_STEP_LISTS="${STEP_LISTS}"
		for i in $(echo "${STEP_LISTS}" | tr " " "\\n" | sort | uniq | grep -v "^$")
		do
			STEP_LISTS="${STEP_LISTS} $(get_require "${i}" "")"
		done
	done
	echo "${STEP_LISTS}" | tr " " "\\n" | sort | uniq | grep -v "^$"
	return 
}


function get_default_opt
{
	declare -a USE_OPT
	declare -a NOUSE_OPT
	declare USE_COUNT=0
	declare NOUSE_COUNT=0
	for i in $(cat ${NEW_BASE_DIR}/env/opt.info | grep "^opt=")
	do
		OPT=$(echo ${i} | awk -F'=' '{ print $2 }')
		if [ "x${OPT:0:1}" == "x+" ]; then
			USE_OPT[${USE_COUNT}]=${OPT:1}
			((USE_COUNT++))
		else
			if [ "x${OPT:0:1}" == "x-" ]; then
				NOUSE_OPT[${NOUSE_COUNT}]=${OPT:1}
				((NOUSE_COUNT++))
			else
				USE_OPT[${USE_COUNT}]=${OPT}
				((USE_COUNT++))
			fi
		fi
	done
	echo "${USE_OPT[@]}"
}



function set_to_default_opt
{
	declare -a SET_OPT
	declare SET_COUNT=0
	declare SET_STR="${2}"
	declare -a USE_OPT=(${1})
	declare USE_COUNT=${#USE_OPT[@]}

	for i in $(echo "${SET_STR}" | tr ";" "\\n")
	do
                if [ "x${i}" == "xnone_status" ] || [ "x${i:0:1}" == "x%" ]; then
                        continue
                fi
                if [ "x${i}" != "x" ]; then
			SET_OPT[${SET_COUNT}]=${i}
			((SET_COUNT++))
		fi
	done


	for g in ${SET_OPT[*]}
	do
		for n in $(echo "${g}" | tr "," "\\n")
		do
			for i in $(echo "${n}" | tr "+" "\\n")
			do
				if [ "x${i}" == "xbad" ]; then
					continue;
				fi

				if [ "x${i:0:1}" == "x!" ]; then
					OPT=${i:1}
					for j in $(echo ${!USE_OPT[@]})
					do
						if [ "x${OPT}x" == "x${USE_OPT[${j}]}x" ]; then
							USE_OPT[${j}]=""
						fi
					done
				else
					USE_OPT[${USE_COUNT}]=${i}
					((USE_COUNT++))
				fi

			done
		done
	done
	echo "${USE_OPT[@]}"
}



# function set_to_default_opt
# {
#	declare -a SET_OPT
#	declare SET_COUNT=0
#	declare SET_STR="${2}"
#	declare -a USE_OPT=(${1})
#	declare USE_COUNT=${#USE_OPT[@]}
#
#	for i in $(echo "${SET_STR}" | tr "," "\\n")
#	do
#		SET_OPT[${SET_COUNT}]=${i}
#		((SET_COUNT++))
#	done
#
#	for i in ${SET_OPT[*]}
#	do
#		if [ "x${i}" == "xbad" ] || ( ( [ "x${i:0:1}" == "x+" ] || [ "x${i:0:1}" == "x-" ] ) && [ "x${i:1}" == "xbad" ] ); then
#			continue;
#		fi
#		if [ "x${i:0:1}" == "x-" ]; then
#			OPT=${i:1}
#			for j in $(echo ${!USE_OPT[@]})
#			do
#				if [ "x${OPT}x" == "x${USE_OPT[${j}]}x" ]; then
#					USE_OPT[${j}]=""
#				fi
#			done
#		else
#			if [ "x${i:0:1}" == "x+" ]; then
#				USE_OPT[${USE_COUNT}]=${i:1}
#			else
#				if [ "x${i:0:1}" != "x%" ]; then
#					USE_OPT[${USE_COUNT}]=${i}
#				fi
#			fi
#			((USE_COUNT++))
#		fi
#	done
#	echo "${USE_OPT[@]}"
# }




function test_opt
{
	declare TEST_COUNT=0
	declare TEST_STR="${2}"
	declare -a TEST_OPT
	declare OPT=""
	declare -a USE_OPT=(${1})
	declare USE_COUNT=${#USE_OPT[@]}
	declare ONCE_PASS=0

	if [ "x${TEST_STR}" == "x" ]; then
		echo "1"
		return
	fi

	for i in $(echo "${TEST_STR}" | tr "+" "\\n")
	do
		if [ "x${i}" != "x" ]; then
			TEST_OPT[${TEST_COUNT}]=${i}
			((TEST_COUNT++))
		fi
	done

	TEST_STATUS=0
	INVERT=0
	for i in ${TEST_OPT[*]}
	do
		INVERT=0
		TEST_STATUS=0

		case "x${i:0:1}" in
#			"x+")
#				OPT=${i:1}
#				INVERT=0
#				;;
			"x!")
				OPT=${i:1}
				INVERT=1
				;;
			*)
				OPT=${i}
				INVERT=0
				;;
		esac
#		if [ "x${INVERT}" == "x1" ]; then
#			TEST_STATUS=1
#		fi
		for j in $(echo ${USE_OPT[*]})
		do
			if [ "x${j}" == "x" ]; then
				continue
			fi
			if [ "x${OPT}x" == "x${j}x" ]; then
				if [ "x${INVERT}" == "x1" ]; then
					TEST_STATUS=0
					# ${i} 反标记找到，${1} 测试不通过"
					echo "0"
					return
				else
					# ${i} 在使用
					TEST_STATUS=1
				fi
				break;
			fi
		done
		if [ "x${INVERT}" == "x1" ]; then
			continue
		fi
		if [ "x${TEST_STATUS}" == "x0" ]; then
			# ${i} 标记没有找到，${1} 测试不通过"
			echo "0"
			return
		fi
	done

	# 全部找到，测试通过

	echo "1"
	return
}

function test_opt_group
{
	declare TEST_COUNT=0
	declare TEST_STR="${2}"
	declare -a TEST_OPT
	declare OPT=""
	declare -a USE_OPT=(${1})
	declare USE_COUNT=${#USE_OPT[@]}
	declare ONCE_PASS=0

	if [ "x${TEST_STR}" == "x" ]; then
		echo "1"
		return
	fi

	for i in $(echo "${TEST_STR}" | tr "," "\\n")
	do
		if [ "x${i}" != "x" ]; then
			TEST_OPT[${TEST_COUNT}]=${i}
			((TEST_COUNT++))
		fi
	done

	TEST_STATUS=0
	for i in ${TEST_OPT[*]}
	do
		if [ "x$(test_opt "${1}" "${i}")" == "x1" ]; then
			# 找到，测试通过
			TEST_STATUS=1
			echo "1"
			return
		fi
	done

	if [ "x${TEST_STATUS}" == "x0" ]; then
		# ${i} 标记没有找到，${1} 测试不通过"
		echo "0"
		return
	else
		# 找到，测试通过
		echo "1"
		return
	fi

}

function test_opt_can_run
{
	declare TEST_COUNT=0
	declare TEST_STR="${2}"
	declare -a TEST_OPT
	declare OPT=""
	declare -a USE_OPT=(${1})
	declare USE_COUNT=${#USE_OPT[@]}
	declare ONCE_PASS=0

	if [ "x${TEST_STR}" == "x" ]; then
		echo "1"
		return
	fi

	for i in $(echo "${TEST_STR}" | tr ";" "\\n")
	do
		if [ "x${i}" == "xnone_status" ] || [ "x${i:0:1}" == "x%" ]; then
			continue
		fi
		if [ "x${i}" != "x" ]; then
			TEST_OPT[${TEST_COUNT}]=${i}
			((TEST_COUNT++))
		fi
	done

	TEST_STATUS=0
	for i in ${TEST_OPT[*]}
	do
		if [ "x$(test_opt_group "${1}" "${i}")" == "x0" ]; then
			TEST_STATUS=1
			# ${i} 标记没有找到，${1} 测试不通过"
			echo "0"
			return
		fi
	done

	if [ "x${TEST_STATUS}" == "x0" ]; then
		# 全部找到，测试通过
		echo "1"
		return
	else
		# ${i} 标记没有找到，${1} 测试不通过"
		echo "0"
		return
	fi
}


function os_run_clean
{
	if [ "x${1}" == "x" ]; then
		return
	fi
	if [ "x${2}" == "x" ]; then
		return
	fi
	declare STEP_STAGE="${1}"
	declare PACKAGE_NAME="${2}"
	if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ]; then
# 		declare OS_RUN_OVERLAY_DIR=$(get_true_overlay_dirname ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set)
		declare OS_RUN_OVERLAY_DIR=$(get_overlay_dirname ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set)
		if [ ! -f ${NEW_TARGET_SYSDIR}/overlaydir/${OS_RUN_OVERLAY_DIR}.released ]; then
			if [ -f ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run ]; then
#				echo "清理 ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run "
				rm ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run
			fi
			if [ -f ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run ]; then
				rm ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run
			fi
			if [ -f ${NEW_TARGET_SYSDIR}/scripts/os_final_run/${OS_RUN_OVERLAY_DIR}/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run ]; then
				rm ${NEW_TARGET_SYSDIR}/scripts/os_final_run/${OS_RUN_OVERLAY_DIR}/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run
			fi
		else
			if [ -f ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run ]; then
#				echo "清理 ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run "
				rm ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run
			fi
			if [ -f ${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run ]; then
				rm ${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run
			fi
			if [ -f ${NEW_TARGET_SYSDIR}/scripts/update/os_final_run/${OS_RUN_OVERLAY_DIR}.update/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run ]; then
				rm ${NEW_TARGET_SYSDIR}/scripts/update/os_final_run/${OS_RUN_OVERLAY_DIR}.update/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run
			fi
		fi
	fi
	return
}

function create_os_run
{
	if [ "x${1}" == "x" ]; then
		return
	fi
	if [ "x${2}" == "x" ]; then
		return
	fi
	if [ "x${3}" == "x" ]; then
		return
	fi
	declare SCRIPT_FILE="${1}"
	declare STEP_STAGE="${2}"
	declare PACKAGE_NAME="${3}"
	declare PACKAGE_INDEX="${4}"
	if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ]; then
# 		declare OS_RUN_OVERLAY_DIR=$(get_true_overlay_dirname ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set)
		declare OS_RUN_OVERLAY_DIR=$(get_overlay_dirname ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set)
		if [ ! -f ${NEW_TARGET_SYSDIR}/overlaydir/${OS_RUN_OVERLAY_DIR}.released ]; then
#			if [ -f ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/${PACKAGE_NAME}_${STEP_STAGE}_${PACKAGE_INDEX} ]; then
			if [ -f ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/${STATUS_FILE} ] || [ "x${PACKAGE_NAME}" == "xfinal_run" ]; then
				if [ -f ${SCRIPTS_DIR}/step/${SCRIPT_FILE}.os_first_run ]; then
					echo ""
					echo "创建 ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run "
					tools/show_package_script.sh ${WORLD_PARM} -e -n ${SCRIPT_FILE} "os_first_run" > ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run
				fi
				if [ -f ${SCRIPTS_DIR}/step/${SCRIPT_FILE}.os_start_run ]; then
					echo ""
					echo "创建 ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run "
#					echo " tools/show_package_script.sh ${WORLD_PARM} -e -n ${SCRIPT_FILE} "os_start_run" > ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run"
					tools/show_package_script.sh ${WORLD_PARM} -e -n ${SCRIPT_FILE} "os_start_run" > ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run
				fi
				if [ -f ${SCRIPTS_DIR}/step/${SCRIPT_FILE}.os_final_run ]; then
					echo ""
					echo "创建 ${NEW_TARGET_SYSDIR}/scripts/os_final_run/${OS_RUN_OVERLAY_DIR}/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run "
					mkdir -p ${NEW_TARGET_SYSDIR}/scripts/os_final_run/${OS_RUN_OVERLAY_DIR}
					tools/show_package_script.sh ${WORLD_PARM} -e -n ${SCRIPT_FILE} "os_final_run" > ${NEW_TARGET_SYSDIR}/scripts/os_final_run/${OS_RUN_OVERLAY_DIR}/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.${PACKAGE_NAME}.run
				fi
			fi
		else
#			echo "${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/${STATUS_FILE} ...."
#			if [ -f ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/${PACKAGE_NAME}_${STEP_STAGE}_${PACKAGE_INDEX} ]; then
			if [ -f ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/${STATUS_FILE} ] || [ "x${PACKAGE_NAME}" == "xfinal_run" ]; then
				if [ -f ${SCRIPTS_DIR}/step/${SCRIPT_FILE}.os_first_run ]; then
					echo ""
					echo "创建 ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run "
					tools/show_package_script.sh ${WORLD_PARM} -e -n ${SCRIPT_FILE} "os_first_run" > ${NEW_TARGET_SYSDIR}/scripts/update/os_first_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run
				fi
				if [ -f ${SCRIPTS_DIR}/step/${SCRIPT_FILE}.os_start_run ]; then
					echo ""
					echo "创建 ${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run "
					tools/show_package_script.sh ${WORLD_PARM} -e -n ${SCRIPT_FILE} "os_start_run" > ${NEW_TARGET_SYSDIR}/scripts/update/os_start_run/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run
				fi
				if [ -f ${SCRIPTS_DIR}/step/${SCRIPT_FILE}.os_final_run ]; then
					echo ""
					echo "创建 ${NEW_TARGET_SYSDIR}/scripts/update/os_final_run/${OS_RUN_OVERLAY_DIR}.update/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run "
					mkdir -p ${NEW_TARGET_SYSDIR}/scripts/update/os_final_run/${OS_RUN_OVERLAY_DIR}.update
					tools/show_package_script.sh ${WORLD_PARM} -e -n ${SCRIPT_FILE} "os_final_run" > ${NEW_TARGET_SYSDIR}/scripts/update/os_final_run/${OS_RUN_OVERLAY_DIR}.update/${STEP_STAGE}.${OS_RUN_OVERLAY_DIR}.update.${PACKAGE_NAME}.run
				fi
			fi
		fi
	fi
}


function step_to_index
{
	declare STEP_COUNT=1
	declare SHOW_COUNT=1
	declare TMP_NAME=""
	declare COUNT_NAME="STEP_COUNT"
	declare ALL_COUNT=0

	declare -a USE_OPT
	declare USE_COUNT=0

	declare STEPNAME=""
	declare STEP_PKGNAME=""
	declare STEP_PKG_STR="${1}" 
	declare STEP_PKG_OPT=""
	declare REQUIRES_STEPS=""
	declare GREP_STR=""
	declare STOP_STEP_PKGNAME=""
	declare STOP_STEP_OPT=""
	declare STOP_STEP_GROUP=""
	declare STOP_STEP_STR=""

	if [ ! -f ${NEW_BASE_DIR}/env/opt.info ]; then
		echo "警告：没有发现env/opt.info文件，本次制作选取的软件包将采用默认的设置。默认设置为：-fopt、-gopt"
	fi
	USE_OPT=($(get_default_opt))
 	USE_OPT=($(set_to_default_opt "$(echo ${USE_OPT[@]})" "${OPT_SET_STR}"))
	USE_COUNT=${#USE_OPT[@]}

	if [ "x${STEP_PKG_STR}" != "x" ]; then
		FORMAT_STRING=$(format_step_str "${STEP_PKG_STR}")
		echo "指定了编译步骤：${FORMAT_STRING}"
		if [ "x${FORMAT_STRING}" == "xNULL" ]; then
			echo "错误：指定的软件包或步骤组 ${STEP_PKG_STR} 不存在，请检查是否输入正确。"
			exit 1
		fi
		if [ $(echo "${FORMAT_STRING}" | head -n1) != $(echo "${FORMAT_STRING}" | tail -n1) ]; then
			echo "错误：发现了多个指定的编译步骤，请参考以下列表，重新指定具体的步骤："
			echo "${FORMAT_STRING}"
			exit 1
		fi
	        STEPNAME=$(get_string_stepname "${FORMAT_STRING}")
        	STEP_PKGNAME=$(get_string_pkgname "${FORMAT_STRING}")
		if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" != "xNULL" ]; then
			STEP_PKG_OPT=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/${STEP_PKGNAME}|" | sort | uniq | tail -n1 | awk -F'|' '{ print $2 }')
			STOP_STEP_PKGNAME=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/${STEP_PKGNAME}|" | sort | uniq | tail -n1 | awk -F'|' '{ print $1 }')
			STOP_STEP_OPT=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/${STEP_PKGNAME}|" | sort | uniq | tail -n1 | awk -F'|' '{ print $2 }')
			STOP_STEP_GROUP="${STOP_STEP_PKGNAME}"
			STOP_STEP_STR="${STOP_STEP_PKGNAME}"
		fi
		if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" == "xNULL" ]; then
			STEP_PKG_OPT=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/" | head -n1 | awk -F'|' '{ print $2 }')
			STOP_STEP_PKGNAME=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/" | tail -n1 | awk -F'|' '{ print $1 }')
			STOP_STEP_OPT=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/" | tail -n1 | awk -F'|' '{ print $2 }')
			STOP_STEP_GROUP="%step/${STEPNAME}/"
			STOP_STEP_STR="${STOP_STEP_PKGNAME}"
		fi

#		echo "因指定了编译步骤，需测试编译的相关组，相关组如下："
#		echo "${STEPNAME}"
		get_requires "${STEPNAME}" ""
		REQUIRES_STEPS="${STEPNAME} $(get_requires "${STEPNAME}" "")"
		GREP_STR=$(echo ${REQUIRES_STEPS} | sed "s@\([^ ]*\)@ -e \"step/&/\"@g")
#		echo "筛选字串： ${GREP_STR}"

	fi
	USE_OPT=($(set_to_default_opt "$(echo ${USE_OPT[@]})" "${STEP_PKG_OPT}"))

#	echo "停止步骤名：${STOP_STEP_PKGNAME}"

	echo "当前指定的编译标记如下："
	echo "${USE_OPT[@]}"

	echo "初始化各组计数器..."
	for i in $(cat "${SOURCE_STEP_FILE}" | grep "^%step" | awk -F'/' '{ print $2 }' | sort | uniq)
	do
		declare ${i/-/_}_COUNT=1
	done

	echo "开始筛选符合条件的步骤..."
	for i in $(cat "${SOURCE_STEP_FILE}" | grep "^%step")
	do
		STEP_NAME=$(echo ${i} | awk -F'|' '{ print $1 }')
		STEP_OPT=$(echo ${i} | awk -F'|' '{ print $2 }')

		if [ "x${STEP_NAME##*/}" == "xNULL" ]; then
			TMP_NAME=$(echo ${STEP_NAME} | awk -F'/' '{ print $2 }')
			((${TMP_NAME/-/_}_COUNT=1))
			continue;
		fi

		TMP_NAME=$(echo ${STEP_NAME} | awk -F'/' '{ print $2 }')
		COUNT_NAME=${TMP_NAME/-/_}_COUNT
		printf -v SHOW_COUNT "%05d" ${!COUNT_NAME}


		# echo "test_opt_can_run \"$(echo ${USE_OPT[@]})\" \"${STEP_OPT}\""
		# test_opt_can_run "$(echo ${USE_OPT[@]})" "${STEP_OPT}"
		if [ "x$(test_opt_can_run "$(echo ${USE_OPT[@]})" "${STEP_OPT}")" == "x1" ]; then
#			echo "${i} 符合条件... ${USE_OPT[@]}"
			if [ "x${GREP_STR}" == "x" ]; then
				echo -n "${SHOW_COUNT}  "
				echo -n $(echo ${STEP_NAME} | sed "s@^%@@g")
				echo "|${STEP_OPT}"
			else
				GREP_RET=0
				if [ "x${REQUIRES_BUILD}" == "x0" ]; then
					eval  "echo ${STEP_NAME} | sed "s@^%@@g" | grep ${GREP_STR} > /dev/null"
					GREP_RET=$?
				fi
#				if [ "$?" == "0" ]; then
				if [ "${GREP_RET}" == "0" ]; then
					if [ "x${REQUIRES_BUILD}" == "x0" ]; then
						if [ "x${STOP_STEP_STR}" == "x${STEP_NAME}" ] || [ "${STEP_NAME%/*}/" == "${STOP_STEP_GROUP}" ] || ( [[ "${STEP_NAME}" =~ "${STOP_STEP_GROUP%/*}/" ]] && ( [ "x${STEP_NAME##*/}" == "xbegin_run" ] || [ "x${STEP_NAME##*/}" == "xfinal_run" ] || [ "x${STEP_NAME##*/}" == "xoverlay_before_run" ] || [ "x${STEP_NAME##*/}" == "xoverlay_after_run" ] || [ "x${STEP_NAME##*/}" == "xoverlay_temp_fix_run" ] ) ); then
							echo -n "${SHOW_COUNT}  "
							echo -n $(echo ${STEP_NAME} | sed "s@^%@@g")
							echo "|${STEP_OPT}"
						fi
					else
						if [ "${STEP_NAME%/*}/" == "${STOP_STEP_GROUP}" ]; then
							GROUP_IN_BUILD=0
						fi
						if [ "x${GROUP_IN_BUILD}" == "x0" ]; then
							echo -n "${SHOW_COUNT}  "
							echo -n $(echo ${STEP_NAME} | sed "s@^%@@g")
							echo "|${STEP_OPT}"
						fi
					fi
					if [ "x${STOP_STEP_PKGNAME}" == "x${STEP_NAME}" ] && [ "x${STOP_STEP_OPT}" == "x${STEP_OPT}" ]; then
						break;
					fi
				fi
			fi
		fi

		if [ "x${STEP_NAME##*/}" != "xbegin_run" ] && [ "x${STEP_NAME##*/}" != "xfinal_run" ] && [ "x${STEP_NAME##*/}" != "xoverlay_before_run" ] && [ "x${STEP_NAME##*/}" != "xoverlay_after_run" ] && [ "x${STEP_NAME##*/}" != "xoverlay_temp_fix_run" ]; then
			((${COUNT_NAME}++))
		fi
	done > ${INDEX_STEP_FILE}
#       done > ${NEW_TARGET_SYSDIR}/step.index

	# 加入final_run脚本
# 	GROUP_STR="$(cat ${NEW_TARGET_SYSDIR}/step.index | awk -F'/' '{ print $2}' | sort | uniq)"
	GROUP_STR="$(cat "${INDEX_STEP_FILE}" | awk -F'/' '{ print $2}' | sort | uniq)"
	for i in ${GROUP_STR}
	do
		if [ x"$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${i}/final_run")" != "x" ]; then
#			if [ x"$(cat ${NEW_TARGET_SYSDIR}/step.index | grep "step/${i}/final_run")" == "x" ]; then
#				echo "00000  step/${i}/final_run|" >> ${NEW_TARGET_SYSDIR}/step.index
			if [ x"$(cat "${INDEX_STEP_FILE}" | grep "step/${i}/final_run")" == "x" ]; then
				echo "00000  step/${i}/final_run|" >> ${INDEX_STEP_FILE}
			fi
		fi
	done
}


function cp_file_and_sources
{
	if [ -f ${NEW_BASE_DIR}/downloads/sources/files.${YONGBAO_BUILD_UUID}.list ]; then
		mkdir -p ${NEW_TARGET_SYSDIR}/downloads/files/
		if [ "x${1}" == "x" ]; then
			echo -n "复制所需的源码包文件..."
		fi
		for cp_file in $(cat ${NEW_BASE_DIR}/downloads/sources/files.${YONGBAO_BUILD_UUID}.list | sort | uniq)
		do
			cp ${NEW_BASE_DIR}/downloads/sources/files/${cp_file} ${NEW_TARGET_SYSDIR}/downloads/files/
		done
		if [ "x${1}" == "x" ]; then
			echo "完成。"
		fi
		rm -f ${NEW_BASE_DIR}/downloads/sources/files.${YONGBAO_BUILD_UUID}.list
	fi
	if [ -f ${NEW_BASE_DIR}/downloads/sources/resources.${YONGBAO_BUILD_UUID}.list ]; then
		mkdir -p ${NEW_TARGET_SYSDIR}/files/
		if [ "x${1}" == "x" ]; then
			echo -n "复制所需的资源文件..."
		fi
		cp -a ${NEW_BASE_DIR}/files/step/* ${NEW_TARGET_SYSDIR}/files/
		pushd ${NEW_BASE_DIR}/downloads/files/step > /dev/null
			for cp_file in $(cat ${NEW_BASE_DIR}/downloads/sources/resources.${YONGBAO_BUILD_UUID}.list | sort | uniq)
			do
				cp --parents ${cp_file} ${NEW_TARGET_SYSDIR}/files/
			done
		popd > /dev/null
		if [ "x${1}" == "x" ]; then
			echo "完成。"
		fi
		rm -f ${NEW_BASE_DIR}/downloads/sources/resources.${YONGBAO_BUILD_UUID}.list
	fi

}

function start_download_source
{
	echo -n -e "\033[2K\r下载 ${1} 所需的源码包及资源文件..."
	for down_retry in 1 2 3
	do
		tools/get_all_package_url.sh ${WORLD_PARM} -a ${USE_PROXY_DOWNLOAD} -s ${1} > /dev/null
		if [ "x$?" == "x0" ]; then
			echo "完成！"
			break;
		else
			echo -e "\e[32m失败！\e[0m"
		fi
		echo -n "尝试再次下载 ${1} 所需的源码包及资源文件..."
	done
	cp_file_and_sources 0
}

function start_download_source_for_version_index
{
	echo -n -e "\033[2K\r下载 ${1} 所需的源码包及资源文件..."
	for down_retry in 1 2 3
	do
		if [ "x${2}" != "x" ]; then
			tools/get_all_package_url.sh ${WORLD_PARM} -a -v "${2}" ${USE_PROXY_DOWNLOAD} -s ${1} > /dev/null
		else
			tools/get_all_package_url.sh ${WORLD_PARM} -a ${USE_PROXY_DOWNLOAD} -s ${1} > /dev/null
		fi
		if [ "x$?" == "x0" ]; then
			echo "完成！"
			break;
		else
			echo -e "\e[32m失败！\e[0m"
		fi
		echo -n "尝试再次下载 ${1} 所需的源码包及资源文件..."
	done
	cp_file_and_sources 0
}

function save_watch_step
{
	WATCH_ID_TEMP=$(date +%s)
	if [ -f ${SCRIPTS_DIR}/step/${1}/${2}.watch_step ]; then
# 		cat ${SCRIPTS_DIR}/step/${1}/${2}.watch_step | grep -v "^#" | while read watch_line
# 		do
		while IFS= read -r watch_line; do
			[[ $watch_line == "#"* ]] && continue
			WATCH_STAGE=$(echo "${watch_line}" | awk -F'/' '{ print $1 }')
			WATCH_PACKAGE_NAME=$(echo "${watch_line}" | awk -F'/' '{ print $2 }')
			if [ "x${WATCH_PACKAGE_NAME}" == "x" ]; then
				WATCH_PACKAGE_NAME=${WATCH_STAGE}
				WATCH_STAGE=${1}
			fi
			if [ ! -d ${NEW_TARGET_SYSDIR}/notice/${WATCH_STAGE}/${WATCH_PACKAGE_NAME}/ ]; then
				mkdir -p ${NEW_TARGET_SYSDIR}/notice/${WATCH_STAGE}/${WATCH_PACKAGE_NAME}
			fi
			WATCH_PACKAGE_FILE="${WATCH_STAGE}/${WATCH_PACKAGE_NAME}/$(echo ${3} | sed -e "s@^${2}_@NAME${2}NAME_@g" -e "s@_${1}_[0-9]\{5\}@_STAGE${1}STAGE@g")"
			echo ${WATCH_ID_TEMP} > ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE}
			touch ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE}.status
		done < "${SCRIPTS_DIR}/step/${1}/${2}.watch_step"
# 		done
	fi
	echo "${WATCH_ID_TEMP}"
	return
}

function update_watch_id
{
	if [ -f ${SCRIPTS_DIR}/step/${1}/${2}.watch_step ]; then
		cat ${SCRIPTS_DIR}/step/${1}/${2}.watch_step | grep -v "^#" | while read watch_line
		do
			WATCH_STAGE=$(echo "${watch_line}" | awk -F'/' '{ print $1 }')
			WATCH_PACKAGE_NAME=$(echo "${watch_line}" | awk -F'/' '{ print $2 }')
			if [ "x${WATCH_PACKAGE_NAME}" == "x" ]; then
				WATCH_PACKAGE_NAME=${WATCH_STAGE}
				WATCH_STAGE=${1}
			fi
			if [ ! -d ${NEW_TARGET_SYSDIR}/notice/${WATCH_STAGE}/${WATCH_PACKAGE_NAME}/ ]; then
				mkdir -p ${NEW_TARGET_SYSDIR}/notice/${WATCH_STAGE}/${WATCH_PACKAGE_NAME}
			fi
			WATCH_PACKAGE_FILE="${WATCH_STAGE}/${WATCH_PACKAGE_NAME}/$(echo ${3} | sed -e "s@^${2}_@NAME${2}NAME_@g" -e "s@_${1}_[0-9]\{5\}@_STAGE${1}STAGE@g")"
			echo "${4}" > ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE}
			touch ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE}.status

# 			if [ ! -f ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE} ]; then
# 				WATCH_ID_TEMP=$(date +%s)
# 				echo ${WATCH_ID_TEMP} > ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE}
# 				echo ${WATCH_ID_TEMP}
# 			else
# 				cat ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE} | head -n1
# 			fi

		done
	fi
	return
}

function update_notice_package
{
	if [ "x${3}" == "x" ]; then
		return
	fi
	if [ -d ${NEW_TARGET_SYSDIR}/notice/${1}/${2}/ ]; then
 		find ${NEW_TARGET_SYSDIR}/notice/${1}/${2}/ -name "$(echo ${3} | sed -e "s@^${2}_@NAME\*NAME_@g" -e "s@_${1}_[0-9]\{5\}@_STAGE\*STAGE@g").status" -exec mv '{}' '{}.bak' ';'
# 		find ${NEW_TARGET_SYSDIR}/notice/${1}/${2}/ -name "$(echo ${3} | sed -e "s@^${2}_@NAME\*NAME_@g" -e "s@_${1}_[0-9]\{5\}@_STAGE\*STAGE@g")" -exec echo "${4}" > '{}' ';'
# 		find ${NEW_TARGET_SYSDIR}/notice/${1}/${2}/ -name "$(echo ${3} | sed -e "s@^${2}_@NAME\*NAME_@g" -e "s@_${1}_[0-9]\{5\}@_STAGE\*STAGE@g")" -exec bash -c 'echo "${4}" > "{}"' ';'
		find ${NEW_TARGET_SYSDIR}/notice/${1}/${2}/ -name "$(echo ${3} | sed -e "s@^${2}_@NAME\*NAME_@g" -e "s@_${1}_[0-9]\{5\}@_STAGE\*STAGE@g")" -exec bash -c 'echo "$1" > "{}"' -- "${4}" ';'
		echo "${4}" > ${NEW_TARGET_SYSDIR}/notice/${1}/${2}/${3}
	fi
}

function test_watch_step
{
	CURRENT_WATCH_ID=0
	TEMP_WATCH_ID=0
	GET_WATCH_ID=0
	if [ -d ${NEW_TARGET_SYSDIR}/notice/${1}/${2} ]; then
		if [ -f ${NEW_TARGET_SYSDIR}/notice/${1}/${2}/${3} ]; then
# 			echo "${NEW_TARGET_SYSDIR}/notice/${1}/${2}/${3}"
			TEMP_WATCH_ID=$(cat ${NEW_TARGET_SYSDIR}/notice/${1}/${2}/${3} | head -n1)
		else
# 			echo "${NEW_TARGET_SYSDIR}/status/${1}/${3}"
			TEMP_WATCH_ID=$(stat -c %Y ${NEW_TARGET_SYSDIR}/status/${1}/${3})
		fi
	fi
# 	echo "TEMP_WATCH_ID: ${TEMP_WATCH_ID}"
	if [ -f ${SCRIPTS_DIR}/step/${1}/${2}.watch_step ]; then
# 		cat ${SCRIPTS_DIR}/step/${1}/${2}.watch_step | grep -v "^#" | while read watch_line
# 		do
		while IFS= read -r watch_line; do
			[[ $watch_line == "#"* ]] && continue

			WATCH_STAGE=$(echo "${watch_line}" | awk -F'/' '{ print $1 }')
			WATCH_PACKAGE_NAME=$(echo "${watch_line}" | awk -F'/' '{ print $2 }')
			if [ "x${WATCH_PACKAGE_NAME}" == "x" ]; then
				WATCH_PACKAGE_NAME=${WATCH_STAGE}
				WATCH_STAGE=${1}
			fi
			if [ -d ${NEW_TARGET_SYSDIR}/notice/${WATCH_STAGE}/${WATCH_PACKAGE_NAME} ]; then
				WATCH_PACKAGE_FILE="${WATCH_STAGE}/${WATCH_PACKAGE_NAME}/$(echo ${3} | sed -e "s@^${2}_@NAME${2}NAME_@g" -e "s@_${1}_[0-9]\{5\}@_STAGE${1}STAGE@g")"
				if [ -f ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE}.status ]; then
					continue;
				else
					if [ -f ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE} ]; then
# 						GET_WATCH_ID=$(cat ${NEW_TARGET_SYSDIR}/notice/${WATCH_STAGE}/${WATCH_PACKAGE_NAME}/$(echo ${3} | sed -e "s@^${2}_@NAME${2}NAME_@g" -e "s@_${1}_[0-9]\{5\}@_STAGE${1}STAGE@g"))
# 						echo "cat ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE}"
# 						echo "GET_WATCH_ID: $(cat ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE})"
						GET_WATCH_ID=$(cat ${NEW_TARGET_SYSDIR}/notice/${WATCH_PACKAGE_FILE})
						if [ "x${GET_WATCH_ID}" == "x" ]; then
							GET_WATCH_ID=$(date +%s)
						fi
						CURRENT_WATCH_ID=$(( CURRENT_WATCH_ID < GET_WATCH_ID ? GET_WATCH_ID : CURRENT_WATCH_ID ))
					else
						CURRENT_WATCH_ID=$(date +%s)
					fi
				fi
			else
				CURRENT_WATCH_ID=$(date +%s)
				continue;
			fi
		done < "${SCRIPTS_DIR}/step/${1}/${2}.watch_step"
# 		done
	fi

# 	if [ "x${CURRENT_WATCH_ID}" == "x0" ]; then
# 		echo "0"
# 		return
# 	fi

	if [ "x${TEMP_WATCH_ID}" == "x${CURRENT_WATCH_ID}" ]; then
		echo "0"
		return
	fi

# 	if [ -d ${NEW_TARGET_SYSDIR}/notice/${1}/${2} ]; then
# 		if (( CURRENT_WATCH_ID > GET_WATCH_ID )); then
# 			echo "1"
# 			return
# 		fi
# 	fi

# 	echo "${CURRENT_WATCH_ID}"
	echo "$(( CURRENT_WATCH_ID >= TEMP_WATCH_ID ? CURRENT_WATCH_ID : 0 ))"
	return
}

function get_package_version
{
	if [ -f ${SCRIPTS_DIR}/step/${1}/${2}.info ]; then
		echo "$(cat ${SCRIPTS_DIR}/step/${1}/${2}.info | awk -F'|' '{ print $2 }')"
	else
		echo "unknown"
	fi
}


function packagedir_to_pack
{
# packagedir_to_pack "${NEW_TARGET_SYSDIR}/packages/${STEP_STAGE}/${PACKAGE_NAME}${PACKAGE_SET_ENV}" "DEST.${DATA_SUFF}" "${ORIG_OVERLAY_DIR}" "${PACKAGE_NAME}" "${PACKAGE_VERSION}" "$([[ "${PACKAGE_SET_ENV}" == "" ]] && echo "loongarch64" || echo "$(echo "${PACKAGE_SET_ENV}" | sed "s@^_@@g")")"
# 	echo "Add ${1}" >> ${NEW_TARGET_SYSDIR}/temp/cover_package.txt
	if [ -d ${1}/${2}.strip ]; then
		mv ${1}/${2}.strip{,.$(date +%Y%m%d%H%M%S)}
	fi
	echo -n "清理独立软件包目录 ${1}/${2} ..."
	cp -a ${1}/${2} ${1}/${2}.strip

# 	echo "tools/strip_step.sh ${WORLD_PARM} ${3} ${1}/${2}.strip"  >> ${NEW_TARGET_SYSDIR}/temp/cover_package.txt

# 	echo "tools/strip_step.sh ${WORLD_PARM} ${3} ${1}/${2}.strip  > ${1}/${2}.strip.single_strip.log 2>&1 || true"  >> ${NEW_TARGET_SYSDIR}/temp/cover_package.txt
# 	echo "tools/final_step.sh ${WORLD_PARM} ${3} ${1}/${2}.strip  > ${1}/${2}.strip.single_final_fix.log 2>&1 || true"  >> ${NEW_TARGET_SYSDIR}/temp/cover_package.txt

	tools/strip_step.sh ${WORLD_PARM} ${3} ${1}/${2}.strip  > ${1}/${2}.strip.single_strip.log 2>&1 || true
	tools/final_step.sh ${WORLD_PARM} ${3} ${1}/${2}.strip  > ${1}/${2}.strip.single_final_fix.log 2>&1 || true
	echo "完成。"
	echo "进行打包 ..."
	tools/pack_archive_dir.sh ${WORLD_PARM} -f -n "${4}-${5}.${6}"  ${1}/${2}.strip "${3}" "pkg" "${SINGLE_PACKAGE_TAR}"
}


mkdir -p ${NEW_TARGET_SYSDIR}
mkdir -p ${NEW_TARGET_SYSDIR}/temp

declare -a USE_SET_ENV
declare USE_SET_ENV_COUNT=0
	
USE_SET_ENV=($(set_build_env "" "${OPT_SET_ENV}"))
USE_SET_ENV_COUNT=${#USE_SET_ENV[@]}

echo -n "" > ${NEW_TARGET_SYSDIR}/temp/set_env_${YONGBAO_BUILD_UUID}.conf
for set_env in ${USE_SET_ENV[*]}
do
	ENV_KEY=$(echo ${set_env} | awk -F'=' '{ print $1 }')
	ENV_VALUE=$(echo ${set_env} | awk -F'=' '{ print $2 }')
	echo "export YONGBAO_SET_ENV_${ENV_KEY}=${ENV_VALUE}" >> ${NEW_TARGET_SYSDIR}/temp/set_env_${YONGBAO_BUILD_UUID}.conf
done
echo "" > ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf


create_date_suff

if [ -f ${NEW_TARGET_SYSDIR}/logs/build_error.log ]; then
	mv ${NEW_TARGET_SYSDIR}/logs/build_error.log{,.$(stat -c %Y ${NEW_TARGET_SYSDIR}/logs/build_error.log)}
fi

# 保存完整的执行命令，以备后续查看。
echo "${FULL_COMMAND}" >> ${NEW_TARGET_SYSDIR}/command_save.txt

if [ "x${SET_INDEX_STEP_FILE}" == "x" ] || [ "x${EXPORT_STEP}" == "x1" ]; then
	if [ "x${SET_INDEX_STEP_FILE}" == "x" ]; then
		INDEX_STEP_FILE="${NEW_TARGET_SYSDIR}/step.index"
		INDEX_MD5SUM_FILE="step.md5sum"
	else
		INDEX_STEP_FILE="${SET_INDEX_STEP_FILE}"
		INDEX_MD5SUM_FILE="custom_$(basename ${INDEX_STEP_FILE}).md5sum"
	fi
	echo "创建索引文件......"
	step_to_index "${1}"
	echo "索引文件创建完成。"
else
	if [ "x${1}" != "x" ]; then
		echo "因指定了索引文件 ${SET_INDEX_STEP_FILE} ，不支持再指定 “${1}” 作为编译筛选目标。"
		exit 1
	fi
	echo -n "指定了索引文件 ${SET_INDEX_STEP_FILE} ..."
	if [ ! -f "${SET_INDEX_STEP_FILE}" ]; then
		echo "不存在!"
		exit 1
	else
		echo ""
	fi
	INDEX_STEP_FILE="${SET_INDEX_STEP_FILE}"
	INDEX_MD5SUM_FILE="custom_$(basename ${INDEX_STEP_FILE}).md5sum"
fi

if [ "x${EXPORT_STEP}" == "x1" ]; then
#	cat ${NEW_TARGET_SYSDIR}/step.index
	cat "${INDEX_STEP_FILE}"
	echo "以上内容已存放在 ${INDEX_STEP_FILE} 文件中。"
	exit 0
fi

if [ "x${1}" != "x" ] && [ "x${FORCE_BUILD}" == "x1" ]; then
	FORCE_ALL_BUILD=1
fi

mkdir -p ${NEW_TARGET_SYSDIR}/status/update
mkdir -p ${NEW_TARGET_SYSDIR}/logs/update
mkdir -p ${NEW_TARGET_SYSDIR}/build
mkdir -p ${NEW_TARGET_SYSDIR}/dist
mkdir -p ${NEW_TARGET_SYSDIR}/temp/temp_overlay
mkdir -p ${NEW_TARGET_SYSDIR}/common_files
mkdir -p ${NEW_TARGET_SYSDIR}/scripts/os_{first,start,final}_run
mkdir -p ${NEW_TARGET_SYSDIR}/scripts/update/os_{first,start,final}_run


mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/{.lowerdir,.workerdir}
mkdir -p ${NEW_TARGET_SYSDIR}/sysroot

mkdir -p ${NEW_TARGET_SYSDIR}/files
mkdir -p ${NEW_TARGET_SYSDIR}/build

mkdir -p ${NEW_BASE_DIR}/downloads/files/step

mkdir -p ${NEW_TARGET_SYSDIR}/cross-tools

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
	CROSSTOOLS_DIR_EXT="_${SET_CROSSTOOLS_DIR}"
else
	CROSSTOOLS_DIR_EXT=""
fi

# if [ -f ${NEW_TARGET_SYSDIR}/status/${INDEX_MD5SUM_FILE} ]; then
# 	if [ "x$(cat ${NEW_TARGET_SYSDIR}/status/${INDEX_MD5SUM_FILE})" != "x0" ]; then
# 		md5sum -c ${NEW_TARGET_SYSDIR}/status/${INDEX_MD5SUM_FILE} 2>/dev/null > /dev/null
# 		if [ "$?" != "0" ] || [ "x${FORCE_ALL_DOWNLOAD}" == "x1" ]; then
# 			if [ "x${FORCE_ALL_DOWNLOAD}" == "x1" ]; then
# 				echo "强制指定进行软件包下载检查，开始进行必要的下载..."
# 			else
# 				echo "本次创建的索引文件与上次的内容不同，可能会存在需要下载的软件包，开始进行必要的下载..."
# 			fi
# 			if [ -f proxy.set ]; then
# #				tools/get_all_package_url.sh -p -i ${NEW_TARGET_SYSDIR}/step.index
# 				tools/get_all_package_url.sh -p -g -i ${INDEX_STEP_FILE}
# 			else
# #				tools/get_all_package_url.sh -i ${NEW_TARGET_SYSDIR}/step.index
# 				tools/get_all_package_url.sh -g -i ${INDEX_STEP_FILE}
# 			fi
# 			echo "下载完成。"
# 		fi
# 	fi
# else
# 	echo "开始下载必要的软件包..."
# 	if [ -f proxy.set ]; then
# #		tools/get_all_package_url.sh -p -i ${NEW_TARGET_SYSDIR}/step.index
# 		tools/get_all_package_url.sh -p -i ${INDEX_STEP_FILE}
# 	else
# #		tools/get_all_package_url.sh -i ${NEW_TARGET_SYSDIR}/step.index
# 		tools/get_all_package_url.sh -i ${INDEX_STEP_FILE}
# 	fi
# 	echo "下载完成。"
# fi
# # md5sum ${NEW_TARGET_SYSDIR}/step.index > ${NEW_TARGET_SYSDIR}/status/step.md5sum
# md5sum ${INDEX_STEP_FILE} > ${NEW_TARGET_SYSDIR}/status/${INDEX_MD5SUM_FILE}

if [ -f ${NEW_TARGET_SYSDIR}/status/${INDEX_MD5SUM_FILE} ]; then
	if [ "x$(cat ${NEW_TARGET_SYSDIR}/status/${INDEX_MD5SUM_FILE})" != "x0" ]; then
		md5sum -c ${NEW_TARGET_SYSDIR}/status/${INDEX_MD5SUM_FILE} 2>/dev/null > /dev/null
		if [ "$?" != "0" ] || [ "x${FORCE_ALL_DOWNLOAD}" == "x1" ]; then
			if [ "x${FORCE_ALL_DOWNLOAD}" == "x1" ]; then
				echo "强制指定进行软件包下载检查，开始进行必要的下载..."
#				if [ -f proxy.set ]; then
					tools/get_all_package_url.sh ${WORLD_PARM} -a ${USE_PROXY_DOWNLOAD} -i ${INDEX_STEP_FILE}
#				else
#					tools/get_all_package_url.sh ${WORLD_PARM} -a -i ${INDEX_STEP_FILE}
#				fi
			else
				echo "本次创建的索引文件与上次的内容不同，可能会存在需要下载的软件包，开始进行必要的下载..."
#				if [ -f proxy.set ]; then
					tools/get_all_package_url.sh ${WORLD_PARM} -a ${USE_PROXY_DOWNLOAD} -g -i ${INDEX_STEP_FILE}
#				else
#					tools/get_all_package_url.sh -a -g -i ${INDEX_STEP_FILE}
#				fi
			fi
			echo "下载完成。"
			cp_file_and_sources
		fi
	fi
else
	if [ "x${FORCE_ALL_DOWNLOAD}" == "x1" ]; then
		echo "强制指定进行软件包下载检查，开始进行必要的下载..."
#		if [ -f proxy.set ]; then
			tools/get_all_package_url.sh ${WORLD_PARM} -a ${USE_PROXY_DOWNLOAD} -i ${INDEX_STEP_FILE}
#		else
#			tools/get_all_package_url.sh -i ${INDEX_STEP_FILE}
#		fi
		echo "下载完成。"
	else
		echo "开始下载必要的软件包..."
#		if [ -f proxy.set ]; then
			tools/get_all_package_url.sh ${WORLD_PARM} -a ${USE_PROXY_DOWNLOAD} -g -i ${INDEX_STEP_FILE}
#		else
#			tools/get_all_package_url.sh -g -i ${INDEX_STEP_FILE}
#		fi
		echo "下载完成。"
	fi
	cp_file_and_sources
fi
md5sum ${INDEX_STEP_FILE} > ${NEW_TARGET_SYSDIR}/status/${INDEX_MD5SUM_FILE}


# mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/{.lowerdir,.workerdir}
# mkdir -p ${NEW_TARGET_SYSDIR}/sysroot


# mkdir -p ${NEW_TARGET_SYSDIR}/files
# mkdir -p ${NEW_TARGET_SYSDIR}/build
# # cp -a ${BASE_DIR}/files/step/* ${NEW_TARGET_SYSDIR}/files/
# # cp -a ${BASE_DIR}/sources/downloads ${NEW_TARGET_SYSDIR}/

# if [ "x${FORCE_ALL_DOWNLOAD}" == "x1" ]; then
# 	if [ -f ${BASE_DIR}/downloads/sources/files.list ]; then
# 		mkdir -p ${NEW_TARGET_SYSDIR}/downloads/files/
# 		echo -n "复制所需的源码包文件..."
# 		for cp_file in $(cat ${BASE_DIR}/downloads/sources/files.list | sort | uniq)
# 		do
# 			cp ${BASE_DIR}/downloads/sources/files/${cp_file} ${NEW_TARGET_SYSDIR}/downloads/files/
# 		done
# 		echo "完成。"
# 	fi
# 	if [ -f ${BASE_DIR}/downloads/sources/resources.list ]; then
# 		mkdir -p ${NEW_TARGET_SYSDIR}/files/
# 		echo -n "复制所需的资源文件..."
# 		cp -a ${BASE_DIR}/files/step/* ${NEW_TARGET_SYSDIR}/files/
# 		pushd ${BASE_DIR}/downloads/files/step > /dev/null
# 			for cp_file in $(cat ${BASE_DIR}/downloads/sources/resources.list | sort | uniq)
# 			do
# 				cp --parents ${cp_file} ${NEW_TARGET_SYSDIR}/files/
# 			done
# 		popd > /dev/null
# 		echo "完成。"
# 	fi
# 
# # 	if [ -f ${BASE_DIR}/downloads/sources/patches.list ]; then
# #		mkdir -p ${NEW_TARGET_SYSDIR}/files/
# #		echo -n "复制补丁文件..."
# #		pushd ${BASE_DIR}/files/step > /dev/null
# #			for cp_file in $(cat ${BASE_DIR}/downloads/sources/patches.list | sort | uniq)
# #			do
# #				cp --parents ${cp_file} ${NEW_TARGET_SYSDIR}/files/
# #			done
# #		popd > /dev/null
# #		echo "完成。"
# #	fi
# 
# fi


while mount | grep "overlay on ${NEW_TARGET_SYSDIR}/sysroot type " > /dev/null
do
	echo "卸载已挂载的目录 ${NEW_TARGET_SYSDIR}/sysroot ..."
	overlay_umount
done

echo "开始编译制作过程......"
echo "------------$(date)-------------" >> ${NEW_TARGET_SYSDIR}/logs/build_log

# STEP_FILE="${NEW_TARGET_SYSDIR}/step.index"
STEP_FILE="${INDEX_STEP_FILE}"

if [ "x${SINGLE_PACKAGE}" != "x1" ]; then
	if [ "x${USE_PREV_INDEX_FILE}" != "x1" ]; then
		cp ${INDEX_STEP_FILE} ${NEW_TARGET_SYSDIR}/step.index.temp
	fi
	STEP_FILE="${NEW_TARGET_SYSDIR}/step.index.temp"
fi

echo -n "" > ${NEW_TARGET_SYSDIR}/logs/step_begin_run_save
echo -n "" > ${NEW_TARGET_SYSDIR}/logs/step_final_run_save
echo -n "" > ${NEW_TARGET_SYSDIR}/logs/step_overlay_before_run_save
echo -n "" > ${NEW_TARGET_SYSDIR}/logs/step_overlay_after_run_save
echo -n "" > ${NEW_TARGET_SYSDIR}/logs/step_overlay_temp_fix_run_save


if [ -f ${NEW_TARGET_SYSDIR}/logs/info_pool ]; then
	mv ${NEW_TARGET_SYSDIR}/logs/info_pool{,.$(date +%Y%m%d%H%M%S)}
fi
touch ${NEW_TARGET_SYSDIR}/logs/info_pool

# cat ${STEP_FILE} | awk -F'|' '{ print $1 }' | while read line
cat ${STEP_FILE} | grep -v "^#" | while read line_all
do
	SET_PARENT_DIR="${USER_SET_PARENT_DIR}"
	if [ "x${AUTO_SET_OVERLAY_DIR}" == "x1" ]; then
		SET_OVERLAY_DIR=""
		AUTO_SET_OVERLAY_DIR=0
	fi
	export OPT_SET_OVERLAY_DIR=""

	line=$(echo "${line_all}" | awk -F'|' '{ print $1 }')
	PACKAGE_ALL_OPT="$(echo "${line_all}" | awk -F'|' '{ print $2 }')"
	RET_VAL=0
	PACKAGE_INDEX=$(echo "${line}" | sed "s@ *step@@g" | awk -F'/' '{ print $1 }')
	STEP_STAGE=$(echo "${line}" | sed "s@ *step@@g" | awk -F'/' '{ print $2 }')
	PACKAGE_NAME=$(echo "${line}" | sed "s@ *step@@g" | awk -F'/' '{ print $3 }')
	PACKAGE_VERSION=$(get_package_version "${STEP_STAGE}" "${PACKAGE_NAME}")
	PACKAGE_GIT_COMMIT=""

	if [ "x${SINGLE_PACKAGE}" == "x1" ] && [ "x${PACKAGE_NAME}" == "xfinal_run" ]; then
		continue;
	fi

	if [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.parmfilter ]; then
# 		test_filter_form_opt "${PACKAGE_ALL_OPT}" "${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.parmfilter"
		if [ "x$(test_filter_form_opt "${PACKAGE_ALL_OPT}" "${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.parmfilter" )" != "x0" ]; then
			if [ "x$(get_all_set_env_expr "${PACKAGE_ALL_OPT}")" == "x" ]; then
				echo -e "\r\e[33m发现 ${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包当前设置不符合制作条件。\e[0m"
			else
				echo -e "\r\e[33m发现 ${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包因 "$(get_all_set_env_expr "${PACKAGE_ALL_OPT}")" 设置而不符合制作条件。跳过！\e[0m"
			fi
			continue;
		fi
	fi

#	echo "OPT_SET_OVERLAY_DIR: ${OPT_SET_OVERLAY_DIR}"
#	echo "PACKAGE_ALL_OPT: ${PACKAGE_ALL_OPT}"
	export OPT_SET_OVERLAY_DIR="$(set_overlay_dir_form_opt "${PACKAGE_ALL_OPT}")"
#	echo "OPT_SET_OVERLAY_DIR: ${OPT_SET_OVERLAY_DIR}"

	if [ -f ${SOURCES_DIR}/url/${STEP_STAGE}/${PACKAGE_NAME} ]; then
		PKG_FILENAME=$(cat ${SOURCES_DIR}/url/${STEP_STAGE}/${PACKAGE_NAME} | awk -F'|' '{ print $3 }' | sed "s@\.tar\.gz\$@@g")
		if [ -f ${NEW_BASE_DIR}/downloads/sources/files/${PKG_FILENAME}.commit ]; then
			PACKAGE_GIT_COMMIT="$(cat ${NEW_BASE_DIR}/downloads/sources/files/${PKG_FILENAME}.commit)"
		else
			PACKAGE_GIT_COMMIT=""
		fi
	fi

	if [ "x${PACKAGE_VERSION}" == "xgit" ] || [ "x${PACKAGE_VERSION}" == "xgit-default" ]; then
		PACKAGE_VERSION="git$([[ "${PACKAGE_GIT_COMMIT}" == "" ]] && echo "" || echo "_$(echo ${PACKAGE_GIT_COMMIT} | sed "s@COMMIT=@@g" | cut -c1-8)")"
	fi

	OPT_SET_PARENT_DIR="$(set_parent_dir_form_opt "${PACKAGE_ALL_OPT}")"
	PACKAGE_SET_ENV=$(get_all_can_set_env_str "${PACKAGE_ALL_OPT}")
	PACKAGE_SET_STATUS_FILE=$(get_can_set_status_file "${PACKAGE_ALL_OPT}")
#	get_unset_env_for_package

	OPT_SET_VERSION_INDEX="$(set_version_index_form_opt "${PACKAGE_ALL_OPT}")"

# 	if [ "x${OPT_SET_PARENT_DIR}" != "x" ]; then
# 		echo -n "${PACKAGE_NAME} 设置了临时上级目录: ${OPT_SET_PARENT_DIR} 。"
# 	fi

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


#	echo ""
#	echo "OVERLAY_DIR: ${OVERLAY_DIR}"
#	echo "SET_OVERLAY_DIR: ${SET_OVERLAY_DIR}"
	export SET_OVERLAY_DIR=${SET_OVERLAY_DIR}
#	echo "AUTO_SET_OVERLAY_DIR: ${AUTO_SET_OVERLAY_DIR}"

	STATUS_FILE="${PACKAGE_NAME}${PACKAGE_SET_ENV}_${STEP_STAGE}${CROSSTOOLS_DIR_EXT}_${PACKAGE_INDEX}"
	if [ "x${SET_OVERLAY_DIR}" != "x" ] && [ "x${AUTO_SET_OVERLAY_DIR}" == "x0" ]; then
		STATUS_FILE="${PACKAGE_NAME}${PACKAGE_SET_ENV}_${STEP_STAGE}_${SET_OVERLAY_DIR}${CROSSTOOLS_DIR_EXT}_${PACKAGE_INDEX}"
	else
#		if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
#			STATUS_FILE="${PACKAGE_NAME}${PACKAGE_SET_ENV}_${STEP_STAGE}_${SET_OVERLAY_DIR}_${PACKAGE_INDEX}"
#		fi
		if [ "x${SET_OVERLAY_DIR}" != "x" ] && [ "x${AUTO_SET_OVERLAY_DIR}" != "x1" ]; then
			STATUS_FILE="${PACKAGE_NAME}${PACKAGE_SET_ENV}_${STEP_STAGE}_${SET_OVERLAY_DIR}${CROSSTOOLS_DIR_EXT}_${PACKAGE_INDEX}"
		fi
	fi

	if [ "x${OPT_SET_VERSION_INDEX}" == "x" ]; then
		SCRIPT_FILE=$(echo "${line}" | awk -F' ' '{ print $2 }' | sed "s@ *step\/@@g")
	else
		SCRIPT_FILE=$(echo "${line}" | awk -F' ' '{ print $2 }' | sed "s@ *step\/@@g").${OPT_SET_VERSION_INDEX}
	fi

	TEST_WATCH_PACKAGE=0
	if [ "x${PACKAGE_NAME}" == "xbegin_run" ] || [ "x${PACKAGE_NAME}" == "xoverlay_before_run" ] || [ "x${PACKAGE_NAME}" == "xoverlay_after_run" ] || [ "x${PACKAGE_NAME}" == "xoverlay_temp_fix_run" ]; then
		echo "${STEP_STAGE}" >> ${NEW_TARGET_SYSDIR}/logs/step_${PACKAGE_NAME}_save
		continue;
	else
		if [ ! -d ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/ ]; then
			mkdir -p ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}
		fi
		if ([ -f ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/${STATUS_FILE} ] || [ -f ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/${STATUS_FILE} ]) && [ "x${SINGLE_PACKAGE}" == "x0" ] ; then
			SHOW_PACKAGE_OPT="$(get_all_set_env_expr "${PACKAGE_ALL_OPT}")"
#			echo "test ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/${STATUS_FILE}"
#			echo "${PACKAGE_GIT_COMMIT}tools/show_package_script.sh ${WORLD_PARM} -n ${SCRIPT_FILE}"
			echo "${PACKAGE_GIT_COMMIT}$(tools/show_package_script.sh ${WORLD_PARM} -n ${SCRIPT_FILE})" | md5sum -c ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/${STATUS_FILE} 2>/dev/null > /dev/null
			if [ "$?" == "0" ] && ([ "x${FORCE_BUILD}" == "x0" ] || [ "x${FORCE_ALL_BUILD}" == "x0" ]); then
				TEST_WATCH_PACKAGE=$(test_watch_step "${STEP_STAGE}" "${PACKAGE_NAME}" "${STATUS_FILE}")
#  				test_watch_step "${STEP_STAGE}" "${PACKAGE_NAME}" "${STATUS_FILE}"
#  				echo "aaaaaaaaaaaaaaaa ${TEST_WATCH_PACKAGE} aaaaaaaaaaaaaaaaa"
# 				TEST_WATCH_PACKAGE=0
				if [ "x${TEST_WATCH_PACKAGE}" == "x0" ]; then
					if [ "x${SHOW_PACKAGE_OPT}" == "x" ]; then
						echo -n -e "\r${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包已完成制作。\033[0K"
					else
						echo -n -e "\r${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包 ${SHOW_PACKAGE_OPT} 已完成制作。\033[0K"
					fi
					create_os_run "${SCRIPT_FILE}" "${STEP_STAGE}" "${PACKAGE_NAME}" "${PACKAGE_INDEX}"
					continue;
				else
					echo -e "\r\e[033m${STEP_STAGE} 组中的 ${PACKAGE_NAME} 因相关步骤的重构而要重新执行。\e[0m\033[0K"
				fi
			else
				if [ ! -d ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/ ]; then
					mkdir -p ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}
				fi
				if [ -f ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/${STATUS_FILE} ] && [ "x${SINGLE_PACKAGE}" == "x0" ] ; then
#					echo "检查update目录中的${STATUS_FILE}状态文件。"
					echo "${PACKAGE_GIT_COMMIT}$(tools/show_package_script.sh ${WORLD_PARM} -n ${SCRIPT_FILE})" | md5sum -c ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/${STATUS_FILE} 2>/dev/null > /dev/null
					if [ "$?" == "0" ] && ([ "x${FORCE_BUILD}" == "x0" ] || [ "x${FORCE_ALL_BUILD}" == "x0" ]); then
						TEST_WATCH_PACKAGE=$(test_watch_step "${STEP_STAGE}" "${PACKAGE_NAME}" "${STATUS_FILE}")
						if [ "x${TEST_WATCH_PACKAGE}" == "x0" ]; then
							if [ "x${SHOW_PACKAGE_OPT}" == "x" ]; then
								echo -n -e "\r${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包已完成制作。\033[0K"
							else
								echo -n -e "\r${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包 ${SHOW_PACKAGE_OPT} 已完成制作。\033[0K"
							fi
							create_os_run "${SCRIPT_FILE}" "${STEP_STAGE}" "${PACKAGE_NAME}" "${PACKAGE_INDEX}"
							continue;
						else
							echo -e "\r${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包因相关步骤的重构而要重新执行。\033[0K"
						fi
					else
						echo -e "\r${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包制作步骤文件内容发生变化，需要重新执行。\033[0K"
					fi
				else
					echo -e "\r${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包制作步骤文件内容发生变化，需要重新执行。\033[0K"
				fi
			fi
		fi
	fi

	if [ "x${PACKAGE_NAME}" != "xfinal_run" ]; then
		if [ "x${FORCE_ALL_DOWNLOAD}" == "x0" ]; then
			if [ "x${OPT_SET_VERSION_INDEX}" == "x" ]; then
				start_download_source "${STEP_STAGE}/${PACKAGE_NAME}"
			else
				start_download_source_for_version_index "${STEP_STAGE}/${PACKAGE_NAME}" "${OPT_SET_VERSION_INDEX}"
			fi
		fi
		SHOW_PACKAGE_OPT="$(get_all_set_env_expr "${PACKAGE_ALL_OPT}")"
		if [ "x${SHOW_PACKAGE_OPT}" == "x" ]; then
			echo -e "\r开始执行 ${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包的制作步骤...\033[0K"
		else
			echo -e "\r开始执行 ${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包 ${SHOW_PACKAGE_OPT} 的制作步骤...\033[0K"
		fi
		if [ "x${OPT_SET_VERSION_INDEX}" != "x" ]; then
			echo "本次步骤构建额外版本 ${OPT_SET_VERSION_INDEX} ..."
		fi

		if [ "x${OPT_SET_PARENT_DIR}" != "x" ]; then
			if [ "x${SET_PARENT_DIR}" != "x" ]; then
				echo "虽然 ${PACKAGE_NAME} 设有临时上级目录: ${OPT_SET_PARENT_DIR} ，但用户指定了上级目录，本次将采用用户指定的目录 ${SET_PARENT_DIR} 。"
			else
				echo "${PACKAGE_NAME} 设置了临时上级目录: ${OPT_SET_PARENT_DIR} 。"
			fi
		fi
	else
		echo -e "\r准备执行 ${STEP_STAGE} 组中的完成脚本...\033[0K"
	fi
	tools/show_package_script.sh ${WORLD_PARM} ${SCRIPT_FILE} >/dev/null
	RET_VAL=$?
	if [ "${RET_VAL}" != "0" ]; then
		echo "${SCRIPT_FILE}脚本运行错误！"
		exit ${RET_VAL}
	fi
	RET_VAL=0

	grep "^${STEP_STAGE}$" ${NEW_TARGET_SYSDIR}/logs/step_begin_run_save > /dev/null
	if [ "x$?" == "x0" ]; then
		echo -n "运行 ${STEP_STAGE} 初始化脚本..."
		tools/run_package_script.sh ${WORLD_PARM} ${STEP_STAGE}/begin_run >${NEW_TARGET_SYSDIR}/logs/begin_run_${STEP_STAGE}.log 2>&1
		if [ "x$?" != "x0" ]; then
			echo -e "\e[031m错误！\e[0m"
			tools/show_package_script.sh ${WORLD_PARM} ${STEP_STAGE}/begin_run
			echo "${STEP_STAGE} 初始化脚本运行错误!"
			echo "错误日志请查看 ${NEW_TARGET_SYSDIR}/logs/begin_run_${STEP_STAGE}.log 文件。"
			exit 1
		fi
		sed -i "/^${STEP_STAGE}$/d" ${NEW_TARGET_SYSDIR}/logs/step_begin_run_save
		echo "完成。"
	fi

	declare STEP_OVERLAY_TEMP_FIX=0
	if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ] || [ "x${OPT_SET_PARENT_DIR}" != "x" ]; then
		if [ "x${PACKAGE_NAME}" != "xfinal_run" ]; then
			if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ]; then
				STEP_OVERLAY_TEMP_FIX="$(cat ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set | grep "temp_fix=" | tail -n1 | awk -F'=' '{ print $2 }')"
			else
				STEP_OVERLAY_TEMP_FIX=0
			fi
			overlay_mount ${STEP_STAGE} ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set "${STEP_OVERLAY_TEMP_FIX}"
		else
			overlay_mount ${STEP_STAGE} ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set "2"
		fi
	fi
	
	if [ "x${PACKAGE_NAME}" != "xfinal_run" ]; then
		if [ "x${PACKAGE_VERSION}" != "xNULL" ]; then
			echo -n "制作 ${STEP_STAGE} 组中的 ${PACKAGE_NAME} - ${PACKAGE_VERSION} 软件包..."
		else
			echo -n "制作 ${STEP_STAGE} 组中的 ${PACKAGE_NAME} 软件包..."
		fi
	else
		echo -n "执行 ${STEP_STAGE} 组中的完成脚本..."
	fi

	STATUS_LOG_FILE="${STATUS_FILE}"
	if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ]; then
                if [ "x${ORIG_OVERLAY_DIR}" != "x" ]; then
			if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${ORIG_OVERLAY_DIR}.released ]; then
				STATUS_LOG_FILE="update/${STATUS_LOG_FILE}"
			fi
		fi
	fi
	if [ "x${SINGLE_PACKAGE}" == "x1" ]; then
		STATUS_LOG_FILE="${STATUS_LOG_FILE}.single_build"
	fi
	ln -sf ${STATUS_LOG_FILE}.log ${NEW_TARGET_SYSDIR}/logs/current.log
	os_run_clean "${STEP_STAGE}" "${PACKAGE_NAME}"
	tools/run_package_script.sh ${WORLD_PARM} ${SCRIPT_FILE} >${NEW_TARGET_SYSDIR}/logs/${STATUS_LOG_FILE}.log 2>&1
	if [ "x$?" != "x0" ]; then
		echo  -e "\e[31m错误！\e[0m"

		case "x${BUILD_ERROR_LIMITE}" in
			x0)
				echo "* ${STEP_STAGE}/${PACKAGE_NAME} $([[ "${REBUILD_ENV}" == "" ]] && echo "" || echo " -e ${REBUILD_ENV}")$([[ "${SET_CROSSTOOLS_DIR}" == "" ]] && echo "" || echo " 指定交叉工具链目录: ${SET_CROSSTOOLS_DIR}")$([[ "${OPT_SET_PARENT_DIR}" == "" ]] && echo "" || echo " 指定上级挂载目录: ${OPT_SET_PARENT_DIR}")$([[ "${SET_OVERLAY_DIR}" == "" ]] && echo "$([[ "${OPT_SET_OVERLAY_DIR}" == "" ]] && echo "" || echo " 指定安装目录: ${OPT_SET_OVERLAY_DIR}")" || echo " 指定安装目录: ${SET_OVERLAY_DIR}")" >> ${NEW_TARGET_SYSDIR}/logs/build_error.log
				echo "    错误日志请查看 ${NEW_TARGET_SYSDIR}/logs/${STATUS_LOG_FILE}.log 文件。"  >> ${NEW_TARGET_SYSDIR}/logs/build_error.log
				echo "    进入构建环境进行调试使用命令： tools/enter_package_env.sh ${WORLD_PARM}$([[ "${REBUILD_ENV}" == "" ]] && echo "" || echo " -e ${REBUILD_ENV}")$([[ "${SET_CROSSTOOLS_DIR}" == "" ]] && echo "" || echo " -C ${SET_CROSSTOOLS_DIR}")$([[ "${SET_PARENT_DIR}" == "" ]] && echo "$([[ "${OPT_SET_PARENT_DIR}" == "" ]] && echo "" || echo " -O ${OPT_SET_PARENT_DIR}")" || echo " -O ${SET_PARENT_DIR}")$([[ "${SET_OVERLAY_DIR}" == "" ]] && echo "$([[ "${OPT_SET_OVERLAY_DIR}" == "" ]] && echo "" || echo " -S ${OPT_SET_OVERLAY_DIR}")" || echo " -S ${SET_OVERLAY_DIR}") ${STEP_STAGE}/${PACKAGE_NAME} "  >> ${NEW_TARGET_SYSDIR}/logs/build_error.log
				if [ "${SET_OVERLAY_DIR}" != "" ] || [ "${OPT_SET_OVERLAY_DIR}" != "" ] || [ "${ORIG_OVERLAY_DIR}" != "" ]; then
					overlay_umount
				fi
				continue
				;;
			x1)
				tools/show_package_script.sh ${WORLD_PARM} ${SCRIPT_FILE}
				echo -e "${SCRIPT_FILE}  $([[ "${REBUILD_ENV}" == "" ]] && echo "" || echo " -e ${REBUILD_ENV}")$([[ "${SET_CROSSTOOLS_DIR}" == "" ]] && echo "" || echo " 指定交叉工具链目录: ${SET_CROSSTOOLS_DIR}")$([[ "${OPT_SET_PARENT_DIR}" == "" ]] && echo "" || echo " 指定上级挂载目录: ${OPT_SET_PARENT_DIR}")$([[ "${SET_OVERLAY_DIR}" == "" ]] && echo "$([[ "${OPT_SET_OVERLAY_DIR}" == "" ]] && echo "" || echo " 指定安装目录: ${OPT_SET_OVERLAY_DIR}")" || echo " 指定安装目录: ${SET_OVERLAY_DIR}") \e[31m制作错误!\e[0m"
				echo -e "错误日志请查看 \e[31m ${NEW_TARGET_SYSDIR}/logs/${STATUS_LOG_FILE}.log \e[0m 文件。"
				REBUILD_ENV=$(format_package_env_to_string)
				echo -e "进入构建环境进行调试使用命令： \e[32m tools/enter_package_env.sh ${WORLD_PARM}$([[ "${REBUILD_ENV}" == "" ]] && echo "" || echo " -e ${REBUILD_ENV}")$([[ "${SET_CROSSTOOLS_DIR}" == "" ]] && echo "" || echo " -C ${SET_CROSSTOOLS_DIR}")$([[ "${SET_PARENT_DIR}" == "" ]] && echo "$([[ "${OPT_SET_PARENT_DIR}" == "" ]] && echo "" || echo " -O ${OPT_SET_PARENT_DIR}")" || echo " -O ${SET_PARENT_DIR}")$([[ "${SET_OVERLAY_DIR}" == "" ]] && echo "$([[ "${OPT_SET_OVERLAY_DIR}" == "" ]] && echo "" || echo " -S ${OPT_SET_OVERLAY_DIR}")" || echo " -S ${SET_OVERLAY_DIR}") ${STEP_STAGE}/${PACKAGE_NAME} \e[0m"
				exit 1
				;;
			*)
				((BUILD_ERROR_COUNT--))
				echo "* ${STEP_STAGE}/${PACKAGE_NAME} $([[ "${REBUILD_ENV}" == "" ]] && echo "" || echo " -e ${REBUILD_ENV}")$([[ "${SET_CROSSTOOLS_DIR}" == "" ]] && echo "" || echo " 指定交叉工具链目录: ${SET_CROSSTOOLS_DIR}")$([[ "${OPT_SET_PARENT_DIR}" == "" ]] && echo "" || echo " 指定上级挂载目录: ${OPT_SET_PARENT_DIR}")$([[ "${SET_OVERLAY_DIR}" == "" ]] && echo "$([[ "${OPT_SET_OVERLAY_DIR}" == "" ]] && echo "" || echo " 指定安装目录: ${OPT_SET_OVERLAY_DIR}")" || echo " 指定安装目录: ${SET_OVERLAY_DIR}")" >> ${NEW_TARGET_SYSDIR}/logs/build_error.log
				echo "    错误日志请查看 ${NEW_TARGET_SYSDIR}/logs/${STATUS_LOG_FILE}.log 文件。"  >> ${NEW_TARGET_SYSDIR}/logs/build_error.log
				echo "    进入构建环境进行调试使用命令： tools/enter_package_env.sh ${WORLD_PARM}$([[ "${REBUILD_ENV}" == "" ]] && echo "" || echo " -e ${REBUILD_ENV}")$([[ "${SET_CROSSTOOLS_DIR}" == "" ]] && echo "" || echo " -C ${SET_CROSSTOOLS_DIR}")$([[ "${SET_PARENT_DIR}" == "" ]] && echo "$([[ "${OPT_SET_PARENT_DIR}" == "" ]] && echo "" || echo " -O ${OPT_SET_PARENT_DIR}")" || echo " -O ${SET_PARENT_DIR}")$([[ "${SET_OVERLAY_DIR}" == "" ]] && echo "$([[ "${OPT_SET_OVERLAY_DIR}" == "" ]] && echo "" || echo " -S ${OPT_SET_OVERLAY_DIR}")" || echo " -S ${SET_OVERLAY_DIR}") ${STEP_STAGE}/${PACKAGE_NAME} " >> ${NEW_TARGET_SYSDIR}/logs/build_error.log
				if [ "x${BUILD_ERROR_COUNT}" == "x0" ]; then
					echo -e "\e[31m错误数量达到限制，构建过程停止。\e[0m"
					echo -e "\e[31m本次编译存在以下错误步骤，请检查。\e[0m"

					if [ -f ${NEW_TARGET_SYSDIR}/logs/build_error.log ]; then
						if (( $(wc -l workbase/logs/build_error.log |awk -F' ' '{ print $1 }') >= 15 )); then
							head -n15 ${NEW_TARGET_SYSDIR}/logs/build_error.log
							echo -e "\e[031m......\e[0m"
							echo -e "\e[031m错误数据太多，不再继续显示\e[0m，可打开 \e[031m ${NEW_TARGET_SYSDIR}/logs/build_error.log \e[0m 文件查看更多信息。"
						else
							cat ${NEW_TARGET_SYSDIR}/logs/build_error.log
						fi
					fi
					exit 1
				fi
				overlay_umount
				continue
				;;
		esac
	fi

	if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ]; then
		overlay_umount
		if [ "x${SINGLE_PACKAGE}" != "x1" ]; then
			if ([ "x${STEP_OVERLAY_TEMP_FIX}" == "x1" ] && [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}/overlay_temp_fix_run ]) || [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.tempfix ]; then
#			if [ "x${STEP_OVERLAY_TEMP_FIX}" == "x1" ] && [ -f ${SCRIPTS_DIR}/step/${STEP_STAGE}/overlay_temp_fix_run ]; then
				if [ "x${SET_OVERLAY_DIR}" == "x" ]; then
					cp -af ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${STEP_STAGE}/${PACKAGE_NAME}/* ${NEW_TARGET_SYSDIR}/overlaydir/$(get_overlay_dirname ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set)/
				else
					cp -af ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${STEP_STAGE}/${PACKAGE_NAME}/* ${NEW_TARGET_SYSDIR}/overlaydir/${SET_OVERLAY_DIR}/
				fi
				if [ "x$?" != "x0" ]; then
					echo "错误：以临时修改覆盖方式编译的软件包在复制文件时出现错误，请检查 ${NEW_TARGET_SYSDIR}/temp/temp_overlay/${STEP_STAGE}/${PACKAGE_NAME}/ 目录中是否没有产生任何文件。"
					exit -2
				fi
			fi
		fi
	fi

	if [ "x${PACKAGE_NAME}" != "xfinal_run" ] && [ "x${PACKAGE_SET_STATUS_FILE}" == "x1" ] && [ "x${SINGLE_PACKAGE}" == "x0" ]; then
		if [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ]; then
	                SAVEFILE_OVERLAY_NAME=$(get_overlay_dirname ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set)
			if [ ! -f ${NEW_TARGET_SYSDIR}/overlaydir/${SAVEFILE_OVERLAY_NAME}.released ]; then
				echo "${PACKAGE_GIT_COMMIT}$(tools/show_package_script.sh ${WORLD_PARM} -n ${SCRIPT_FILE})" | md5sum > ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/${STATUS_FILE}
#				if [ ! -d ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/ ]; then
#					mkdir -p ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}
#				fi
#				cp -f ${NEW_TARGET_SYSDIR}/status/${STATUS_FILE} ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/
			else
				mkdir -p ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/
				echo "${PACKAGE_GIT_COMMIT}$(tools/show_package_script.sh ${WORLD_PARM} -n ${SCRIPT_FILE})" | md5sum > ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/${STATUS_FILE}
#				if [ ! -d ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/ ]; then
#					mkdir -p ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}
#				fi
#				cp -f ${NEW_TARGET_SYSDIR}/status/update/${STATUS_FILE} ${NEW_TARGET_SYSDIR}/status/update/${STEP_STAGE}/
			fi
		else
			echo "${PACKAGE_GIT_COMMIT}$(tools/show_package_script.sh ${WORLD_PARM} -n ${SCRIPT_FILE})" | md5sum > ${NEW_TARGET_SYSDIR}/status/${STEP_STAGE}/${STATUS_FILE}
		fi

		if [ "x${TEST_WATCH_PACKAGE}" == "x0" ]; then
			# 默认运行或强制运行，创建 WATCH_ID 。
# 			echo -n "强制执行 $(date +%s)"
			WATCH_ID=$(save_watch_step "${STEP_STAGE}" "${PACKAGE_NAME}" "${STATUS_FILE}")
# 			echo "${WATCH_ID}"
# 			echo "update_notice_package \"${STEP_STAGE}\" \"${PACKAGE_NAME}\" \"${STATUS_FILE}\" \"${WATCH_ID}\""
			update_notice_package "${STEP_STAGE}" "${PACKAGE_NAME}" "${STATUS_FILE}" "${WATCH_ID}"
		else
			# 关注连带运行，传递 WATCH_ID , TEST_WATCH_PACKAGE 值为传递的 WATCH_ID 。
			update_watch_id "${STEP_STAGE}" "${PACKAGE_NAME}" "${STATUS_FILE}" "${TEST_WATCH_PACKAGE}"
			update_notice_package "${STEP_STAGE}" "${PACKAGE_NAME}" "${STATUS_FILE}" "${TEST_WATCH_PACKAGE}"
		fi
	fi

	echo -e "\e[032m完成！\e[0m"

	if [ "x${PACKAGE_NAME}" != "xfinal_run" ] && [ "x${SINGLE_PACKAGE}" == "x1" ] && ( [ "x${SINGLE_PACKAGE_TAR}" != "xnone" ] && [ "x${SINGLE_PACKAGE_TAR}" != "" ] ) ; then
# 		packagedir_to_pack "${NEW_TARGET_SYSDIR}/packages/${STEP_STAGE}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}" "DEST.${DATA_SUFF}" "${ORIG_OVERLAY_DIR}" "${PACKAGE_NAME}" "${PACKAGE_VERSION}" "$([[ "${PACKAGE_SET_ENV}" == "" ]] && echo "${ARCH_NAME}" || echo "${PACKAGE_SET_ENV}")"
		packagedir_to_pack "${NEW_TARGET_SYSDIR}/packages/${STEP_STAGE}/${PACKAGE_NAME}${PACKAGE_SET_ENV}/${PACKAGE_VERSION}" "DEST.${DATA_SUFF}" "${ORIG_OVERLAY_DIR}" "${PACKAGE_NAME}" "${PACKAGE_VERSION}" "$([[ "${PACKAGE_SET_ENV}" == "" ]] && echo "${ARCH_NAME}" || echo "${PACKAGE_SET_ENV}" | sed "s@^_@@g")"
	fi

	create_os_run "${SCRIPT_FILE}" "${STEP_STAGE}" "${PACKAGE_NAME}" "${PACKAGE_INDEX}"

	if [ "x${STEP_STAGE}" == "xhost-tools" ] || [ "x${STEP_STAGE}" == "xcross-tools" ]; then
		if [ "x${PACKAGE_NAME}" != "xfinal_run" ] && [ "x${PACKAGE_SET_STATUS_FILE}" == "x1" ] && [ "x${SINGLE_PACKAGE}" == "x0" ]; then
			if [ -d ${NEW_TARGET_SYSDIR}/${STEP_STAGE} ]; then
				mkdir -p ${NEW_TARGET_SYSDIR}/${STEP_STAGE}/Yongbao/status/
				PACKAGE_INFO=$(cat ${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.info)
				if [ "x${PACKAGE_INFO}" != "x" ]; then
					PACKAGE_INFO_VERSION="$(echo ${PACKAGE_INFO} | awk -F'|' '{ print $2 }' | sed "s@-default\$@@g")"
					PACKAGE_INFO_NAME="$(echo ${PACKAGE_INFO} | awk -F'|' '{ print $3 }')"
					if [ "x${OPT_SET_VERSION_INDEX}" != "x" ]; then
						PACKAGE_INFO_NAME="${PACKAGE_INFO_NAME}.${OPT_SET_VERSION_INDEX}"
					fi
					if [ "x${PACKAGE_INFO_NAME}" != "x" ] && [ "x${PACKAGE_INFO_NAME}" != "xNULL" ]; then
						if [ "x${PACKAGE_GIT_COMMIT}" == "x" ]; then
							echo "${PACKAGE_INFO_VERSION}" > ${NEW_TARGET_SYSDIR}/${STEP_STAGE}/Yongbao/status/${PACKAGE_INFO_NAME}
						else
							if [ -f ${NEW_TARGET_SYSDIR}/common_files/${PACKAGE_INFO_NAME}.version ]; then
								cat ${NEW_TARGET_SYSDIR}/common_files/${PACKAGE_INFO_NAME}.version > ${NEW_TARGET_SYSDIR}/${STEP_STAGE}/Yongbao/status/${PACKAGE_INFO_NAME}
							else
								echo "git_$(echo ${PACKAGE_GIT_COMMIT} | awk -F'=' '{ print $2 }' | cut -c 1-12)" > ${NEW_TARGET_SYSDIR}/${STEP_STAGE}/Yongbao/status/${PACKAGE_INFO_NAME}
							fi
						fi
					fi
				fi
			fi
		fi
	elif [ -f ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set ]; then
		SAVEFILE_OVERLAY_NAME=""
		if [ "x${SET_OVERLAY_DIR}" == "x" ]; then
			SAVEFILE_OVERLAY_NAME=$(get_overlay_dirname ${NEW_BASE_DIR}/env/${STEP_STAGE}/overlay.set)
		else
			SAVEFILE_OVERLAY_NAME=${SET_OVERLAY_DIR}
		fi
		if [ "x${SAVEFILE_OVERLAY_NAME}" != "x" ]; then
			if [ "x${PACKAGE_NAME}" != "xfinal_run" ] && [ "x${PACKAGE_SET_STATUS_FILE}" == "x1" ] && [ "x${SINGLE_PACKAGE}" == "x0" ]; then
				if [ -d ${NEW_TARGET_SYSDIR}/overlaydir/${SAVEFILE_OVERLAY_NAME} ]; then
					mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${SAVEFILE_OVERLAY_NAME}/var/Yongbao/status/
					PACKAGE_INFO=$(cat ${SCRIPTS_DIR}/step/${STEP_STAGE}/${PACKAGE_NAME}.info)
					if [ "x${PACKAGE_INFO}" != "x" ]; then
						PACKAGE_INFO_VERSION="$(echo ${PACKAGE_INFO} | awk -F'|' '{ print $2 }' | sed "s@-default\$@@g")"
						PACKAGE_INFO_NAME="$(echo ${PACKAGE_INFO} | awk -F'|' '{ print $3 }')"
						if [ "x${OPT_SET_VERSION_INDEX}" != "x" ]; then
							PACKAGE_INFO_NAME="${PACKAGE_INFO_NAME}.${OPT_SET_VERSION_INDEX}"
						fi
						if [ "x${PACKAGE_INFO_NAME}" != "x" ] && [ "x${PACKAGE_INFO_NAME}" != "xNULL" ]; then
							if [ "x${PACKAGE_GIT_COMMIT}" == "x" ]; then
								echo "${PACKAGE_INFO_VERSION}" > ${NEW_TARGET_SYSDIR}/overlaydir/${SAVEFILE_OVERLAY_NAME}/var/Yongbao/status/${PACKAGE_INFO_NAME}
							else
								if [ -f ${NEW_TARGET_SYSDIR}/common_files/${PACKAGE_INFO_NAME}.version ]; then
									cat ${NEW_TARGET_SYSDIR}/common_files/${PACKAGE_INFO_NAME}.version > ${NEW_TARGET_SYSDIR}/overlaydir/${SAVEFILE_OVERLAY_NAME}/var/Yongbao/status/${PACKAGE_INFO_NAME}
								else
									echo "git_$(echo ${PACKAGE_GIT_COMMIT} | awk -F'=' '{ print $2 }' | cut -c 1-12)" > ${NEW_TARGET_SYSDIR}/overlaydir/${SAVEFILE_OVERLAY_NAME}/var/Yongbao/status/${PACKAGE_INFO_NAME}
								fi
							fi
						fi
					fi
				fi
			fi
		fi
	fi

	echo -n "${STEP_STAGE}/${PACKAGE_NAME} : " >> ${NEW_TARGET_SYSDIR}/logs/build_log
	if [ -f ${SOURCES_DIR}/url/${STEP_STAGE}/${PACKAGE_NAME} ]; then
		PACKAGE_URL=$(cat ${SOURCES_DIR}/url/${STEP_STAGE}/${PACKAGE_NAME})
		if [ "x${PACKAGE_URL}" != "x" ]; then
			echo -n "${PACKAGE_URL}" >> ${NEW_TARGET_SYSDIR}/logs/build_log
                	case "$(echo ${PACKAGE_URL%%/*} | awk -F'|' '{ print $1 }')" in
			GIT)
				if [ -f ${SOURCES_DIR}/url/${STEP_STAGE}/${PACKAGE_NAME}.gitinfo ]; then
					echo -n " $(cat ${SOURCES_DIR}/url/${STEP_STAGE}/${PACKAGE_NAME}.gitinfo) " >> ${NEW_TARGET_SYSDIR}/logs/build_log
				fi
				;;
	                *)
				;;
			esac
			PKG_FILENAME=$(cat ${SOURCES_DIR}/url/${STEP_STAGE}/${PACKAGE_NAME} | awk -F'|' '{ print $3 }' | sed "s@\.tar\.gz\$@@g")
			if [ -f ${NEW_BASE_DIR}/downloads/sources/files/${PKG_FILENAME}.commit ]; then
				echo -n " | $(cat ${NEW_BASE_DIR}/downloads/sources/files/${PKG_FILENAME}.commit) " >> ${NEW_TARGET_SYSDIR}/logs/build_log
			fi
		fi
	fi
	echo "" >> ${NEW_TARGET_SYSDIR}/logs/build_log
	if [ "${STEP_FILE}" == "${NEW_TARGET_SYSDIR}/step.index.temp" ]; then
# 		echo "sed -i \"\\#^${line_all}\$#d\" ${STEP_FILE}"
		sed -i "\\#^${line_all}\$#d" ${STEP_FILE}
	fi
done

if [ "x$?" == "x0" ]; then
	echo -e "\r编译制作过程完成。\033[0K\n"

	if [ -f ${NEW_TARGET_SYSDIR}/logs/build_error.log ]; then
		echo -e "\e[31m本次编译存在以下错误步骤，请检查。\e[0m"
		if (( $(wc -l ${NEW_TARGET_SYSDIR}/logs/build_error.log |awk -F' ' '{ print $1 }') >= 15 )); then
			head -n15 ${NEW_TARGET_SYSDIR}/logs/build_error.log
			echo -e "\e[031m......\e[0m"
			echo -e "\e[031m错误数据太多，不再继续显示\e[0m，可打开 \e[031m ${NEW_TARGET_SYSDIR}/logs/build_error.log \e[0m 文件查看更多信息。"
		else
			cat ${NEW_TARGET_SYSDIR}/logs/build_error.log
		fi
		exit
	fi

	cat ${NEW_TARGET_SYSDIR}/logs/info_pool
	
	if [ "x${1}" == "x" ]; then
		echo "接下来可以使用 ./strip_os.sh $([[ "${SET_OVERLAY_DIR}" == "" ]] && echo "$([[ -d ${NEW_TARGET_SYSDIR}/overlaydir_strip ]] && echo "-f" || echo "")" || echo "-f ${SET_OVERLAY_DIR}") 脚本来清除调试信息，使用 ./install_os_run.sh 安装系统启动脚本，$([[ -f info_set/release_sort ]] && echo "使用 ./release_info.sh 来创建软件包信息汇总 ，" || echo "" )以及使用 ./pack_os.sh $([[ "${SET_OVERLAY_DIR}" == "" ]] && echo "$([[ -d ${NEW_TARGET_SYSDIR}/dist/os/squashfs ]] && echo "-f" || echo "")" || echo "-f ${SET_OVERLAY_DIR}") 脚本来打包系统。"
	fi
else
	exit
fi

if [ "x${SINGLE_PACKAGE}" != "x1" ]; then
	rm -f ${NEW_TARGET_SYSDIR}/step.index.temp
fi
rm -f ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf
rm -f ${NEW_TARGET_SYSDIR}/temp/set_env_${YONGBAO_BUILD_UUID}.conf

echo "编译制作过程完成。" >> ${NEW_TARGET_SYSDIR}/logs/build_log
echo "------------$(date)-------------" >> ${NEW_TARGET_SYSDIR}/logs/build_log

while mount | grep "on ${NEW_TARGET_SYSDIR}/cross-tools type " > /dev/null
do
	echo "卸载已挂载的目录 ${NEW_TARGET_SYSDIR}/cross-tools ..."
	overlay_umount_cross_tools
done


