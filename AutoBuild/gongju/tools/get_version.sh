#!/bin/bash
export NEW_TARGET_SYSDIR="${PWD}/workbase"
export BASE_DIR="${PWD}"
export STEP_NAME=""
export PACKAGE_NAME=""
export PACKAGE_INFO=""

if [ "x${1}" == "x" ]; then
	# 没有指定步骤名称!
	echo NULL
        exit 1
fi
STEP_NAME="${1}"

if [ "x${2}" == "x" ]; then
	# 没有指定步骤中的软件包名。
	echo NULL
        exit 2
fi
PACKAGE_NAME="${2}"

if [ ! -f ${BASE_DIR}/scripts/step/${STEP_NAME}/${PACKAGE_NAME}.info ]; then
	echo NULL
	exit 3
fi

PACKAGE_INFO=$(cat ${BASE_DIR}/scripts/step/${STEP_NAME}/${PACKAGE_NAME}.info)

PACKAGE_VERSION=$(echo "${PACKAGE_INFO}" | awk -F'|' '{ print $2 }')

echo ${PACKAGE_VERSION}

