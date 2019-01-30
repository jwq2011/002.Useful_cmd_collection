
if [[ $_ != $0 ]]; then
    SUBSHELL_RUN=no
else
    SUBSHELL_RUN=yes
fi

ANDROID_PATH=$(pwd)
UBOOT_PATH=${ANDROID_PATH}/bootable/bootloader/u-boot
UBOOT_OUT_PATH=${UBOOT_PATH}
UBOOT_CONFIGS_PATH=${UBOOT_PATH}/configs/
UBOOT_PROJECT_CONFIG_PATH=${UBOOT_OUT_PATH}/include/configs

KERNEL_DIR=${ANDROID_PATH}/kernel
KERNEL_DTS_DIR=${KERNEL_DIR}/arch/arm/boot/dts/tcc
KERNEL_CONFIGS_DIR=${KERNEL_DIR}/arch/arm/configs

OPTION_PROJECT=$(cat ${ANDROID_PATH}/device/telechips/car_tcc803x/vendorsetup.sh | grep add_lunch_combo |cut -c 17-)
SD_BURN_OPTION_PROJECT=$(cat ${ANDROID_PATH}/device/telechips/car_tcc803x/vendorsetup.sh | grep add_lunch_combo |cut -c 17- |cut -d - -f 1)

CPU_COUNT=$(grep process /proc/cpuinfo | wc -l)

build_android() {
    if [ "$SUBSHELL_RUN" = "yes" ]; then
        set -e
    fi

	if [ -f ${ANDROID_PATH}/device/fsl/${TARGET_PRODUCT}/vendor/vendor_copy.sh ]; then
		${ANDROID_PATH}/device/fsl/${TARGET_PRODUCT}/vendor/vendor_copy.sh
	fi

    echo -e "\n\nBuild android start...\n\n"
    cd ${ANDROID_PATH}

    source build/envsetup.sh
    lunch ${TELECHIPS_TARGET_PRODUCT_COMBO}

    make -j$CPU_COUNT 2>&1 | tee Build_Android_Log.txt
    if [ ${PIPESTATUS[0]} -ne 0 ] ; then
        echo -e "\n\n\033[0;31;5m Build android failed!!\033[0m\n\n"
        return 1
    fi
    last_version=`cat ${ANDROID_PATH}/out/target/product/${TARGET_PRODUCT}/system/build.prop |grep "ro.build.display.id" | tail -n 1 | cut -d "=" -f2- | awk '{print $1}'`

    echo -e "$last_version"
    echo $last_version > last_successful_version.txt

    echo -e "\n\033[0;32;1m  Build android successfully\033[0m\n"
}

clean_android() {
    echo -e "\n\nClean android start...\n\n"

    cd ${ANDROID_PATH}
    make clean
}

make_otapackage() {
    if [ "$SUBSHELL_RUN" = "yes" ]; then
        set -e
    fi

    echo -e "\n\nMake ota_package start...\n\n"

    cd ${ANDROID_PATH}

    source build/envsetup.sh
    lunch ${TELECHIPS_TARGET_PRODUCT_COMBO}
    if [ $? -ne 0 ] ; then
        echo -e "\n\n\033[0;31;5m Build android failed!!\033[0m\n\n"
        return 1
    fi
    make PRODUCT=${TELECHIPS_TARGET_PRODUCT_COMBO} otapackage -j$CPU_COUNT 2>&1 | tee Build_Otapackage_Log.txt
}

build_uboot() {
    if [ "$SUBSHELL_RUN" = "yes" ]; then
	    set -e
    fi

	echo -e "\n\nBuild u-boot start...\n\n"
	cd ${UBOOT_PATH}
	make distclean
	if [ -f ${UBOOT_PATH}/configs/${TELECHIPS_TARGET_PRODUCT}_defconfig ];then
		make ${TELECHIPS_TARGET_PRODUCT}_config
	else
		make tcc803x_aarch32_defconfig;
	fi
	
	make -j$CPU_COUNT 2>&1 | tee Build_Uboot_Log.txt
	if [ $? -ne 0 ] ; then
		echo -e "\n\n\033[0;31;5m Build uboot failed!!\033[0m\n\n"
        return 1
	fi

    if [ ! -e ${TELECHIPS_ANDROID_OUT_DIR} ]; then
        mkdir -p ${TELECHIPS_ANDROID_OUT_DIR}
    fi

	cp -rf ${UBOOT_OUT_PATH}/*.rom ${TELECHIPS_ANDROID_OUT_DIR}/

	echo -e "\n\033[0;32;1m Build u-boot successfully\033[0m\n"
}
clean_uboot() {
    echo -e "\n\nClean u-boot start...\n\n"

    cd ${UBOOT_PATH}
    make distclean
	rm ${TELECHIPS_ANDROID_OUT_DIR}/*.rom
}

build_kernel() {
    if [ "$SUBSHELL_RUN" = "yes" ]; then
        set -e
    fi

    echo -e "\n\nBuild kernel start...\n\n"

    export PATH=${UBOOT_PATH}/tools:$PATH

    cd ${KERNEL_DIR}
    echo $ARCH && echo $CROSS_COMPILE &&echo $PATH

    if [ "${TELECHIPS_TARGET_PRODUCT}" == "car_tcc803x" ];then
        make tcc803x_android_avn_defconfig
    else
        make ${TELECHIPS_TARGET_PRODUCT}_defconfig
    fi

    make -j40 2>&1 | tee BUILD_Kernel_LOG.txt
	if [ $? -ne 0 ] ; then
		echo -e "\n\n\033[0;31;5m Make kernel failed!!\033[0m\n\n"
        return 1
	fi

    if [ "${TELECHIPS_TARGET_PRODUCT}" == "car_tcc803x" ];then
		cp ${KERNEL_DTS_DIR}/tcc8030-android-lpd4321_sv0.1.dtb ${TELECHIPS_ANDROID_OUT_DIR}/
		cp ${KERNEL_DTS_DIR}/tcc8030-android-lpd4321_sv0.1.dtb ${TELECHIPS_ANDROID_OUT_DIR}/dtb.img
	fi

    echo -e "\n\033[0;32;1m Make kernel successfully\033[0m\n"
}

distclean_kernel() {
    echo "distclean_kernel"
	rm ${TELECHIPS_ANDROID_OUT_DIR}/tcc8030-android-lpd4321_sv0.1.dtb
	rm ${TELECHIPS_ANDROID_OUT_DIR}/*.dtb
    cd ${ANDROID_PATH}/kernel
    make distclean
}

build_vendor_image() {
    if [ "$SUBSHELL_RUN" = "yes" ]; then
        set -e
    fi

    echo -e "\n\nBuild vendor.img start...\n\n"
	cd ${ANDROID_PATH}

	make vendorimage -j$CPU_COUNT
	if [ $? -ne 0 ] ; then
		echo -e "\n\n\033[0;31;5m Make vendor image failed!!\033[0m\n\n"
        return 1
	fi

	echo -e "\n\033[0;32;1m Make vendor image successfully\033[0m\n"
}

build_all() {
    build_uboot
    if [ $? -ne 0 ] ; then
        return 1
    fi

    build_kernel
    if [ $? -ne 0 ] ; then
        return 1
    fi

    build_android
    if [ $? -ne 0 ] ; then
        return 1
    fi
    #make_otapackage
}

clean_all() {
    clean_uboot
    distclean_kernel
    clean_android
}

setup_env() {
	if [ -z $1 ];then
        if [ "$TELECHIPS_TARGET_PRODUCT_COMBO" = "" ]; then
		    export TELECHIPS_TARGET_PRODUCT_COMBO=sabresd_6dq-user
        fi
	else
        local PRJNUM=`echo "$OPTION_PROJECT" | grep -c $1`
        local PRJS=`echo "$OPTION_PROJECT" | grep $1`
        if [ $PRJNUM == 1 ]; then
            export TELECHIPS_TARGET_PRODUCT_COMBO=$PRJS
        elif [ $PRJNUM -gt 1 ]; then
			echo -e "\033[0;31;1m ######Error: $1 match multi projects: ###### \033[0m"
            echo -e "\033[0;31;1m$PRJS \033[0m"
            return 1
        else
			echo -e "\033[0;31;1m ######Error: $1 is not a valid project ###### \033[0m"
            usage
            return 1
        fi
	fi

	export TELECHIPS_TARGET_PRODUCT=$(echo ${TELECHIPS_TARGET_PRODUCT_COMBO} | cut -d- -f1)
	export TELECHIPS_ANDROID_OUT_DIR=${ANDROID_PATH}/out/target/product/${TELECHIPS_TARGET_PRODUCT}
	export ARCH=arm
#	export CROSS_COMPILE=${ANDROID_PATH}/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-
	export CROSS_COMPILE=arm-linux-androideabi-

	cd ${ANDROID_PATH}

	source build/envsetup.sh
	lunch ${TELECHIPS_TARGET_PRODUCT_COMBO}
	export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:[$TARGET_PRODUCT \[\033[01;34m\]\w\[\033[00m\]]$ '
}

rm_boot_recovery_img() {
    rm -f ${TELECHIPS_ANDROID_OUT_DIR}/boot.img
    rm -f ${TELECHIPS_ANDROID_OUT_DIR}/recovery.img
}

usage() {
    echo "
    Usage:
    source build.sh [prj] [cmd] ---- setup building enviroment, use sabresd_6dq-eng as default if no prj input
    build.sh [prj] [cmd]        ---- run build [cmd] in subshell, not change terminal enviroment
    例如sabresd_6dq项目： source build.sh env car_tcc803x-eng"
    echo -e "\n\033[0;31;5m    可选项目参数:\033[0m \033[0;32;1m "$OPTION_PROJECT" \033[0m"
#    echo -e "\033[0;32;1m "$OPTION_PROJECT" \033[0m\n"
	echo "
    $0 uboot                ---- build uboot image
    $0 clean-uboot          ---- clean uboot
    $0 kernel               ---- build kernel image
    $0 distclean-kernel     ---- distclean kernel
    $0 android              ---- build android image
    $0 clean-android        ---- clean android
    $0 clean-uboot-kernel   ---- clean u-boot & kernel
    $0 update               ---- make ota update image
    $0 pack                 ---- pack android image
    $0 bootsd               ---- make booting which booting from sdcard(not emmc)
    $0 recoverysd           ---- make recovery.img which booting from sdcard(not emmc)
    $0 rm_boot              ---- delete boot.img which is at android output directory
    $0 all                  ---- make all
	"
}


if [ "$1" = "env" ]; then
     shift
fi

if [ $# -lt 1 ]; then
    usage
elif [ "$TELECHIPS_TARGET_PRODUCT" = "" ] || [ `echo "$OPTION_PROJECT" | grep -c $1` -ge 1 ]; then
    if [ `echo "$SD_BURN_OPTION_PROJECT" | grep -c $1` -ne 1 ]; then
	setup_env $1
        shift
    fi
fi

if [ $# -ge 1 ]; then
    while [ $# -ne 0 ]; do
        case $1 in
            uboot)
                build_uboot
                ;;
            uboot_dl)
                build_uboot_dl
                ;;
            clean-uboot)
                clean_uboot
                ;;
            kernel)
                build_kernel
                ;;
            bootimg)
                build_boot_image
                ;;
            debug-bootimg)
                build_debug_bootimage
                ;;
            distclean-kernel)
                distclean_kernel
                ;;
            vendor)
                build_vendor_image
                ;;
            android)
                build_android
                ;;
            clean-android)
                clean_android
                ;;
            update)
                make_otapackage
                ;;
            bootsd)
                build_boot_image_sd
                ;;
            recoverysd)
                build_recovery_image_sd
                ;;
            rm_boot)
                rm_boot_recovery_img
                ;;
            checkout)
                checkout_diff
                ;;
            all)
                build_all
                ;;
            clean-uboot-kernel)
                clean_uboot
                distclean_kernel
                ;;
            clean-all)
                clean_all
                ;;
            help)
                usage
                ;;
            *)
                echo -e "\n\nwrong target cmd: $1,pls check! �?⊙ω⊙�?"
                usage
                if [ "$SUBSHELL_RUN" = "yes" ]; then
                    exit 1
                else
                    return 1
                fi
                ;;
        esac
        shift
    done
fi



