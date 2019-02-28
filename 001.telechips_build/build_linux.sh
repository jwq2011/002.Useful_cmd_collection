#########################################################################
# File Name: build_linux.sh
# Author: jiaweiqing
# mail: ssi-jiawq@dfmc.com.cn
# Created Time: Wed 13 Feb 2019 11:20:49 AM CST
#########################################################################
#!/bin/sh

cur_path=`pwd`
SUPPORT_MACHINES="tcc8030 tcc8031 tcca7s"

machine_selected()
{
	echo "machine($machine) selected."
	if [ -f poky/oe-init-build-env ]; then
		mkdir -p build
		if [ -n $machine ]; then
			export MACHINE="$machine"
			source poky/oe-init-build-env build/$machine
			sed -i "s%^#\(MACHINE ??=.*$machine\".*\)%\1%g" conf/local.conf
		fi
	fi
}

graphic_backend_selected()
{
	# Set Graphics Backend System
	echo "graphic backend($graphic_backend) selected."
	if [ -n $graphic_backend ]; then
		if [ $graphic_backend == "fb" ]; then
			sed -i 's%^#\(INVITE_PLATFORM += "qt5\/eglfs"\)%\1%g' conf/local.conf
		else
			sed -i 's%^#\(INVITE_PLATFORM += "qt5\/wayland"\)%\1%g' conf/local.conf
			sed -i 's%^#\(INVITE_PLATFORM += "drm"\)%\1%g' conf/local.conf
			sed -i 's%^#\(DISTRO_FEATURES_append = " wayland"*\)%\1%g' conf/local.conf
		fi
	fi
}

set_machine_env()
{
	if [ -z $machine ]; then
		echo "Could not continue build. You have to select machine"
	else
		if [ $machine == "tcca7s" ]; then
			# echo "machine($machine) selected."
			machine_selected
		else
			echo -e "Choose Graphical Backend - \e[1;33;40m(Wayland is default)\e[0m"
			num=1
			for graphic_backend in $SUPPORT_GRAPHIC_BACKEND; do
				echo "  $num. $graphic_backend"
				versions[$num]=$graphic_backend
				num=$(($num + 1))
			done
			total=$num
			num=$(($num - 1))
			echo -n "select number(1-$num) => "
			read sel

			if [ -z $sel ]; then
				graphic_backend=""
			elif [ $sel -gt "0" -a $sel -lt "$total" ]; then
				graphic_backend=${versions[$sel]}
			else
				graphic_backend=""
			fi

			if [ -z $graphic_backend ]; then
				echo "Could not continue build. You have to select graphic backend"
			else
				machine_selected
				graphic_backend_selected
			fi
		fi
	fi
}

set_linux_env()
{
	echo "Choose MACHINE"
	num=1
	for machine in $SUPPORT_MACHINES; do
		echo "  $num. $machine"
		machines[$num]=$machine
		num=$(($num + 1))
	done
	total=$num
	num=$(($num - 1))
	echo -n "select number(1-$num) => "
	read sel

	if [ -z $sel ]; then
		machine=""
	else
		if [ $sel != "0" -a $sel -lt "$total" ];then
			machine=${machines[$sel]}
		else
			machine=""
		fi
	fi

	if [$machine == "tcca7s" ]; then
		export TEMPLATECONF=$cur_path/poky/meta-telechips/meta-subcore/template
	else
		export TEMPLATECONF=$cur_path/poky/meta-telechips/template
		SUPPORT_GRAPHIC_BACKEND="wayland fb"	
	fi

	set_machine_env
}

set_linux_env
