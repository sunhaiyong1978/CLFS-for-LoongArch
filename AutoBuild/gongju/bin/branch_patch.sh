#!/bin/bash -e

export BASE_DIR="${PWD}"

SCRIPTS_DIR="${BASE_DIR}/scripts"
declare RELEASE_VERSION=""
declare INCREASE_MODE=0
declare SYNC_DIST_SET=""
declare REVERT_PATCH=0
declare RESTORE_PATCH=0
declare DATA_SUFF="$(date +%Y%m%d%H%M%S)"

function main_help
{
            echo "说明：对目标目录进行内容的同步或生成补丁文件。"
            echo "用法: ./`basename $0`"
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
            echo "    -R: 取消最后一次使用的补丁。"
            echo "    -N: 应用最后一次取消的补丁。"
            echo "    -D 版本: 设置同步的目的目录，设置的\"版本\"增加Branch_作为目录。"
            exit 0
}

while getopts 'RND:h' OPT; do
    case $OPT in
	R)
	    REVERT_PATCH=1
	    ;;
	N)
	    RESTORE_PATCH=1
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


function patch_to_directory
{
	if [ "x${1}" == "x" ]; then
		return 1
	fi
	if [ "x${2}" == "x" ]; then
		return 1
	fi
	if [ "x${3}" == "x" ]; then
		return 1
	fi
	declare PATCH_RUN=0
	if [ "x${4}" == "x1" ]; then
		PATCH_RUN=1
	fi

	TO_DIRECTORY="${1}"
	DIFF_DATE_SYNC="${2}"
	CONTROL_FILE="${3}"

	if [ ! -d ${TO_DIRECTORY} ]; then
		return 2
	fi

	if [ ! -f ${TO_DIRECTORY}./sync_diff/${DIFF_DATE_SYNC}/${CONTROL_FILE} ]; then
		return 2
	fi


	pushd ${TO_DIRECTORY} > /dev/null
		mkdir -p ./sync/${DIFF_DATE_SYNC}/patches/
		case ${CONTROL_FILE##*.} in
			diff | patch)
# 				echo "patch -Np1 -i ./sync_diff/${DIFF_DATE_SYNC}/${CONTROL_FILE}"
				if [ "x${PATCH_RUN}" == "x0" ]; then
					patch --dry-run -Np1 -i ./sync_diff/${DIFF_DATE_SYNC}/${CONTROL_FILE}
					if [ "x$?" != "x0" ]; then
						return 3
					fi
				else
					patch -Np1 -i ./sync_diff/${DIFF_DATE_SYNC}/${CONTROL_FILE}
					if [ "x$?" != "x0" ]; then
						return 3
					fi
					cp -f ./sync_diff/${DIFF_DATE_SYNC}/${CONTROL_FILE} sync/${DIFF_DATE_SYNC}/
				fi
				;;
			*)
				cat "./sync_diff/${DIFF_DATE_SYNC}/${CONTROL_FILE}" | grep -v "^#" | while read line_all
				do
# #		 			TO_PATCH_FILE=$(echo "${line_all}" | awk -F'|' '{ print $1 }')
					USE_PATCH_FILE="$(echo "${line_all}" | awk -F'|' '{ print $2 }')"
# 					echo "patch -Np1 -i ./sync_diff/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff"
					if [ -f ./sync_diff/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff ]; then
						if [ "x${PATCH_RUN}" == "x0" ]; then
							patch --dry-run -Np1 -i ./sync_diff/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff
							if [ "x$?" != "x0" ]; then
								return 3
							fi
						else
							patch -Np1 -i ./sync_diff/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff
							if [ "x$?" != "x0" ]; then
								return 3
							fi
							cp -f ./sync_diff/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff sync/${DIFF_DATE_SYNC}/patches/
						fi
					fi
				done
				if [ "x${PATCH_RUN}" == "x1" ]; then
					cp -f ./sync_diff/${DIFF_DATE_SYNC}/${CONTROL_FILE} sync/${DIFF_DATE_SYNC}/
				fi
				;;
		esac
	popd > /dev/null
	return 0
}

function unpatch_to_directory
{
	if [ "x${1}" == "x" ]; then
		return 1
	fi
	if [ "x${2}" == "x" ]; then
		return 1
	fi
	if [ "x${3}" == "x" ]; then
		return 1
	fi
	PATCH_DRY_RUN=1
	if [ "x${4}" == "x1" ]; then
		PATCH_DRY_RUN=0
	fi

	TO_DIRECTORY="${1}"
	DIFF_DATE_SYNC="${2}"
	CONTROL_FILE="${3}"

	if [ ! -d ${TO_DIRECTORY} ]; then
		return 2
	fi

	if [ ! -f ${TO_DIRECTORY}./sync/${DIFF_DATE_SYNC}/${CONTROL_FILE} ]; then
		return 2
	fi


	pushd ${TO_DIRECTORY} > /dev/null
		case ${CONTROL_FILE##*.} in
			diff | patch)
				if [ "x${PATCH_DRY_RUN}" == "x1" ]; then
					patch --dry-run -Rp1 -i ./sync/${DIFF_DATE_SYNC}/${CONTROL_FILE}
					if [ "x$?" != "x0" ]; then
						return 3
					fi
				else
					patch -Rp1 -i ./sync/${DIFF_DATE_SYNC}/${CONTROL_FILE}
					if [ "x$?" != "x0" ]; then
						return 3
					fi
				fi
				;;
			*)
				cat "./sync/${DIFF_DATE_SYNC}/${CONTROL_FILE}" | grep -v "^#" | while read line_all
				do
					USE_PATCH_FILE="$(echo "${line_all}" | awk -F'|' '{ print $2 }')"
					if [ -f ./sync/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff ]; then
						if [ "x${PATCH_DRY_RUN}" == "x1" ]; then
							patch --dry-run -Rp1 -i ./sync/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff
							if [ "x$?" != "x0" ]; then
								return 3
							fi
						else
							patch -Rp1 -i ./sync/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff
							if [ "x$?" != "x0" ]; then
								return 3
							fi
						fi
					fi
				done
				;;
		esac
	popd > /dev/null
	return 0
}

function repatch_to_directory
{
	if [ "x${1}" == "x" ]; then
		return 1
	fi
	if [ "x${2}" == "x" ]; then
		return 1
	fi
	if [ "x${3}" == "x" ]; then
		return 1
	fi
	declare PATCH_RUN=0
	if [ "x${4}" == "x1" ]; then
		PATCH_RUN=1
	fi

	TO_DIRECTORY="${1}"
	DIFF_DATE_SYNC="${2}"
	CONTROL_FILE="${3}"

	if [ ! -d ${TO_DIRECTORY} ]; then
		return 2
	fi

	if [ ! -f ${TO_DIRECTORY}./sync/${DIFF_DATE_SYNC}/${CONTROL_FILE} ]; then
		return 2
	fi


	pushd ${TO_DIRECTORY} > /dev/null
		case ${CONTROL_FILE##*.} in
			diff | patch)
				if [ "x${PATCH_RUN}" == "x0" ]; then
					patch --dry-run -Np1 -i ./sync/${DIFF_DATE_SYNC}/${CONTROL_FILE}
					if [ "x$?" != "x0" ]; then
						return 3
					fi
				else
					patch -Np1 -i ./sync/${DIFF_DATE_SYNC}/${CONTROL_FILE}
					if [ "x$?" != "x0" ]; then
						return 3
					fi
				fi
				;;
			*)
				cat "./sync/${DIFF_DATE_SYNC}/${CONTROL_FILE}" | grep -v "^#" | while read line_all
				do
					USE_PATCH_FILE="$(echo "${line_all}" | awk -F'|' '{ print $2 }')"
					if [ -f ./sync/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff ]; then
						if [ "x${PATCH_RUN}" == "x0" ]; then
							patch --dry-run -Np1 -i ./sync/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff
							if [ "x$?" != "x0" ]; then
								return 3
							fi
						else
							patch -Np1 -i ./sync/${DIFF_DATE_SYNC}/patches/${USE_PATCH_FILE}.diff
							if [ "x$?" != "x0" ]; then
								return 3
							fi
						fi
					fi
				done
				;;
		esac
	popd > /dev/null
	return 0
}




BRANCH_SYNC_ABS_DIST=""
BRANCH_SYNC_DIST=""

if [ "x${SYNC_DIST_SET}" == "x" ]; then
	if [ -f ${BASE_DIR}/current_branch ]; then
		RELEASE_VERSION="$(cat ${BASE_DIR}/current_branch | grep -v "^#" | grep -v "^$" | head -n1 | sed "s@[^?\|^[:alnum:]\|^\.\|^[:space:]\|^_\|^-]@@g")"
		if [ -d ${BASE_DIR}/Branch_${RELEASE_VERSION} ]; then
			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将对该目录中进行文件更新。"
		else
			echo "没有发现 Branch_${RELEASE_VERSION} 目录，无法继续。"
			exit 1
		fi
		BRANCH_SYNC_ABS_DIST=${BASE_DIR}/Branch_${RELEASE_VERSION}/
		BRANCH_SYNC_DIST=Branch_${RELEASE_VERSION}/
	else
		echo "没有发现 current_branch 文件，无法确定需要进行同步的分支名。"
		exit 1
	fi
else
	if [ -d ${BASE_DIR}/Branch_${SYNC_DIST_SET} ]; then
		RELEASE_VERSION="${SYNC_DIST_SET}"
	else
		echo "没有发现 Branch_${SYNC_DIST_SET} 目录，无法进行同步，请指定正确的目录。"
		exit 1
	fi
	BRANCH_SYNC_ABS_DIST=${BASE_DIR}/Branch_${RELEASE_VERSION}/
	BRANCH_SYNC_DIST=Branch_${RELEASE_VERSION}/
fi

if [ "x${BRANCH_SYNC_DIST}" == "x" ] && [ ! -d ${BRANCH_SYNC_DIST} ]; then
	echo "目标目录 “${BRANCH_SYNC_DIST}” 找不到，无法继续！"
	exit 2
fi

if [ "x${REVERT_PATCH}" == "x0" ]; then
	# 打补丁

	DATE_SYNC=""
	if [ -f ${BRANCH_SYNC_DIST}./sync/unpatch_stamp ]; then
		DATE_SYNC=$(cat ${BRANCH_SYNC_DIST}./sync/unpatch_stamp | grep -v "^#" | tail -n1)
	fi
	if [ "x${DATE_SYNC}" == "x" ] && [ "x${RESTORE_PATCH}" == "x1" ]; then
		echo "因使用了 -N 参数，将强制使用保存在 ${BRANCH_SYNC_DIST}./sync/ 目录中最近一次被取消的补丁进行应用，但该目录中未发现存在取消的补丁，无法继续，如需要使用新补丁，请去掉 -N 参数后重新运行。"
		exit 9
	fi
	if [ "x${DATE_SYNC}" != "x" ] && [ "x${RESTORE_PATCH}" == "x1" ]; then
		if [ ! -d ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/ ]; then
			echo "没有找到差异目录 ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/ ，无法继续！"
		        exit 4
		fi
		echo "更新分支：${BRANCH_SYNC_ABS_DIST} (${BRANCH_SYNC_DIST}) ，差异目录 ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/"
		DIFF_STAMP=""
		if [ -f ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/diff_stamp ]; then
			DIFF_STAMP=$(cat ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/diff_stamp)
		fi

		if [ -f ${BRANCH_SYNC_DIST}/sync/branch_stamp ]; then
			if [ "x${DIFF_STAMP}" != "x$(cat ${BRANCH_SYNC_DIST}/sync/branch_stamp | grep -v "^#" | tail -n1)" ]; then
				echo "${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/diff_stamp 和 ${BRANCH_SYNC_DIST}/sync/branch_stamp 不匹配，当前分支可能已经进行了变更，与差异目录记录的信息不一致，无法进行恢复补丁的操作。"
				exit 5
			fi
		else
			if [ "x${DIFF_STAMP}" != "x" ]; then
				echo "${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/diff_stamp 存在记录，但 ${BRANCH_SYNC_DIST}/sync/branch_stamp 文件丢失，当前分支可能已经进行了变更，与差异目录记录的信息不一致，无法进行恢复补丁的操作。"
				exit 5
			fi
		fi
		echo "记录时间戳一致，可以进行更新。"

		PATCH_ERROR=0
		for sync_i in sync_files env_sync_files step.diff
		do
			if [ -f ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/${sync_i} ]; then
				set +e
				repatch_to_directory "${BRANCH_SYNC_DIST}" "${DATE_SYNC}" "${sync_i}" "0"
				if [ "x$?" != "x0" ]; then
					PATCH_ERROR=1
					break;
				fi
				set -e
			fi
		done
		if [ "x${PATCH_ERROR}" == "x0" ]; then
			echo "恢复补丁验证成功，进行实际的恢复过程..."
			for sync_i in sync_files env_sync_files step.diff
			do
				if [ -f ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/${sync_i} ]; then
					set +e
					repatch_to_directory "${BRANCH_SYNC_DIST}" "${DATE_SYNC}" "${sync_i}" "1"
					if [ "x$?" != "x0" ]; then
						echo "补丁恢复失败，无法继续！"
						exit 6
						break;
					fi
					set -e
				fi
			done
			echo "${DATE_SYNC}" >> ${BRANCH_SYNC_DIST}./sync/branch_stamp
			sed -i '$d' ${BRANCH_SYNC_DIST}./sync/unpatch_stamp
			echo "从 ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/ 补丁恢复成功！"
		else
			echo "补丁恢复验证失败，无法继续！"
			exit 6
		fi
	else
		if [ -f ${BRANCH_SYNC_DIST}./sync_diff/current_stamp ]; then
			DATE_SYNC=$(cat ${BRANCH_SYNC_DIST}./sync_diff/current_stamp | grep -v "^#" | head -n1)
		fi
		if [ "x${DATE_SYNC}" == "x" ]; then
			echo "没有找到差异目录信息！"
			exit 3
		fi
		if [ ! -d ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/ ]; then
			echo "没有找到差异目录 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/ ，无法继续！"
			exit 4
		fi
		echo "更新分支：${BRANCH_SYNC_ABS_DIST} (${BRANCH_SYNC_DIST}) ，差异目录 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/"

		DIFF_STAMP=""
		if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/diff_stamp ]; then
			DIFF_STAMP=$(cat ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/diff_stamp)
		fi

		if [ -f ${BRANCH_SYNC_DIST}/sync/branch_stamp ]; then
			if [ "x${DIFF_STAMP}" != "x$(cat ${BRANCH_SYNC_DIST}/sync/branch_stamp | grep -v "^#" | tail -n1)" ]; then
				echo "${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/diff_stamp 和 ${BRANCH_SYNC_DIST}/sync/branch_stamp 不匹配，当前分支可能已经进行了变更，与差异目录记录的信息不一致，无法进行更新操作。"
				exit 5
			fi
		else
			if [ "x${DIFF_STAMP}" != "x" ]; then
				echo "${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/diff_stamp 存在记录，但 ${BRANCH_SYNC_DIST}/sync/branch_stamp 文件丢失，当前分支可能已经进行了变更，与差异目录记录的信息不一致，无法进行更新操作。"
				exit 5
			fi
		fi

		echo "记录时间戳一致，可以进行更新。"

		PATCH_ERROR=0
		for sync_i in sync_files env_sync_files step.diff
		do
			if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/${sync_i} ]; then
# 				PATCH_SUCCESS=$(patch_to_directory ${BRANCH_SYNC_DIST} ${DATE_SYNC} sync_files)
# 				if [ "x${PATCH_SUCCESS}" == "x0" ]; then
				set +e
# 				echo "patch_to_directory \"${BRANCH_SYNC_DIST}\" \"${DATE_SYNC}\" \"${sync_i}\" \"0\""
				patch_to_directory "${BRANCH_SYNC_DIST}" "${DATE_SYNC}" "${sync_i}" "0"
				if [ "x$?" != "x0" ]; then
					PATCH_ERROR=1
					break;
				fi
				set -e
			fi
		done

# 		if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/env_sync_files ]; then
# # 			PATCH_SUCCESS=$(patch_to_directory ${BRANCH_SYNC_DIST} ${DATE_SYNC} env_sync_files)
# # 			if [ "x${PATCH_SUCCESS}" == "x0" ]; then
# 			set +e
# 			patch_to_directory ${BRANCH_SYNC_DIST} ${DATE_SYNC} env_sync_files
# 			if [ "x$?" == "x0" ]; then
# 				echo "补丁打入成功！"
# 			else
# 				echo "补丁打入失败！"
# 				exit 6
# 			fi
# 			set -e
# 		fi
# 
# 		if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/step.diff ]; then
# 			set +e
# 			patch_to_directory ${BRANCH_SYNC_DIST} ${DATE_SYNC} step.diff
# 			if [ "x$?" == "x0" ]; then
# 				echo "补丁打入成功！"
# 			else
# 				echo "补丁打入失败！"
# 				exit 6
# 			fi
# 			set -e
# 		fi
		if [ "x${PATCH_ERROR}" == "x0" ]; then
			echo "补丁验证成功，进行实际的应用过程..."
			for sync_i in sync_files env_sync_files step.diff
			do
				if [ -f ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/${sync_i} ]; then
					set +e
# 					echo "patch_to_directory \"${BRANCH_SYNC_DIST}\" \"${DATE_SYNC}\" \"${sync_i}\" \"1\""
					patch_to_directory "${BRANCH_SYNC_DIST}" "${DATE_SYNC}" "${sync_i}" "1"
					if [ "x$?" != "x0" ]; then
						echo "补丁应用失败，无法继续！"
						exit 6
						break;
					fi
					set -e
				fi
			done
			cp -af ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/diff_message ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/diff_message
			echo "${DIFF_STAMP}" > ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/diff_stamp
			echo "${DATE_SYNC}" >> ${BRANCH_SYNC_DIST}./sync/branch_stamp
			echo "从 ${BRANCH_SYNC_DIST}./sync_diff/${DATE_SYNC}/ 应用补丁成功！"
		else
			echo "补丁验证失败，无法继续！"
			exit 6
		fi
	fi
else
	# 反打补丁
	DATE_SYNC=""
	if [ -f ${BRANCH_SYNC_DIST}./sync/branch_stamp ]; then
		DATE_SYNC=$(cat ${BRANCH_SYNC_DIST}./sync/branch_stamp | grep -v "^#" | tail -n1)
	fi
	if [ "x${DATE_SYNC}" != "x" ]; then
		if [ ! -d ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/ ]; then
			echo "没有找到差异目录 ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/ ，已经没有可用于回复补丁的文件！"
		        exit 4
		fi
		echo "更新分支：${BRANCH_SYNC_ABS_DIST} (${BRANCH_SYNC_DIST}) ，差异目录 ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/"

		UNPATCH_ERROR=0
		for sync_i in sync_files env_sync_files step.diff
		do
			if [ -f ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/${sync_i} ]; then
				set +e
				unpatch_to_directory ${BRANCH_SYNC_DIST} ${DATE_SYNC} ${sync_i} 0
				if [ "x$?" != "x0" ]; then
					UNPATCH_ERROR=1
					break;
				fi
				set -e
			fi
		done


# 		if [ -f ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/sync_files ]; then
# 			set +e
# 			unpatch_to_directory ${BRANCH_SYNC_DIST} ${DATE_SYNC} sync_files
# 			if [ "x$?" == "x0" ]; then
# 				echo "反补丁成功！"
# 			else
# 				echo "反补丁失败！"
# 				exit 6
# 			fi
# 			set -e
# 		fi
# 
# 		if [ -f ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/env_sync_files ]; then
# 			set +e
# 			unpatch_to_directory ${BRANCH_SYNC_DIST} ${DATE_SYNC} env_sync_files
# 			if [ "x$?" == "x0" ]; then
# 				echo "反补丁成功！"
# 			else
# 				echo "反补丁失败！"
# 				exit 6
# 			fi
# 			set -e
# 		fi
# 
# 		if [ -f ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/step.diff ]; then
# 			set +e
# 			unpatch_to_directory ${BRANCH_SYNC_DIST} ${DATE_SYNC} step.diff
# 			if [ "x$?" == "x0" ]; then
# 				echo "反补丁成功！"
# 			else
# 				echo "反补丁失败！"
# 				exit 6
# 			fi
# 			set -e
# 		fi

		if [ "x${UNPATCH_ERROR}" == "x0" ]; then
			echo "反打补丁验证成功，进行实际的反打补丁过程..."
			for sync_i in sync_files env_sync_files step.diff
			do
				if [ -f ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/${sync_i} ]; then
					set +e
					unpatch_to_directory ${BRANCH_SYNC_DIST} ${DATE_SYNC} ${sync_i} 1
					if [ "x$?" != "x0" ]; then
						echo "反打补丁失败，无法继续！"
						exit 6
						break;
					fi
					set -e
				fi
			done
			sed -i '$d' ${BRANCH_SYNC_DIST}./sync/branch_stamp
			echo "${DATE_SYNC}" >> ${BRANCH_SYNC_DIST}./sync/unpatch_stamp
			echo "通过 ${BRANCH_SYNC_DIST}./sync/${DATE_SYNC}/ 反打补丁成功！"
		else
			echo "反打补丁验证失败，无法继续！"
			exit 6
		fi


	fi
fi


exit 0
