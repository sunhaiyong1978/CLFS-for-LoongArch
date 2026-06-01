function os_first_run
{
	set +e
	RUN_COMMOND="${1}"
	if [ -f ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run ]; then
		grep "^${1}$" ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run
		if [ "x$?" == "x0" ]; then
			return
		fi
	fi
	set -e
	echo "${1}" >> ${NEW_TARGET_SYSDIR}/scripts/os_first_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run
	return
}

function os_start_run
{
	set +e
	RUN_COMMOND="${1}"
	if [ -f ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run ]; then
		grep "^${1}$" ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run
		if [ "x$?" == "x0" ]; then
			return
		fi
	fi
	set -e
	echo "${1}" >> ${NEW_TARGET_SYSDIR}/scripts/os_start_run/${STEP_BUILDNAME}.${STEP_PACKAGENAME}.run
	return
}

function info_pool
{
	if [ "x${1}" != "x" ]; then
		echo "${1}" >> ${NEW_TARGET_SYSDIR}/logs/info_pool
	fi
}


function get_user_set_env
{
	if [ "x${1}" == "x" ]; then
		echo ""
	else
		ENV_NAME_TEMP_STR="YONGBAO_SET_ENV_${1}"
		if [ "x${!ENV_NAME_TEMP_STR}" == "x" ]; then
			echo "${2}"
		else
			echo "${!ENV_NAME_TEMP_STR}"
		fi
	fi
	return
}

function get_arch_datafile
{
	if [ "x${1}" == "x" ]; then
		echo "NULL.conf"
		return
	fi
	if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
		echo "NULL.conf"
		return
	fi
	RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "\(^\|/\)${1}\(/\|=\)" | awk -F'=' '{ print $2 }' | head -n1)"
	echo "${RET_VAL}"
	return
}

function get_arch_parm
{
	if [ "x${1}" == "x" ]; then
		echo "ERROR"
		return
	fi
	if [ "x${2}" == "x" ]; then
		echo "ERROR"
		return
	fi

	ARCH_DATAFILE=$(get_arch_datafile "${1}")
	if [ "x${ARCH_DATAFILE}" == "xNULL.conf" ]; then
		echo "ERROR"
		return
	fi
	RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/data/${ARCH_DATAFILE} | grep "^${2}=" | awk -F"^${2}=" '{ print $2 }' | head -n1)"
	echo "${RET_VAL}"
	return

}


function replace_arch_parm
{
	if [ "x${2}" == "x" ]; then
		SEARCH_ARCH=$(uname -m)
	else
		SEARCH_ARCH=${2}
	fi
	RET_VAL="${1}"
	for replace in $(echo "${1}" | grep -o "<<<[^>]*>>>")
	do
		RET_VAL="$(echo "${RET_VAL}" | sed "s@${replace}@$(get_arch_parm "${SEARCH_ARCH}" ${replace:3:-3})@g")"
	done
	echo "${RET_VAL}"
	return
}


function archname_to_anyparm
{
	if [ "x${1}" == "x" ]; then
		if [ "x${3}" == "x" ]; then
			echo ""
			exit 1
		else
			echo "${3}"
		fi
	else
# 		if [ "x${1}" == "x${3}" ]; then
# 			echo "${3}"
# 		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
#				echo "无法识别名称: ${1}"
				echo ""
                                exit 1
			fi
# #			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $2 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "${2}")"
			if [ "x${RET_VAL}" == "x" ] || [ "x${RET_VAL}" == "xERROR" ]; then
#				echo "没有找到名称或参数: ${1} ${2}"
#				exit 1
				echo "${3}"
			else
				echo "${RET_VAL}"
			fi
# 		fi
	fi
	return
}



function archname_to_name
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
# 		if [ "x${1}" == "x${2}" ]; then
# 			echo "${2}"
# 		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
# #			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $2 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "NAME")"
			if [ "x${RET_VAL}" == "x" ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			else
				echo "${RET_VAL}"
			fi
# 		fi
	fi
	return
}



function archname_to_linuxname
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
		if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
			echo "无法识别名称: ${1}"
                               exit 1
		fi
#		RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $2 }' | sed "s@[[:space:]]@@g")"
		RET_VAL="$(get_arch_parm "${1}" "LINUX_NAME")"
		if [ "x${RET_VAL}" == "x" ]; then
			echo "无法识别名称: ${1}"
                               exit 1
		else
			echo "${RET_VAL}"
		fi
	fi
	return
}

function archname_to_triple
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
#		if [ "x${1}" == "x${2}" ]; then
#			echo "${2}"
#		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
			# RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}[[:space:]]" | awk -F"^${1}" '{ print $2 }' | sed "s@[[:space:]]@@g")"
# #			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $3 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "TRIPLE")"
			if [ "x${RET_VAL}" == "x" ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			else
				echo "${RET_VAL}"
			fi
#		fi
	fi
	return
}

function archname_to_archbit
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
# 		if [ "x${1}" == "x${2}" ]; then
# 			echo "${2}"
# 		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
# #			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $4 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "BIT")"
			if [ "x${RET_VAL}" == "x" ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			else
				echo "${RET_VAL}"
			fi
# 		fi
	fi
	return
}

function archname_to_lib_suff
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
# 		if [ "x${1}" == "x${2}" ]; then
# 			echo "${2}"
# 		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
# #			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $4 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "LIB_SUFF")"
			echo "${RET_VAL}"
# 		fi
	fi
	return
}

function archbit_to_lib_suff
{
	case "${1}" in
		64)
			echo "64"
			;;
		*)
			echo ""
			;;
	esac
}

function archname_to_archabi
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
# 		if [ "x${1}" == "x${2}" ]; then
# 			echo "${2}"
# 		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
# 			RET_VAL="$(cat ${NEW_TARGET_SYSDIR}/../env/arch.data | grep "^${1}=" | awk -F"=" '{ print $5 }' | sed "s@[[:space:]]@@g")"
			RET_VAL="$(get_arch_parm "${1}" "ABI")"
			if [ "x${RET_VAL}" == "x" ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			else
				echo "${RET_VAL}"
			fi
# 		fi
	fi
	return
}

function archname_to_cflags
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
# 		if [ "x${1}" == "x${2}" ]; then
# 			echo "${2}"
# 		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
			RET_VAL="$(get_arch_parm "${1}" "CFLAGS")"
			echo "${RET_VAL}"
# 		fi
	fi
	return
}

function archname_to_cxxflags
{
	if [ "x${1}" == "x" ]; then
		if [ "x${2}" == "x" ]; then
			exit 1
		else
			echo "${2}"
		fi
	else
# 		if [ "x${1}" == "x${2}" ]; then
# 			echo "${2}"
# 		else
			if [ ! -f ${NEW_TARGET_SYSDIR}/../env/arch.data ]; then
				echo "无法识别名称: ${1}"
                                exit 1
			fi
			RET_VAL="$(get_arch_parm "${1}" "CXXFLAGS")"
			echo "${RET_VAL}"
		fi
# 	fi
	return
}

function save_package_version
{
	declare SAVE_PACKAGE_NAME=""
	declare SAVE_PACKAGE_VERSION=""
	if [ "x${1}" == "x" ]; then
		SAVE_PACKAGE_NAME="${STEP_PACKAGENAME}"
	else
		SAVE_PACKAGE_NAME="${1}"
	fi
	if [ "x${2}" == "x" ]; then
		SAVE_PACKAGE_VERSION="${PACKAGE_VERSION}"
	else
		SAVE_PACKAGE_VERSION="${2}"
	fi
	if [ "x${SAVE_PACKAGE_NAME}" == "x" ]; then
		SAVE_PACKAGE_NAME="foo"
	fi
	echo "${SAVE_PACKAGE_VERSION}" > ${COMMON_DIR}/${SAVE_PACKAGE_NAME}.version
	return
}

function get_package_version
{
	declare GET_PACKAGE_NAME="${1}"
	if [ "x${GET_PACKAGE_NAME}" == "x" ]; then
		echo "unknown"
		return
	fi
	if [ ! -f ${COMMON_DIR}/${GET_PACKAGE_NAME}.version ]; then
		echo "noversion"
		return
	fi
	echo "$(cat ${COMMON_DIR}/${GET_PACKAGE_NAME}.version | head -n1)"
	return
}

function get_system_pkg_config_path
{
	if [ -f /bin/pkgconf ]; then
		PKGCONF_NAME=/bin/pkgconf
		GET_PKG_VERSION=$(${PKGCONF_NAME} --version)
	else
		if [ -f /bin/pkg-config ]; then
			PKGCONF_NAME=/bin/pkg-config
			GET_PKG_VERSION=$(${PKGCONF_NAME} --version)
		else
			GET_PKG_VERSION="0"
		fi
	fi
	case "x${GET_PKG_VERSION:0:1}" in
		x1|x2)
			echo "$(${PKGCONF_NAME} --dump-personality | grep "^DefaultSearchPaths:" | awk -F':' '{ print $2 }' | sed "s@ @:@g" | sed "s@^:@@g" | sed "s@:\$@@g")"
			;;
		*)
			echo "/usr/lib${LIB_SUFF}/pkgconfig"
			;;
	esac
	return
}

function set_strip_step
{
        declare STRIP_SET_DIRECTORY="/usr/bin"
        declare STRIP_SET_DIRECTORY_DEPTH="1"
        declare STRIP_SET_FILES="*"
        declare STRIP_SET_COMMAND="strip"
        declare STRIP_SET_COMMAND_PARM="--strip-all"

	declare OVERLAY_DIR="sysroot"

	if [ "x${OPT_SET_OVERLAY_DIR}" == "x" ]; then
	        OVERLAY_DIR=$(cat ${NEW_TARGET_SYSDIR}/../env/${STEP_BUILDNAME}/overlay.set | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
	else
		OVERLAY_DIR=$(echo "${OPT_SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

	if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
		OVERLAY_DIR=$(echo "${SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

	if [ "x${OVERLAY_DIR}" == "x" ]; then
		return
	fi

	if [ -d ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR} ]; then
		if [ ! -f ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.strip ]; then
			touch ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.strip
		fi
	else
		return
	fi
	
	if [ "x${1}" == "x" ]; then
		return
	fi
	STRIP_SET_DIRECTORY="${1}"

	if [ "x${2}" == "x0" ]; then
		STRIP_SET_DIRECTORY_DEPTH="0"
	else
		STRIP_SET_DIRECTORY_DEPTH="1"
	fi

	if [ "x${3}" == "x" ]; then
		STRIP_SET_FILES="*"
	else
		STRIP_SET_FILES="${3}"
	fi


	if [ "x${4}" == "x" ]; then
		STRIP_SET_COMMAND_PARM="--strip-all"
	else
		STRIP_SET_COMMAND_PARM="${4}"
	fi

	if [ "x${5}" == "x" ]; then
		STRIP_SET_COMMAND="$(command -v ${CROSS_TARGET}-strip)"
	else
		STRIP_SET_COMMAND="$(command -v ${5})"
	fi
	if [ "x${STRIP_SET_COMMAND}" == "x" ]; then
		return
	fi


	echo "${STRIP_SET_DIRECTORY}	${STRIP_SET_DIRECTORY_DEPTH}	${STRIP_SET_FILES}	${STRIP_SET_COMMAND}	${STRIP_SET_COMMAND_PARM}" >> ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.strip

	return
}

function set_split_conf
{
        declare SPLIT_PART_NAME="devel"
        declare SPLIT_DIRECTORY="/usr/include"
        declare SPLIT_MATCH_RULE="*"

	declare OVERLAY_DIR="sysroot"

	if [ "x${OPT_SET_OVERLAY_DIR}" == "x" ]; then
	        OVERLAY_DIR=$(cat ${NEW_TARGET_SYSDIR}/../env/${STEP_BUILDNAME}/overlay.set | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
	else
		OVERLAY_DIR=$(echo "${OPT_SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

	if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
		OVERLAY_DIR=$(echo "${SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

	if [ "x${OVERLAY_DIR}" == "x" ]; then
		return
	fi

	if [ -d ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR} ]; then
		if [ ! -f ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.split ]; then
			touch ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.split
		fi
	else
		return
	fi
	
	if [ "x${1}" == "x" ]; then
		return
	fi
	SPLIT_PART_NAME="${1}"

	if [ "x${2}" == "x0" ]; then
		return
	fi
	SPLIT_DIRECTORY="${2}"

	if [ "x${3}" == "x" ]; then
		SPLIT_MATCH_RULE="*"
	else
		SPLIT_MATCH_RULE="${3}"
	fi

	echo "${SPLIT_PART_NAME}	${SPLIT_DIRECTORY}	${SPLIT_MATCH_RULE}" >> ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.split

	return
}

function set_final_fix_step
{
        declare FINAL_FIX_SET_DIRECTORY="/usr/bin"
        declare FINAL_FIX_SET_FILES_TYPE="f"
        declare FINAL_FIX_SET_COMMAND_OPT="F"
        declare FINAL_FIX_SET_COMMAND_DEST=""
        declare FINAL_FIX_SET_COMMAND_DEST_FIX=""

	declare OVERLAY_DIR="sysroot"

	if [ "x${OPT_SET_OVERLAY_DIR}" == "x" ]; then
	        OVERLAY_DIR=$(cat ${NEW_TARGET_SYSDIR}/../env/${STEP_BUILDNAME}/overlay.set | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
	else
		OVERLAY_DIR=$(echo "${OPT_SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

	if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
		OVERLAY_DIR=$(echo "${SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

	if [ "x${OVERLAY_DIR}" == "x" ]; then
		return
	fi

	if [ -d ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR} ]; then
		if [ ! -f ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.final_fix ]; then
			touch ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.final_fix
		fi
	else
		return
	fi
	
	if [ "x${1}" == "x" ]; then
		return
	fi
	FINAL_FIX_SET_DIRECTORY="${1}"

	case "x${2}" in
		xD | xF | xS | xC)
			FINAL_FIX_COMMAND_OPT="${2}"
			;;
		*)
		FINAL_FIX_COMMAND_OPT="F"
	esac

	case "x${3}" in
		xf | xd | xl | xg)
			FINAL_FIX_FILES_TYPE="${3}"
			;;
		*)
			FINAL_FIX_FILES_TYPE="f"
			;;
	esac

	if [ "x${4}" == "x" ]; then
		FINAL_FIX_SET_COMMAND_DEST=""
	else
		FINAL_FIX_SET_COMMAND_DEST="${4}"
	fi

	if [ "x${5}" == "x" ]; then
		FINAL_FIX_SET_COMMAND_DEST_FIX=""
	else
		FINAL_FIX_SET_COMMAND_DEST_FIX="${5}"
	fi


	echo "${FINAL_FIX_SET_DIRECTORY}|${FINAL_FIX_COMMAND_OPT}|${FINAL_FIX_FILES_TYPE}|${FINAL_FIX_SET_COMMAND_DEST}|${FINAL_FIX_SET_COMMAND_DEST_FIX}" >> ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.final_fix

	return
}




function set_step_to_dist
{
	declare OVERLAY_DIR="sysroot"

	if [ "x${OPT_SET_OVERLAY_DIR}" == "x" ]; then
	        OVERLAY_DIR=$(cat ${NEW_TARGET_SYSDIR}/../env/${STEP_BUILDNAME}/overlay.set | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
	else
		OVERLAY_DIR=$(echo "${OPT_SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

	if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
		OVERLAY_DIR=$(echo "${SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

	if [ "x${OVERLAY_DIR}" == "x" ]; then
		return
	fi

	if [ -d ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR} ]; then
# 		if [ ! -f ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.dist ]; then
#			touch ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.dist
# 		fi
		echo "export STEP_BUILDNAME=${STEP_BUILDNAME}" >> ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.dist
# 		echo "export SYSDIR=${SYSDIR}" >> ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.dist
		echo "export TEMP_DIRECTORY=${TEMP_DIRECTORY}" >> ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}.dist
	else
		return
	fi

}


function run_step_package_check
{
	if [ "x${BUILD_PACKAGE_CHECK}" == "x0" ]; then
		return 0
	fi
	if [ "x${RUN_TARGET_ARCH}" == "x$(uname -m)" ]; then
		if [ ! -f ${NEW_TARGET_SYSDIR}/../scripts/step/${STEP_BUILDNAME}/${STEP_PACKAGENAME}.check ]; then
			case "x${1}" in
				"xcheck")
# 					make LDFLAGS="${LDFLAGS} ${TEST_LDFLAGS}" -j${JOBS} check
					make -j${JOBS} check
					;;
				"xtests")
# 					make LDFLAGS="${LDFLAGS} ${TEST_LDFLAGS}" -j${JOBS} tests
					make -j${JOBS} tests
					;;
				"xtest")
					make -j${JOBS} test
					;;
				"xninja")
					ninja check
					;;
				*)
					return 0
					;;
			esac
		else
			source ${NEW_TARGET_SYSDIR}/../scripts/step/${STEP_BUILDNAME}/${STEP_PACKAGENAME}.check
		fi
	else
		return 0
	fi
}


function default_set_comment
{
#	default_set_comment "x86_64-emu" "X86 64位二进制翻译" "/usr/bin/x86_64-emu"

        declare OVERLAY_DIR="sysroot"

        if [ "x${OPT_SET_OVERLAY_DIR}" == "x" ]; then
                OVERLAY_DIR=$(cat ${NEW_TARGET_SYSDIR}/../env/${STEP_BUILDNAME}/overlay.set | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
        else
                OVERLAY_DIR=$(echo "${OPT_SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
        fi

	if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
		OVERLAY_DIR=$(echo "${SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

        if [ "x${OVERLAY_DIR}" == "x" ]; then
                return
        fi

	if [ "x${1}" == "x" ]; then
		return
	fi
	declare DEFAULT_SET_NAME="${1}"

	declare DEFAULT_SET_COMMENT=""
	if [ "x${2}" != "x" ]; then
		DEFAULT_SET_COMMENT="${2}"
	fi

	if [ "x${3}" == "x" ]; then
		return
	fi
	declare DEFAULT_SET_COMMAND="${3}"

        if [ -d ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR} ]; then
                mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}/etc/default-set
                echo "${DEFAULT_SET_COMMENT}|${DEFAULT_SET_COMMAND}" > ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}/etc/default-set/${DEFAULT_SET_NAME}.comment
        else
                return
        fi

	return 
}

function default_set_conf
{
        declare OVERLAY_DIR="sysroot"

        if [ "x${OPT_SET_OVERLAY_DIR}" == "x" ]; then
                OVERLAY_DIR=$(cat ${NEW_TARGET_SYSDIR}/../env/${STEP_BUILDNAME}/overlay.set | grep "overlay_dir=" | head -n1 | gawk -F'=' '{ print $2 }')
        else
                OVERLAY_DIR=$(echo "${OPT_SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
        fi

	if [ "x${SET_OVERLAY_DIR}" != "x" ]; then
		OVERLAY_DIR=$(echo "${SET_OVERLAY_DIR}" | sed -e "s@,@ @g" -e "s@[^[:alnum:]\|^[:space:]\|^_\|^\.\|^-]@@g")
	fi

        if [ "x${OVERLAY_DIR}" == "x" ]; then
                return
        fi

	if [ "x${1}" == "x" ]; then
		return
	fi
	declare DEFAULT_SET_NAME="${1}"
	if [ "x${2}" == "x" ]; then
		return
	fi
	declare DEFAULT_SET_VERSION="${2}"

        if [ -d ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR} ]; then
		mkdir -p ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}/etc/default-set/${DEFAULT_SET_NAME}/
		touch ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}/etc/default-set/${DEFAULT_SET_NAME}/${DEFAULT_SET_VERSION}
		echo "SET=${3}|${4}|${5}|" > ${NEW_TARGET_SYSDIR}/overlaydir/${OVERLAY_DIR}/etc/default-set/${DEFAULT_SET_NAME}/${DEFAULT_SET_VERSION}
        else
                return
        fi
}

# if [ -f ${NEW_TARGET_SYSDIR}/set_env.conf ]; then
# 	source ${NEW_TARGET_SYSDIR}/set_env.conf
# fi
if [ -f ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf ]; then
	source ${NEW_TARGET_SYSDIR}/temp/package_env_${YONGBAO_BUILD_UUID}.conf
fi

# if [ -f ${NEW_TARGET_SYSDIR}/package_unset.conf ]; then
# 	source ${NEW_TARGET_SYSDIR}/package_unset.conf
# fi


function unpack_for_pkg_format
{
	if [ "x${1}" == "x" ] || [ "x${1}" == "xsource" ]; then
		return
	fi
	if [ "x${2}" == "x" ]; then
		return
	fi
	if [ "x${3}" == "x" ]; then
		return
	fi
	rpmbuild --target=${3} -bp SPECS/${2}.spec --define "_topdir ${PWD}"
# 	rpmbuild --buildroot=${PWD}/test --target=loongarch64 -bp gcc.spec --define "_topdir ${PWD}"
	if [ "x${4}" != "x0" ]; then
		RPM_PACKAGE_NAME=$(rpm --specfile --target=${3} --info SPECS/${2}.spec | grep Name | head -n1 | awk -F':' '{ print $2 }' | sed "s@ @@g")
		RPM_PACKAGE_VERSION=$(rpm --specfile --target=${3} --info SPECS/${2}.spec | grep Version | head -n1 | awk -F':' '{ print $2 }' | sed "s@ @@g")
		cd BUILD/${RPM_PACKAGE_NAME}-${RPM_PACKAGE_VERSION}*
	fi
	return
}

function check_gnu_Makefile
{
	if [ "x${CHECK_GNU_MAKEFILE_DISABLE}" == "x1" ]; then
		return
	fi
	touch foo
# 	GREP_RETURN_STR="$(grep -r -e " \/usr\/lib${LIB_SUFF}\/lib" -e " \-L\/usr\/lib${LIB_SUFF}" $(find -name "Makefile") foo || true)"
# 	GREP_RETURN_STR="$(grep -r -e " \/usr\/lib\(\|64\|32\)\/lib" -e " \-L\/usr\/lib\(\|64\|32\)" -e "\-rpath\(,\| \)\/usr\/lib" $(find -name "Makefile") foo || true)"
	GREP_RETURN_STR="$(grep -r -e "^[^#].* \/usr\/lib\(\|64\|32\)\/lib.*\.\(so\|\a\)" -e "^[^#].* \-L\/usr\/lib\(\|64\|32\)" -e "^[^#].*\-Wl,\-rpath\(,\|=\)\/usr\/lib" $(find -name "Makefile") foo || true)"
	if [ "x${GREP_RETURN_STR}" != "x" ]; then
		echo "配置过程可能使用了主系统的库，请检查。"
		echo "${GREP_RETURN_STR}"
		exit 1;
	fi
}
