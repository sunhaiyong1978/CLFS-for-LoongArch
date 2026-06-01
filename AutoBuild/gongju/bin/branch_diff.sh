#!/bin/bash -e

export BASE_DIR="${PWD}"

SCRIPTS_DIR="${BASE_DIR}/scripts"
declare RELEASE_VERSION=""
declare INCREASE_MODE=0
declare SYNC_SOURCE_SET=""
declare SYNC_DIST_SET=""
declare SINGLE_PATCH=0
declare APPLY_PATCH=0
declare DATE_SUFF="$(date +%Y%m%d%H%M%S)"

function main_help
{
            echo "说明：通过对比两个分支生成差异文件。"
            echo "用法: ./`basename $0`"
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
            echo "    -i: 指定该参数成为增加模式，即目标分支环境没有的步骤会进行增加，若不指定该参数则不会增加目标分支环境没有的步骤。"
            echo "    -s: 设置该参数将生成一个包含全部变更的差异文件。"
            echo "    -S 版本: 设置差异分析的源目录，设置的\"版本\"增加Branch_作为目录。"
            echo "    -D 版本: 设置差异分析的目的目录，设置的\"版本\"增加Branch_作为目录。"
            exit 0
}

while getopts 'isS:D:h' OPT; do
    case $OPT in
	i)
	    INCREASE_MODE=1
	    ;;
	s)
	    SINGLE_PATCH=1
	    ;;
# 	a)
# 	    APPLY_PATCH=1
# 	    ;;
	S)
	    SYNC_SOURCE_SET=$OPTARG
	    ;;
	D)
	    SYNC_DIST_SET=$OPTARG
	    ;;
        h|?)
	    main_help
            ;;
    esac
done
shift $(($OPTIND - 1))


BRANCH_SYNC_ABS_SOURCE=${BASE_DIR}/
BRANCH_SYNC_SOURCE=./

BRANCH_SYNC_ABS_DIST=""
BRANCH_SYNC_DIST=""

if [ "x${SYNC_SOURCE_SET}" == "x" ]; then
	BRANCH_SYNC_ABS_SOURCE=${BASE_DIR}/
	BRANCH_SYNC_SOURCE=./
else
	if [ -d ${BASE_DIR}/Branch_${SYNC_SOURCE_SET} ]; then
		BRANCH_SYNC_ABS_SOURCE=${BASE_DIR}/Branch_${SYNC_SOURCE_SET}/
		BRANCH_SYNC_SOURCE=Branch_${SYNC_SOURCE_SET}/
	else
		echo "没有发现 Branch_${SYNC_SOURCE_SET} 目录，无法分析差异，请指定正确的目录。"
		exit 1
	fi
fi

if [ "x${SYNC_DIST_SET}" == "x" ]; then
	if [ -f ${BASE_DIR}/current_branch ]; then
		RELEASE_VERSION="$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
		if [ -d ${BASE_DIR}/Branch_${RELEASE_VERSION} ]; then
			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将使用 ${BRANCH_SYNC_SOURCE} 分支对 Branch_${RELEASE_VERSION} 分支目录分析差异。"
		else
			echo "没有发现 Branch_${RELEASE_VERSION} 目录，无法继续。"
			exit 1
		fi
		BRANCH_SYNC_ABS_DIST=${BASE_DIR}/Branch_${RELEASE_VERSION}/
		BRANCH_SYNC_DIST=Branch_${RELEASE_VERSION}/
	else
		if [ "x${SYNC_SOURCE_SET}" == "x" ]; then
			echo "没有发现 current_branch 文件，无法确定需要进行差异分析的分支名，可通过 -D 参数指定目标分支。"
			exit 1
		else
			BRANCH_SYNC_ABS_DIST=${BASE_DIR}/
			BRANCH_SYNC_DIST=./
		fi
	fi
else
	if [ -d ${BASE_DIR}/Branch_${SYNC_DIST_SET} ]; then
		RELEASE_VERSION="${SYNC_DIST_SET}"
	else
		echo "没有发现 Branch_${SYNC_DIST_SET} 目录，无法进行差异分析，请指定正确的目录。"
		exit 1
	fi
	BRANCH_SYNC_ABS_DIST=${BASE_DIR}/Branch_${RELEASE_VERSION}/
	BRANCH_SYNC_DIST=Branch_${RELEASE_VERSION}/
fi

# if [ "x${1}" == "x" ]; then
# 	echo "说明：将首次运行脚本安装到系统中。"
# 	echo "用法: ./`basename $0`"
# 	echo "选项："
# 	echo "    -h: 显示当前帮助信息。"
# 	echo "    -i: 指定该参数成为增加模式，即目标分支环境没有的步骤会进行增加，若不指定该参数则不会增加目标分支环境没有的步骤。"
# 	echo "    -w: 强制在主线环境中进行安装文件，不指定该参数将使用 current_branch 指定的分支环境中安装文件，若不存在 current_branch 文件则无法继续。"
# 	exit 0
# fi


# BRANCH_SYNC_ABS_SOURCE=${BASE_DIR}/
# BRANCH_SYNC_SOURCE=./

# BRANCH_SYNC_ABS_DIST=${BASE_DIR}/Branch_${RELEASE_VERSION}/
# BRANCH_SYNC_DIST=Branch_${RELEASE_VERSION}/

if [ "x${BRANCH_SYNC_SOURCE}" == "x" ] && [ ! -d ${BRANCH_SYNC_SOURCE} ]; then
	echo "源目录 “${BRANCH_SYNC_SOURCE}” 找不到，无法继续！"
	exit 2
fi

if [ "x${BRANCH_SYNC_DIST}" == "x" ] && [ ! -d ${BRANCH_SYNC_DIST} ]; then
	echo "目标目录 “${BRANCH_SYNC_DIST}” 找不到，无法继续！"
	exit 2
fi

if [ "x${BRANCH_SYNC_SOURCE}" == "x${BRANCH_SYNC_DIST}" ]; then
	echo "源目录和目标目录不能相同！"
	exit 3
fi

echo "分支差异分析：${BRANCH_SYNC_ABS_SOURCE} (${BRANCH_SYNC_SOURCE}) -> ${BRANCH_SYNC_ABS_DIST} (${BRANCH_SYNC_DIST})"

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

# SOURCE_STEP_FILE=${BASE_DIR}/step
SOURCE_STEP_FILE=${BRANCH_SYNC_ABS_SOURCE}./step

if [ "x${1}" != "x" ]; then
	STEP_PKG_STR="${1}"
	FORMAT_STRING=$(format_step_str "${STEP_PKG_STR}")
	# echo "指定了同步步骤：${FORMAT_STRING}"

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
else
	STEPNAME=NULL
	STEP_PKGNAME=NULL
fi

# echo "${STEPNAME}/${STEP_PKGNAME}"
# if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" != "xNULL" ]; then
# 	STEP_PKG_OPT=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/${STEP_PKGNAME}|" | sort | uniq | tail -n1 | awk -F'|' '{ print $2 }')
# 	STOP_STEP_PKGNAME=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/${STEP_PKGNAME}|" | sort | uniq | tail -n1 | awk -F'|' '{ print $1 }')
# 	STOP_STEP_OPT=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/${STEP_PKGNAME}|" | sort | uniq | tail -n1 | awk -F'|' '{ print $2 }')
# 	STOP_STEP_GROUP="${STOP_STEP_PKGNAME}"
# 	STOP_STEP_STR="${STOP_STEP_PKGNAME}"
# fi
# if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" == "xNULL" ]; then
# 	STEP_PKG_OPT=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/" | head -n1 | awk -F'|' '{ print $2 }')
# 	STOP_STEP_PKGNAME=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/" | tail -n1 | awk -F'|' '{ print $1 }')
# 	STOP_STEP_OPT=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/" | tail -n1 | awk -F'|' '{ print $2 }')
# 	STOP_STEP_GROUP="%step/${STEPNAME}/"
# 	STOP_STEP_STR="${STOP_STEP_PKGNAME}"
# fi
# echo "%step/${STEPNAME}/${STEP_PKGNAME}|${STEP_PKG_OPT}" 
# echo "${STOP_STEP_PKGNAME}" 
# echo "${STOP_STEP_OPT}" 
# echo "${STOP_STEP_GROUP}" 
# echo "${STOP_STEP_STR}" 



# 对 scripts 、files 、sources 三个目录进行比对并输出结果。

FILES_LIST=""
STEP_GROUPS=""
INCREASE_PKGS=""

echo "需要进行差异分析的步骤如下："
if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" != "xNULL" ]; then
	pushd ${BRANCH_SYNC_SOURCE} > /dev/null
		RECORD_FLAG=0
		STEP_GROUPS=${STEPNAME}
		PKGVERSION="foo"
		if [ ! -f ${BRANCH_SYNC_ABS_DIST}scripts/step/${STEPNAME}/${STEP_PKGNAME} ]; then
			if [ "x${INCREASE_MODE}" == "x0" ]; then
				echo "目标分支中没有 step/${STEPNAME}/${STEP_PKGNAME} 步骤，跳过！若要增加该步骤请使用 -i 参数执行。"
				RECORD_FLAG=0
			else
				INCREASE_PKGS="${STEPNAME}/${STEP_PKGNAME}"
				RECORD_FLAG=1
			fi
		else
			RECORD_FLAG=1
		fi
		if [ "x${RECORD_FLAG}" == "x1" ]; then
			echo "步骤 step/${STEPNAME}/${STEP_PKGNAME} 涉及的文件如下:"
			if [ -f scripts/step/${STEPNAME}/${STEP_PKGNAME} ]; then
				FILES_LIST="${FILES_LIST}|$(find scripts/step/${STEPNAME}/ -type f -name "${STEP_PKGNAME}" -exec echo "{}|" ";" -o -type f -name "${STEP_PKGNAME}.*" -exec echo "{}|" ";")"
				if [ -f scripts/step/${STEPNAME}/${STEP_PKGNAME}.info ]; then
					PKGVERSION=$(cat scripts/step/${STEPNAME}/${STEP_PKGNAME}.info | awk -F'|' '{ print $2 }')
				fi
			fi
			if [ -f sources/url/${STEPNAME}/${STEP_PKGNAME} ]; then
				FILES_LIST="${FILES_LIST}|$(find sources/url/${STEPNAME}/ -type f -name "${STEP_PKGNAME}" -exec echo "{}|" ";" -o -type f -name "${STEP_PKGNAME}.*" -exec echo "{}|" ";")"
			fi
			if [ -d files/step/${STEPNAME}/${STEP_PKGNAME}/${PKGVERSION}/ ]; then
# 				FILES_LIST="${FILES_LIST}|$(find files/step/${STEPNAME}/${STEP_PKGNAME}/${PKGVERSION}/ -type f -exec echo "{}|" ";")"
				FILES_LIST="${FILES_LIST}|files/step/${STEPNAME}/${STEP_PKGNAME}/${PKGVERSION}/"
			fi
		fi
	popd > /dev/null
fi



if [ "x${STEPNAME}" != "xNULL" ] && [ "x${STEP_PKGNAME}" == "xNULL" ]; then
	STEP_PKGS=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/${STEPNAME}/" | awk -F'|' '{ print $1 }' | sort | uniq)
	STEP_GROUPS=${STEPNAME}
	pushd ${BRANCH_SYNC_SOURCE} > /dev/null
		for step_i in ${STEP_PKGS}
		do
			PKGVERSION="foo"
			step_i_STEPNAME=$(echo "${step_i}" | awk -F'/' '{ print $2 }')
			step_i_STEP_PKGNAME=$(echo "${step_i}" | awk -F'/' '{ print $3 }')
			if [ "x${step_i_STEP_PKGNAME}" == "xNULL" ]; then
				continue;
			fi
			if [ ! -f ${BRANCH_SYNC_ABS_DIST}scripts/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} ]; then
				if [ "x${INCREASE_MODE}" == "x0" ]; then
					echo "目标分支中没有 step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} 步骤，跳过！若要增加该步骤请使用 -i 参数执行。"
					continue;
				else
					INCREASE_PKGS="${INCREASE_PKGS} ${step_i_STEPNAME}/${step_i_STEP_PKGNAME}"
				fi
			fi

# 			echo "步骤 step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} 涉及的文件如下:"
			echo "检索 step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} 步骤的差异..."
			if [ -f scripts/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} ]; then
# 				echo "$(find scripts/step/${step_i_STEPNAME}/ -type f -name "${step_i_STEP_PKGNAME}" -exec echo "        {}" ";" -o -type f -name "${step_i_STEP_PKGNAME}.*" -exec echo "	{}" ";")"
				FILES_LIST="${FILES_LIST}|$(find scripts/step/${step_i_STEPNAME}/ -type f -name "${step_i_STEP_PKGNAME}" -exec echo "{}|" ";" -o -type f -name "${step_i_STEP_PKGNAME}.*" -exec echo "{}|" ";")"
				if [ -f scripts/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}.info ]; then
					PKGVERSION=$(cat scripts/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}.info | awk -F'|' '{ print $2 }')
				fi
			fi
			if [ -f sources/url/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} ]; then
# 				echo "$(find sources/url/${step_i_STEPNAME}/ -type f -name "${step_i_STEP_PKGNAME}" -exec echo "        {}" ";" -o -type f -name "${step_i_STEP_PKGNAME}.*" -exec echo "        {}" ";")"
				FILES_LIST="${FILES_LIST}|$(find sources/url/${step_i_STEPNAME}/ -type f -name "${step_i_STEP_PKGNAME}" -exec echo "{}|" ";" -o -type f -name "${step_i_STEP_PKGNAME}.*" -exec echo "{}|" ";")"
			fi
			if [ -d files/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}/${PKGVERSION}/ ]; then
# 				echo "$(find files/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}/${PKGVERSION}/ -type f -exec echo "        {}" ";")"
# 				FILES_LIST="${FILES_LIST}|$(find files/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}/${PKGVERSION}/ -type f -exec echo "{}|" ";")"
				FILES_LIST="${FILES_LIST}|files/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}/${PKGVERSION}/"
			fi
		done
	popd > /dev/null
fi


if [ "x${STEPNAME}" == "xNULL" ] && [ "x${STEP_PKGNAME}" == "xNULL" ]; then
	STEP_PKGS=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/" | awk -F'|' '{ print $1 }' | sort | uniq)
	STEP_GROUPS=$(cat "${SOURCE_STEP_FILE}" | grep "^%step/" | awk -F'|' '{ print $1 }' | awk -F'/' '{ print $2 }' | sort | uniq)
	pushd ${BRANCH_SYNC_SOURCE} > /dev/null
		for step_i in ${STEP_PKGS}
		do
			PKGVERSION="foo"
			step_i_STEPNAME=$(echo "${step_i}" | awk -F'/' '{ print $2 }')
			step_i_STEP_PKGNAME=$(echo "${step_i}" | awk -F'/' '{ print $3 }')
			if [ "x${step_i_STEP_PKGNAME}" == "xNULL" ]; then
				continue;
			fi
			if [ ! -f ${BRANCH_SYNC_ABS_DIST}scripts/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} ]; then
				if [ "x${INCREASE_MODE}" == "x0" ]; then
					echo "目标分支中没有 step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} 步骤，若要增加该步骤请使用 -i 参数执行。"
					continue;
				else
					INCREASE_PKGS="${INCREASE_PKGS} ${step_i_STEPNAME}/${step_i_STEP_PKGNAME}"
				fi
			fi

# 			echo "步骤 step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} 涉及的文件如下:"
			echo "检索 step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} 步骤的差异..."
			if [ -f scripts/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} ]; then
# 				echo "$(find scripts/step/${step_i_STEPNAME}/ -type f -name "${step_i_STEP_PKGNAME}" -exec echo "        {}" ";" -o -type f -name "${step_i_STEP_PKGNAME}.*" -exec echo "	{}" ";")"
				FILES_LIST="${FILES_LIST}|$(find scripts/step/${step_i_STEPNAME}/ -type f -name "${step_i_STEP_PKGNAME}" -exec echo "{}|" ";" -o -type f -name "${step_i_STEP_PKGNAME}.*" -exec echo "{}|" ";")"
				if [ -f scripts/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}.info ]; then
					PKGVERSION=$(cat scripts/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}.info | awk -F'|' '{ print $2 }')
				fi
			fi
			if [ -f sources/url/${step_i_STEPNAME}/${step_i_STEP_PKGNAME} ]; then
# 				echo "$(find sources/url/${step_i_STEPNAME}/ -type f -name "${step_i_STEP_PKGNAME}" -exec echo "        {}" ";" -o -type f -name "${step_i_STEP_PKGNAME}.*" -exec echo "        {}" ";")"
				FILES_LIST="${FILES_LIST}|$(find sources/url/${step_i_STEPNAME}/ -type f -name "${step_i_STEP_PKGNAME}" -exec echo "{}|" ";" -o -type f -name "${step_i_STEP_PKGNAME}.*" -exec echo "{}|" ";")"
			fi
			if [ -d files/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}/${PKGVERSION}/ ]; then
# 				echo "$(find files/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}/${PKGVERSION}/ -type f -exec echo "        {}" ";")"
# 				FILES_LIST="${FILES_LIST}|$(find files/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}/${PKGVERSION}/ -type f -exec echo "{}|" ";")"
				FILES_LIST="${FILES_LIST}|files/step/${step_i_STEPNAME}/${step_i_STEP_PKGNAME}/${PKGVERSION}/"
			fi
		done
	popd > /dev/null
fi

echo ""
echo "检索完毕，进行差异分析报告："


parts=($(echo "${FILES_LIST}" | awk -F "|" '{
	for(i=1; i<=NF; i++) {
		if ($i != "") {
			print "	" $i
		}
	}
}'))

# SYNC_LOG_FILES_NAME="${STEPNAME}_${STEP_PKGNAME}"

if [ ! -d ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF} ]; then
	mkdir -p ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/
fi

# DIFF_ALL_STR=""
# # DIFF_FILE_LIST=""
# for parts_i in "${!parts[@]}"; do
# # 	echo "  parts[$parts_i] = '${parts[parts_i]}'"
# # 	diff -Nurp ${BASE_DIR}/Branch_${RELEASE_VERSION}/${parts[parts_i]} ${BASE_DIR}/${parts[parts_i]} || true
# 	DIFF_STR=$(diff -Nurp ${BRANCH_SYNC_DIST}${parts[parts_i]} ${BRANCH_SYNC_SOURCE}${parts[parts_i]} || true)
# 	if [ "x${DIFF_STR}" != "x" ]; then
# 		echo "${parts[parts_i]} 存在差异"
# 		DIFF_ALL_STR="${DIFF_ALL_STR}
# ${DIFF_STR}"
# # 		DIFF_FILE_LIST="${DIFF_FILE_LIST}|${parts[parts_i]}"
# # 		DIFF_FILE_LIST="${DIFF_FILE_LIST}
# # $(echo ${parts[parts_i]} | awk -F'/' ' { print $3"/"$4 }'| sed "s@\..\{0,\}\$@@g")"
# 	fi
# done

# if [ "x${DIFF_ALL_STR}" != "x" ]; then
# 	echo "${DIFF_ALL_STR}" > ${BRANCH_SYNC_DIST}./sync_diff/${SYNC_LOG_FILES_NAME}.diff
# 	# echo "${DIFF_FILE_LIST}"
# 	cat ${BRANCH_SYNC_DIST}./sync_diff/${STEPNAME}_${STEP_PKGNAME}.diff | grep "^--- ${BRANCH_SYNC_DIST}" | awk -F' ' '{ print $2 }' > ${BRANCH_SYNC_DIST}./sync_diff/${SYNC_LOG_FILES_NAME}.sync_files
# fi


PATCH_COUNT=""
COUNT=1
rm -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/sync_files
for parts_i in "${!parts[@]}"; do
	DIFF_STR=$(diff -Nurp ${BRANCH_SYNC_DIST}${parts[parts_i]} ${BRANCH_SYNC_SOURCE}${parts[parts_i]} || true)
	if [ "x${DIFF_STR}" != "x" ]; then
		printf -v PATCH_COUNT "%05d" ${COUNT}
		echo "${parts[parts_i]} 存在差异"
		mkdir -p ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/patches/
		echo "${DIFF_STR}" > ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/patches/${PATCH_COUNT}.step.diff
		echo "${parts[parts_i]}|${PATCH_COUNT}.step" >> ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/sync_files
		((COUNT++))
	fi
done


# 对 env 目录进行比对并输出结果。
# ENV_DIFF_ALL_STR=""
# for groups_i in ${STEP_GROUPS}
# do
# # 	diff -Nurp ${BRANCH_SYNC_DIST}./env/${STEPNAME} ${BRANCH_SYNC_SOURCE}./env/${STEPNAME} || true
# 	ENV_DIFF_STR=$(diff -Nurp ${BRANCH_SYNC_DIST}./env/${groups_i}/ ${BRANCH_SYNC_SOURCE}./env/${groups_i}/ || true)
# 	if [ "x${ENV_DIFF_STR}" != "x" ]; then
# 		if [ "x${INCREASE_MODE}" == "x0" ]; then
# 			if [ -d ${BRANCH_SYNC_DIST}./env/${groups_i}/ ]; then
# 				echo "根据指定的目标 ${1} 发现 env/${groups_i} 存在差异，可能需要同步。"
# 			else
# 				echo "目标 ${1} 发现 env/${groups_i} 存在差异，若需要同步请设置 -i 参数。"
# 			fi
# 		else
# 			echo "根据指定的目标 ${1} 发现 env/${groups_i} 存在差异，可能需要同步。"
# 		fi
# 		ENV_DIFF_ALL_STR="${ENV_DIFF_ALL_STR}
# ${ENV_DIFF_STR}"
# 	fi
# done
# if [ "x${ENV_DIFF_ALL_STR}" != "x" ]; then
# 	echo "${ENV_DIFF_ALL_STR}" > ${BRANCH_SYNC_DIST}./sync_diff/${SYNC_LOG_FILES_NAME}.env.diff
# 	cat ${BRANCH_SYNC_DIST}./sync_diff/${STEPNAME}_${STEP_PKGNAME}.env.diff | grep "^--- ${BRANCH_SYNC_DIST}" | awk -F' ' '{ print $2 }' > ${BRANCH_SYNC_DIST}./sync_diff/${SYNC_LOG_FILES_NAME}.env.sync_files
# fi

for groups_i in ${STEP_GROUPS}
do
	ENV_DIFF_STR=$(diff -Nurp ${BRANCH_SYNC_DIST}./env/${groups_i}/ ${BRANCH_SYNC_SOURCE}./env/${groups_i}/ || true)
	if [ "x${ENV_DIFF_STR}" != "x" ]; then
		printf -v PATCH_COUNT "%05d" ${COUNT}
		if [ "x${INCREASE_MODE}" == "x0" ]; then
			if [ -d ${BRANCH_SYNC_DIST}./env/${groups_i}/ ]; then
				echo "根据指定的目标 ${1} 发现 env/${groups_i} 存在差异，可能需要同步。"
			else
				echo "目标 ${1} 发现 env/${groups_i} 存在差异，若需要分析差异请设置 -i 参数。"
				continue;
			fi
		else
			echo "根据指定的目标 ${1} 发现 env/${groups_i} 存在差异，可能需要同步。"
		fi
		mkdir -p ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/patches/
		echo "${ENV_DIFF_STR}" > ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/patches/${PATCH_COUNT}.env.diff
		echo "env/${groups_i}|${PATCH_COUNT}.env" >> ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/env_sync_files
		((COUNT++))
	fi
done

if [ "${COUNT}" == "1" ]; then
	echo "步骤文件没有任何不同的部分，无需更新!"
fi

# 输出对 step 文件更新内容的结果。

echo -n "检查目标目录 ${BRANCH_SYNC_DIST} 中的步骤控制文件 step 是否存在差异内容..."
rm -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/.step.temp
cat "${SOURCE_STEP_FILE}" | grep -v "^#" | grep "^%step/" | while read line_all
do
	line=$(echo "${line_all}" | awk -F'|' '{ print $1 }')
        PACKAGE_ALL_OPT="$(echo "${line_all}" | awk -F'|' '{ print $2 }')"
	line_STEPNAME=$(echo "${line}" | awk -F'/' '{ print $2 }')
	line_STEP_PKGNAME=$(echo "${line}" | awk -F'/' '{ print $3 }')
	if [ ! -d ${BRANCH_SYNC_DIST}scripts/step/${line_STEPNAME} ]; then
		if [ "x${INCREASE_MODE}" == "x0" ]; then
			continue;
		fi
	fi
	if [ "x${line_STEP_PKGNAME}" == "xNULL" ]; then
		if [ ! -d ${BRANCH_SYNC_DIST}scripts/step/${line_STEPNAME} ]; then
			if [ "x${INCREASE_MODE}" == "x1" ]; then
				for groups_i in ${STEP_GROUPS}
				do
					if [ "x${line_STEPNAME}" == "x${groups_i}" ]; then
						echo "${line_all}" >> ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/.step.temp
						break;
					fi
				done
			fi
		else
			echo "${line_all}" >> ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/.step.temp
		fi
		continue;
	fi
	if [ ! -f ${BRANCH_SYNC_DIST}scripts/step/${line_STEPNAME}/${line_STEP_PKGNAME} ]; then
# 		echo "查寻 ${line_STEPNAME}/${line_STEP_PKGNAME}"
		if [ "x${INCREASE_MODE}" == "x1" ]; then
			for increase_i in ${INCREASE_PKGS}
			do
				if [ "x${line_STEPNAME}/${line_STEP_PKGNAME}" == "x${increase_i}" ]; then
					echo "${line_all}" >> ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/.step.temp
					break;
				fi
			done
		fi
	else
		echo "${line_all}" >> ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/.step.temp
	fi
done

STEP_DIFF_STR=$(diff -Nurp ${BRANCH_SYNC_DIST}./step ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/.step.temp || true)
if [ "x${STEP_DIFF_STR}" != "x" ]; then
# 	echo "发现目标目录 ${BRANCH_SYNC_DIST} 中的步骤控制文件 step 需要进行更新。"
	echo "存在需要差异内容！"
	echo "${STEP_DIFF_STR}" > ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/step.diff
else
	echo "无差异内容。"
fi

if [ ${COUNT} -gt 1 ] || [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/step.diff ]; then
	echo "输出文件均存放在 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/ 目录中。"
fi
if [ ${COUNT} -gt 1 ]; then
	if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/sync_files ]; then
		echo "涉及步骤修改的文件列表在 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/sync_files 文件中。"
	fi
	if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/env_sync_files ]; then
		echo "涉及步骤组配置修改的文件列表在 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/env_sync_files 文件中。"
	fi
	echo "步骤与配置文件修改相关的差异文件存放在 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/patches/ 目录中，共 $(expr ${COUNT} - 1) 个文件。"
fi
if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/step.diff ]; then
	echo "步骤控制文件修改差异文件 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/step.diff"
fi

if [ "x${SINGLE_PATCH}" == "x1" ]; then
	if [ ${COUNT} -gt 1 ]; then
		cat ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/patches/*.diff > ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/all.diff
	fi
	if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/step.diff ]; then
		cat ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/step.diff >> ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/all.diff
	fi
	if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/all.diff ]; then
		echo "合并差异文件 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/all.diff"
	else
		echo "因内容相同，故无需生成合并文件。"
	fi
fi

# echo "输出文件均存放在 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/ 目录中。"
if [ -f ${BRANCH_SYNC_DIST}./branch_stamp ]; then
	cat ${BRANCH_SYNC_DIST}./branch_stamp > ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/diff_stamp
else
	echo "${DATE_SUFF}" > ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/diff_stamp
fi
if [ -f ${BRANCH_SYNC_DIST}./branch_message ]; then
	echo "在 ${BRANCH_SYNC_DIST} （$(cat ${BRANCH_SYNC_DIST}./branch_message)）分支目录上创建的补丁集合。" > ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/diff_message
else
	echo "在 ${BRANCH_SYNC_DIST} 分支目录上创建的补丁集合。" > ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/diff_message
fi
echo "${DATE_SUFF}" > ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SUFF}/self_stamp
echo "${DATE_SUFF}" > ${BRANCH_SYNC_DIST}./sync_diff/current_stamp

# 应用补丁
# if [ "x${APPLY_PATCH}" == "x1 ]; then
# 	echo "正在应用补丁..."
# 	
# fi

