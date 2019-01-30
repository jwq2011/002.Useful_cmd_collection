#########################################################################
# File Name: build_hyper.sh
# Author: jiawq
# Created Time: Wed 30 Jan 2019 08:38:58 AM CST
#########################################################################
#!/bin/bash


export COQOS_LICENSE_FILE=/usr/share/ssi-env/WuhanSouthSagittariusIntegration__coqoshv_expires_20190331.lic

CPU_COUNT=$(grep process /proc/cpuinfo | wc -l)
BUILD_HOME_PATH=$(pwd)
HYPER_UBOOT_PATH=${BUILD_HOME_PATH}/../u-boot

red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`

set_toolchain_env()
{
	index=$1

	echo "${red}[1] Telechips Android Platform "
	echo "[2] Telechips Android Platform (64bit) "
	echo "[3] Telechips Linux Platform "
	echo "[4] Telechips Linux Platform (64bit)${reset} "
	#echo -n "${green}Select Target Platform : ${index} ${reset} "
	echo -n "${green}Select Target Platform : ${reset} "
	echo "${index}"

	if [ $index -eq 1 ]; then
		export CROSS_COMPILE=arm-linux-androideabi-
	elif [ $index -eq 2 ]; then
		export ARCH=arm64
		export CROSS_COMPILE=aarch64-linux-android-
	elif [ $index -eq 3 ]; then
		export ARCH=arm 
		export CROSS_COMPILE=arm-none-linux-gnueabi-
	elif [ $index -eq 4 ]; then
		export ARCH=arm64
		export CROSS_COMPILE=aarch64-linux-gnu-
	else
		export CROSS_COMPILE=
		echo "${red}Unknown Taget Platform !!${reset}"
	fi
}

make_hyper_uboot()
{
	cd ${HYPER_UBOOT_PATH}
	#set env
	set_toolchain_env 4
	make tcc803x_hyper_defconfig
	make -j$CPU_COUNT 2>&1 | tee LOG_make_hyper_uboot.txt

	if [ $? -ne 0 ] ; then
		echo -e "${red}Make Hyper uboot failed !!${reset}"
	return 1
	fi
	echo -e "${green}Make Hyper uboot successfully !!${reset}"
}

make_hyper_image()
{
	NETRC=~/.netrc
	if [ ! -f $NETRC ]; then
    		touch $NETRC
		make pkg-install
	fi

	cd ${BUILD_HOME_PATH}
	make configure -j$CPU_COUNT 2>&1 | tee LOG_make_configure.txt
	make all -j$CPU_COUNT 2>&1 | tee LOG_make_all.txt
	make install -j$CPU_COUNT 2>&1 | tee LOG_make_install.txt

	if [ $? -ne 0 ] ; then
		echo -e "${red}Make Hyper image failed !!${reset}"
	return 1
	fi
	echo -e "${green}Make Hyper image successfully !!${reset}"
}

make_hyper_uboot
make_hyper_image
