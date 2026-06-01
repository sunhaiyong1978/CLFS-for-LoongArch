#!/bin/bash

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"
declare WORLD_PARM=""

while getopts 'wh' OPT; do
    case $OPT in
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    ;;
        h|?)
            echo "目标系统运行准备处理脚本。"
            echo ""
            echo "用法: ./`basename $0` [选项] [步骤名称] [需要处理的目录]"
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
	    echo "    -w: 强制在主线环境中进行处理，不指定该参数将使用 current_branch 指定的分支环境中进行处理，若不存在 current_branch 文件则默认对主线环境进行处理。"
            exit 127
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
#			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行构建。"
		else
#			echo "没有发现 Branch_${RELEASE_VERSION} 目录。"
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


export FIX_STEP_NAME=""
export FINAL_FIX_DIR=""

if [ "x${1}" == "x" ]; then
	echo "没有指定步骤名称!"
	exit 1
fi
FIX_STEP_NAME="${1}"

if [ "x${2}" == "x" ]; then
	echo "没有指定需要处理的目录。"
	exit 2
fi
FINAL_FIX_DIR="${2}"

echo "处理 ${FINAL_FIX_DIR} 目录以符合在目标系统环境中运行..."
mkdir -p ${NEW_TARGET_SYSDIR}/logs/final_fix/
# echo "处理 ${FINAL_FIX_DIR} 目录以符合在目标系统环境中运行..." > ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${FIX_STEP_NAME}.log
# source ${NEW_BASE_DIR}/env/${FIX_STEP_NAME}/config

if [ -d ${FINAL_FIX_DIR} ]; then
# 	PACKAGE_STEP_NAME=""
	STEP_BUILDNAME=""
	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist ]; then
# 		PACKAGE_STEP_NAME=$(cat ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist)
		source ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist
	fi
# 	if [ "x${PACKAGE_STEP_NAME}" == "x" ]; then
# 		PACKAGE_STEP_NAME="target_base"
#	fi
	if [ "x${STEP_BUILDNAME}" == "x" ]; then
		STEP_BUILDNAME="target_base"
	fi


	echo -n "" > ${TEMP_DIRECTORY}/final_fix_all.txt
	echo -n "" > ${TEMP_DIRECTORY}/final_fix_custom.txt

	if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.final_fix ]; then
		echo "发现 ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.final_fix 文件，按照其中的设置对 ${FIX_STEP_NAME} 目录进行追加处理操作..."
		cat ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.final_fix | sort | uniq | while read line_fix
		do
			FINAL_FIX_SET_DIRECTORY=$(echo "${line_fix}" | awk -F'|' '{ print $1 }')
			if [ "x${FINAL_FIX_SET_DIRECTORY}" == "x" ]; then
				echo "没有设置处理目录。"
				exit 3
			fi
			if [ ! -d ${FINAL_FIX_DIR}/./${FINAL_FIX_SET_DIRECTORY} ]; then
				"警告：${FINAL_FIX_DIR}/./${FINAL_FIX_SET_DIRECTORY} 目录不存在, 跳过这条处理步骤，继续后面的步骤。"
				continue
			fi
			FINAL_FIX_SET_COMMAND_OPT=$(echo "${line_fix}" | awk -F'|' '{ print $2 }')
			FINAL_FIX_SET_FILES_TYPE=$(echo "${line_fix}" | awk -F'|' '{ print $3 }')
			FINAL_FIX_SET_COMMAND_DIST=$(echo "${line_fix}" | awk -F'|' '{ print $4 }')
			FINAL_FIX_SET_COMMAND_DIST_FIX=$(echo "${line_fix}" | awk -F'|' '{ print $5 }')
			pushd ${FINAL_FIX_DIR} > /dev/null
				case "${FINAL_FIX_SET_COMMAND_OPT}" in
					F)
						case "${FINAL_FIX_SET_FILES_TYPE}" in
							f)
								RUN_COMMAND="find ${PWD}/./${FINAL_FIX_SET_DIRECTORY} -type f -name '"${FINAL_FIX_SET_COMMAND_DIST}"' >> ${TEMP_DIRECTORY}/final_fix_all.txt"
								set -x
								eval "${RUN_COMMAND}"
								set +x
								;;
							g)
								RUN_COMMAND="file ${PWD}/./${FINAL_FIX_SET_DIRECTORY}/* | grep -e '"${FINAL_FIX_SET_COMMAND_DIST}"' | awk -F':' '{ print \$1 }' >> ${TEMP_DIRECTORY}/final_fix_all.txt"
								set -x
								eval "${RUN_COMMAND}"
								set +x
								;;
# 							c)
# 								RUN_COMMAND="file ${PWD}/./${FINAL_FIX_SET_DIRECTORY}/* | grep -e '"${FINAL_FIX_SET_COMMAND_DIST}"' | awk -F':' '{ print \"${FINAL_FIX_SET_COMMAND_DIST_FIX}|\" \$1 }' >> ${TEMP_DIRECTORY}/final_fix_custom.txt"
# 								set -x
# 								eval "${RUN_COMMAND}"
# 								set +x
# 								;;
							d)
								;;
							*)
# 								echo "追加修复操作码“${FINAL_FIX_SET_COMMAND_OPT}”对类型“${FINAL_FIX_SET_FILES_TYPE}”设置无法操作，请使用 f(文件) 、g(文件类型)、c(自定义修改)、d(目录) 及 l(链接)。"
								echo "追加修复操作码“${FINAL_FIX_SET_COMMAND_OPT}”对类型“${FINAL_FIX_SET_FILES_TYPE}”设置无法操作，请使用 f(文件) 、g(文件类型)、d(目录) 及 l(链接)。"
								;;
						esac
						;;
					S)
						case "${FINAL_FIX_SET_FILES_TYPE}" in
							f)
								RUN_COMMAND="find ${PWD}/./${FINAL_FIX_SET_DIRECTORY} -type f -name '"${FINAL_FIX_SET_COMMAND_DIST}"' -exec echo \"${FINAL_FIX_SET_COMMAND_DIST_FIX}|{}\" ';' >> ${TEMP_DIRECTORY}/final_fix_custom.txt"
								set -x
								eval "${RUN_COMMAND}"
								set +x
								;;
							g)
								RUN_COMMAND="file ${PWD}/./${FINAL_FIX_SET_DIRECTORY}/* | grep -e '"${FINAL_FIX_SET_COMMAND_DIST}"' | awk -F':' '{ print \"${FINAL_FIX_SET_COMMAND_DIST_FIX}|\" \$1 }' >> ${TEMP_DIRECTORY}/final_fix_custom.txt"
								set -x
								eval "${RUN_COMMAND}"
								set +x
								;;
							d)
								;;
							*)
								echo "追加修复操作码“${FINAL_FIX_SET_COMMAND_OPT}”对类型“${FINAL_FIX_SET_FILES_TYPE}”设置无法操作，请使用 f(文件) 、g(文件类型)、d(目录) 及 l(链接)。"
								;;
						esac
						;;

					D)
						case "${FINAL_FIX_SET_FILES_TYPE}" in
							f)
								RUN_COMMAND="find ${PWD}/./${FINAL_FIX_SET_DIRECTORY} -type f -name '"${FINAL_FIX_SET_COMMAND_DIST}"' -exec rm -v {} ';'"
								set -x
								eval "${RUN_COMMAND}"
								set +x
								;;
							d)
								;;
							*)
								echo "追加修复操作码“${FINAL_FIX_SET_COMMAND_OPT}”对类型“${FINAL_FIX_SET_FILES_TYPE}”设置无法操作，请使用 f(文件) 、d(目录) 及 l(链接)。"
								;;
						esac
						;;
					C)
						case "${FINAL_FIX_SET_FILES_TYPE}" in
							f)
								RUN_COMMAND="touch ${PWD}/./${FINAL_FIX_SET_DIRECTORY}/${FINAL_FIX_SET_COMMAND_DIST}"
								set -x
								eval "${RUN_COMMAND}"
								set +x
								;;
							d)
								RUN_COMMAND="mkdir -p ${PWD}/./${FINAL_FIX_SET_DIRECTORY}/${FINAL_FIX_SET_COMMAND_DIST}"
								set -x
								eval "${RUN_COMMAND}"
								set +x
								;;
							l)
								RUN_COMMAND="ln -sfv ${FINAL_FIX_SET_COMMAND_DIST} ${PWD}/./${FINAL_FIX_SET_DIRECTORY}"
								set -x
								eval "${RUN_COMMAND}"
								set +x
								;;
							*)
								echo "追加修复操作码“${FINAL_FIX_SET_COMMAND_OPT}”对类型“${FINAL_FIX_SET_FILES_TYPE}”设置无法操作，请使用 f(文件) 、d(目录) 及 l(链接)。"
								;;
						esac
						;;
# 					0)
# 						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中及其之下所有目录中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。" >> ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${FIX_STEP_NAME}.log
# 						echo "将对 ${PWD}/./${STRIP_SET_DIRECTORY} 中及其之下所有目录中的 ${STRIP_SET_FILES} 文件使用 ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} 进行处理。"
# 						RUN_COMMAND="find ${PWD}/./${STRIP_SET_DIRECTORY} -type f -name '"${STRIP_SET_FILES}"' -exec ${STRIP_SET_COMMAND} ${STRIP_SET_COMMAND_PARM} {} 2>> ${NEW_TARGET_SYSDIR}/logs/final_fix/final_fix_${FIX_STEP_NAME}.log ';'"
# 						set -x
# 						eval "${RUN_COMMAND}"
# 						set +x
# 						;;
					*)
						echo "追加修复操作码“${FINAL_FIX_SET_COMMAND_OPT}”设置无法识别，请使用 F(表示修复路径) 、D(删除) 及 C(创建)。"
						;;
				esac
				RUN_COMMAND=""
			popd > /dev/null
		done
	fi


	pushd ${FINAL_FIX_DIR} > /dev/null
		set -x
		source ${NEW_BASE_DIR}/env/${STEP_BUILDNAME}/config
		if [ -f ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist ]; then
			source ${NEW_TARGET_SYSDIR}/overlaydir/${FIX_STEP_NAME}.dist
		fi
		echo "执行默认的处理操作..."
# 		echo -n "" > ${TEMP_DIRECTORY}/final_fix_all.txt
		touch ${TEMP_DIRECTORY}/final_fix-foo
# 		file usr/{bin,sbin,libexec}/* | grep "text executable" | awk -F':' '{ print $1 }' >> ${TEMP_DIRECTORY}/final_fix_all.txt
		file usr/{bin,sbin,libexec}/* | grep -e "ASCII text" -e "text executable" | awk -F':' '{ print $1 }' >> ${TEMP_DIRECTORY}/final_fix_all.txt
		find usr -type f -name "*.pc" \
                        -o -type f -name "*.cmake" \
                        -o -type f -name "Makefile*" \
                        -o -type f -name "*.service" \
                        -o -type f -name "*.pri" \
                        -o -type f -name "*.pl" \
                        -o -type f -name "*.desktop" \
                        -o -type f -name "*.py" >> ${TEMP_DIRECTORY}/final_fix_all.txt
		find usr -type f -name "*.sh" \
                        -o -type f -name "*.json" >> ${TEMP_DIRECTORY}/final_fix_all.txt
		echo "${TEMP_DIRECTORY}/final_fix-foo" >> ${TEMP_DIRECTORY}/final_fix_all.txt
		sed -i \
			-e "s@bin/${CROSS_TARGET}-@bin/@g" \
			-e "s@${CROSSTOOLS_DIR}/bin@/usr/bin@g" \
			-e "s@${CROSSTOOLS_DIR}/qt6@/usr/lib64/qt6@g" \
			-e "s@${HOST_TOOLS_DIR}/bin@/usr/bin@g" \
			-e "s@${SYSROOT_DIR}/lib@/usr/lib@g" \
			-e "s@${SYSROOT_DIR}/usr@/usr@g" \
			-e "s@${SYSROOT_DIR}@@g" \
			$(cat ${TEMP_DIRECTORY}/final_fix_all.txt)

		echo "执行自定义的替换操作..."
		cat ${TEMP_DIRECTORY}/final_fix_custom.txt | grep -v "^#" | while read custom_line
		do
			CUSTOM_REPLACE_STR=$(echo "${custom_line}" | awk -F'|' '{ print $1 }')
			CUSTOM_REPLACE_FILE=$(echo "${custom_line}" | awk -F'|' '{ print $2 }')
			CUSTOM_REPLACE_STR_SOURCE=$(echo "${CUSTOM_REPLACE_STR}" | awk -F'>>>' '{ print $1 }')
			CUSTOM_REPLACE_STR_DEST=$(echo "${CUSTOM_REPLACE_STR}" | awk -F'>>>' '{ print $2 }')
			if [ -f ${CUSTOM_REPLACE_FILE} ]; then
				if [ "x${CUSTOM_REPLACE_STR_SOURCE}" != "x" ]; then
					sed -i "s@${CUSTOM_REPLACE_STR_SOURCE}@${CUSTOM_REPLACE_STR_DEST}@g" ${CUSTOM_REPLACE_FILE}
				else
					echo "被替换字符不允许是空字串！"
				fi
			else
				echo "找不到 ${CUSTOM_REPLACE_FILE} 文件"
			fi
		done


# 		touch ${TEMP_DIRECTORY}/strip-foo
# 		sed -i \
# 			-e "s@bin/${CROSS_TARGET}-@bin/@g" \
# 			-e "s@${CROSSTOOLS_DIR}/bin@/usr/bin@g" \
# 			-e "s@${HOST_TOOLS_DIR}/bin@/usr/bin@g" \
# 			-e "s@${SYSROOT_DIR}/lib@/usr/lib@g" \
# 			-e "s@${SYSROOT_DIR}/usr@/usr@g" \
# 			-e "s@${SYSROOT_DIR}@@g" \
# 			$(file usr/{bin,sbin,libexec}/* | grep "text executable" | awk -F':' '{ print $1 }') \
# 			$(find usr -type f -name "*.pc" \
# 			-o -type f -name "*.cmake" \
# 			-o -type f -name "Makefile*" \
# 			-o -type f -name "*.service" \
# 			-o -type f -name "*.pri" \
# 			-o -type f -name "*.pl" \
# 			-o -type f -name "*.desktop" \
# 			-o -type f -name "*.py" \
# 			) \
# 			${TEMP_DIRECTORY}/strip-foo
		set +x
	popd > /dev/null

else
	echo "没有找到 ${FINAL_FIX_DIR} 目录，请检查是否指定了正确的路径。"
fi
