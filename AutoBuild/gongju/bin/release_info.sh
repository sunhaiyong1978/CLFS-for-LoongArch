#!/bin/bash -e

export BASE_DIR="${PWD}"

declare RELEASE_BUILD_MODE=0
declare NEW_BASE_DIR="${PWD}"

declare UPDATE_MODE=FALSE
declare DISTRO_LABEL=""

declare WORLD_PARM=""

while getopts 'wh' OPT; do
    case $OPT in
	w)
	    NEW_TARGET_SYSDIR="${BASE_DIR}/workbase"
	    NEW_BASE_DIR="${BASE_DIR}"
	    RELEASE_BUILD_MODE=0
	    WORLD_PARM="-w"
	    echo "强制指定使用主线环境中进行构建。"
	    ;;
        ?|h)
            echo "用法: `basename $0` [选项]"
            echo "选项："
            echo "    -h: 显示当前帮助信息。"
	    echo "    -w: 强制在主线环境中进行信息收集，不指定该参数将使用 current_branch 指定的分支环境中进行信息收集，若不存在 current_branch 文件则默认对主线环境进行信息收集。"
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
			echo "发现 current_branch 指定的 Branch_${RELEASE_VERSION} 目录，将在指定目录中进行信息收集。"
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


if [ -f ${NEW_BASE_DIR}/workbase/logs/release_show.txt ]; then
	mv ${NEW_BASE_DIR}/workbase/logs/release_show.txt{,.$(date +%Y%m%d%H%M%S)}
fi
touch ${NEW_BASE_DIR}/workbase/logs/release_show.txt
if [ -f ${NEW_BASE_DIR}/workbase/logs/update_release_show.txt ]; then
	mv ${NEW_BASE_DIR}/workbase/logs/update_release_show.txt{,.$(date +%Y%m%d%H%M%S)}
fi
touch ${NEW_BASE_DIR}/workbase/logs/update_release_show.txt

if [ -f ${NEW_BASE_DIR}/workbase/logs/release_info.txt ]; then
	mv ${NEW_BASE_DIR}/workbase/logs/release_info.txt{,.$(date +%Y%m%d%H%M%S)}
	if [ -f ${NEW_BASE_DIR}/workbase/logs/release_info.temp ]; then
		rm ${NEW_BASE_DIR}/workbase/logs/release_info.temp
		touch ${NEW_BASE_DIR}/workbase/logs/release_info.temp
	else
		touch ${NEW_BASE_DIR}/workbase/logs/release_info.temp
	fi
fi
if [ -f ${NEW_BASE_DIR}/workbase/logs/update_release_info.txt ]; then
	mv ${NEW_BASE_DIR}/workbase/logs/update_release_info.txt{,.$(date +%Y%m%d%H%M%S)}
	if [ -f ${NEW_BASE_DIR}/workbase/logs/update_release_info.temp ]; then
		rm ${NEW_BASE_DIR}/workbase/logs/update_release_info.temp
		touch ${NEW_BASE_DIR}/workbase/logs/update_release_info.temp
	else
		touch ${NEW_BASE_DIR}/workbase/logs/update_release_info.temp
	fi
fi

if [ -f ${NEW_BASE_DIR}/workbase/logs/release_summary.txt ]; then
	mv ${NEW_BASE_DIR}/workbase/logs/release_summary.txt{,.$(date +%Y%m%d%H%M%S)}
fi
if [ -f ${NEW_BASE_DIR}/workbase/logs/update_release_summary.txt ]; then
	mv ${NEW_BASE_DIR}/workbase/logs/update_release_summary.txt{,.$(date +%Y%m%d%H%M%S)}
fi

# for i in $(cat ${NEW_BASE_DIR}/env/*/overlay.set | grep overlay_dir | awk -F'=' '{ print $2 }' | sort | uniq)
for i in $(cat ${NEW_BASE_DIR}/info_set/release_sort)
do
	echo "统计 $i 目录内的软件版本信息..."
	if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/$i ]; then
		echo "${i} 组中包含了以下软件包：" >> ${NEW_BASE_DIR}/workbase/logs/release_info.txt
		for pkg_info in $(ls ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}/var/Yongbao/status/* )
		do
			if [ -f ${pkg_info} ]; then
				if [ "x$(grep "^${i}/${pkg_info##*/}" ${NEW_BASE_DIR}/info_set/release_hide)" == "x" ] && [ "x$(grep "^${pkg_info##*/}$" ${NEW_BASE_DIR}/info_set/release_hide)" == "x" ]; then
					if [ "x$(cat ${NEW_BASE_DIR}/info_set/release_summary | grep "^${pkg_info##*/}=")" != "x" ] && [ "x$(cat ${NEW_BASE_DIR}/workbase/logs/release_info.temp | grep "^${pkg_info##*/}-$(cat ${pkg_info})$")" == "x" ]; then
						echo "找到一个提要${pkg_info##*/}。"
						echo "${pkg_info##*/}-$(cat ${pkg_info})" >> ${NEW_BASE_DIR}/workbase/logs/release_info.temp
						echo "${pkg_info##*/}=$(cat ${NEW_BASE_DIR}/info_set/release_summary | grep "^${pkg_info##*/}=" | awk -F'=' '{ print $2 }' | sed "s@<<<VERSION>>>@$(cat ${pkg_info})@g")" >> ${NEW_BASE_DIR}/workbase/logs/release_show.txt
					fi
					echo "	${pkg_info##*/} $(cat ${pkg_info})" >> ${NEW_BASE_DIR}/workbase/logs/release_info.txt
				fi
			fi
		done
		echo "" >> ${NEW_BASE_DIR}/workbase/logs/release_info.txt
	else
		echo "${NEW_BASE_DIR}/workbase/overlaydir 中没有发现 $i 目录，跳过。"
	fi

	if [ -d ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}.update ]; then
		echo "统计 ${i}.update 目录内的软件版本信息..."
		echo "${i} 组中更新或增加了以下软件包：" >> ${NEW_BASE_DIR}/workbase/logs/update_release_info.txt
		for pkg_info in $(ls ${NEW_BASE_DIR}/workbase/overlaydir_strip/${i}.update/var/Yongbao/status/* )
		do
			if [ -f ${pkg_info} ]; then
				if [ "x$(grep "^${i}/${pkg_info##*/}" ${NEW_BASE_DIR}/info_set/release_hide)" == "x" ] && [ "x$(grep "^${pkg_info##*/}$" ${NEW_BASE_DIR}/info_set/release_hide)" == "x" ]; then
					if [ "x$(cat ${NEW_BASE_DIR}/info_set/release_summary | grep "^${pkg_info##*/}=")" != "x" ] && [ "x$(cat ${NEW_BASE_DIR}/workbase/logs/update_release_info.temp | grep "^${pkg_info##*/}-$(cat ${pkg_info})$")" == "x" ]; then
						echo "找到一个提要${pkg_info##*/}。"
						echo "${pkg_info##*/}-$(cat ${pkg_info})" >> ${NEW_BASE_DIR}/workbase/logs/update_release_info.temp
						echo "${pkg_info##*/}=$(cat ${NEW_BASE_DIR}/info_set/release_summary | grep "^${pkg_info##*/}=" | awk -F'=' '{ print $2 }' | sed "s@<<<VERSION>>>@$(cat ${pkg_info})@g")" >> ${NEW_BASE_DIR}/workbase/logs/update_release_show.txt
					fi
					echo "	${pkg_info##*/} $(cat ${pkg_info})" >> ${NEW_BASE_DIR}/workbase/logs/update_release_info.txt
				fi
			fi
		done
		echo "" >> ${NEW_BASE_DIR}/workbase/logs/update_release_info.txt
	fi

done

for i in $(cat ${NEW_BASE_DIR}/info_set/release_summary | grep -v "^#" | awk -F'=' '{ print $1 }')
do
	if [ "x$(cat ${NEW_BASE_DIR}/workbase/logs/release_show.txt | grep "^${i##*/}=")" != "x" ]; then
		echo "* $(cat ${NEW_BASE_DIR}/workbase/logs/release_show.txt | grep "^${i##*/}=" | awk -F'=' '{ print $2 }')" >> ${NEW_BASE_DIR}/workbase/logs/release_summary.txt
	fi
	if [ "x$(cat ${NEW_BASE_DIR}/workbase/logs/update_release_show.txt | grep "^${i##*/}=")" != "x" ]; then
		echo "* $(cat ${NEW_BASE_DIR}/workbase/logs/update_release_show.txt | grep "^${i##*/}=" | awk -F'=' '{ print $2 }')" >> ${NEW_BASE_DIR}/workbase/logs/update_release_summary.txt
	fi
done
