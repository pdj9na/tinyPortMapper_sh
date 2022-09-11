#!/bin/sh

# 安装依赖
opkg update >/dev/null
! type bash >/dev/null 2>&1 && opkg install bash

DIR=$(readlink -f $0)
DIR=${DIR%/*}

MAINEXEC=$DIR/tinymapper.sh

SRVNAME=tinymapper
SRVFULLNAME_S=$DIR/$SRVNAME
SRVFULLNAME=/etc/init.d/$SRVNAME


if test -f $MAINEXEC;then
	chmod +x $MAINEXEC
fi

# 安装 init 服务，提供参数 u 可卸载
# 安装过程：创建符号连接、启用、启动
# 卸载过程：停止、禁用、删除符号链接
if test -f $SRVFULLNAME_S;then

	chmod +x $SRVFULLNAME_S

	if test x$1 = x;then

		# =========== 二进制文件 ===========
		machine_type=$(uname -m)
		# 暂时只考虑 OpenWrt
		#OS_NAME=$(uname -o)


		bin_name=

		if [ "$machine_type" = x86_64 ];then
			bin_name=tinymapper_amd64
		elif [ "$machine_type" = x86 ];then
			bin_name=tinymapper_x86
		fi

		if [ -n "$bin_name" ];then
			if test ! -f $DIR/bin/$bin_name;then
				echo "二进制文件 $DIR/bin/$bin_name 不存在，请先添加"
				exit
			fi
			chmod +x $DIR/bin/$bin_name
			if [ ! -e /usr/bin/tinymapper -o "$(readlink -f /usr/bin/tinymapper)" != "$DIR/bin/$bin_name"  ];then
				ln -sfT $DIR/bin/$bin_name /usr/bin/tinymapper
			fi
		fi


		# ============ 服务 ==============

		if test "$(readlink -f $SRVFULLNAME)" != $SRVFULLNAME_S;then
			ln -sf $SRVFULLNAME_S $SRVFULLNAME
		fi

		if test -x $SRVFULLNAME;then
			! $SRVFULLNAME enabled && $SRVFULLNAME enable
			test -x $SRVFULLNAME && $SRVFULLNAME start
		fi

	elif test x$1 = xu;then
		# ============ 服务 ==============
		if test -x $SRVFULLNAME;then
			test -x $SRVFULLNAME && $SRVFULLNAME stop
			$SRVFULLNAME enabled && $SRVFULLNAME disable
		fi

		if test "$(readlink -f $SRVFULLNAME)" = $SRVFULLNAME_S;then
			rm -f $SRVFULLNAME
		fi

		# =========== 二进制文件 ===========
		rm -f /usr/bin/tinymapper
	fi
fi



