#!/bin/bash
# PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
# export PATH


# ==== AlwaysUp ===
# 勾选 Ensure that the Windows networking components have started（确保Windows网络组件已经启动）
# 添加依赖服务：主机网络服务


# -------------------------------

# 读取域名的IP地址 domainName remoteIPTag
readRemoteIPFromDomainName(){
	local qt pattern
	local ip_var=$1 _remote=$2
	
	if [ $ip_var = '4' ];then qt='A'
	elif [ $ip_var = '6' ];then qt='AAAA'
	fi

	# dnsmasq解析可能会有问题，还容易出现 Parse error，所以指定DNS解析
	# awk NF变量表示最后列的列号
	local count=0 ip_remote
	if [ -n "$qt" ];then
		while [ -z "$ip_remote" -a $((++count)) -le 3 ];do
			#echo $qt=$_remote=$DNSDN
			# 批处理 bat 执行 windows 命令时，有些文字会变中文，再经过 msys 输出，会乱码，所以要避免中文！
			
			if [[ $OS_NAME =~ Cygwin|MSYS2 ]];then
				ip_remote=$(nslookup -qt=$qt "$_remote" "$DNSDN" | sed -E '1,/:\s+'$_remote'/d' | awk -F':\\s+' '{print $2}')
			elif [[ $OS_NAME =~ OpenWrt ]];then
				ip_remote=$(nslookup -qt=$qt "$_remote" "$DNSDN" | sed -E 's|has '$qt' address\s+|&\n|g' | sed -E '1,/^\s*'$_remote'/d')
			fi
		
			[ -z "$ip_remote" ] && sleep $count
		done
	fi
	echo $ip_remote
}

kill_pid(){

	if test "$LOG_QUIENT" != '1';then
		echo "准备结束的PID: $1"
	fi
	if [ -n "$1" ];then
		kill $1 >/dev/null 2>&1
		# openwrt 的 ps 不支持 -p 选项
		#if $procps -p $1 --no-heading >/dev/null 2>&1;then
		if kill -0 $1 >/dev/null 2>&1;then
			if test "$LOG_QUIENT" != 1;then
				echo "kill ${1}未正常结束，使用kill -9 强制结束"
			fi
			kill -9 $1 >/dev/null 2>&1
		fi
	fi
}

keep_alive(){

	local ip_local=$1 port_local=$2 ip_remote=$3 port_remote=$4
	
	local ip_localREG=$_REG_IPV4_ ip_remoteREG=$_REG_IPV4_
	
	if grep -qE $_REG_IPV6 <<<"$ip_local";then
		ip_local=[$ip_local]
		ip_localREG=$_REG_IPV6_
	fi
	
	if grep -qE $_REG_IPV6 <<<"$ip_remote";then
		ip_remote=[$ip_remote]
		ip_remoteREG=$_REG_IPV6_
	fi
	
	local pid ipport_localOld ipport_remoteOld 
	
	local pid2 ipport_localOld2 ipport_remoteOld2
	
	# 终止多余的本地和目标 IP:port 映射
	
	local procs
	
	if [[ $OS_NAME =~ Cygwin|MSYS2 ]];then
		procs=$($procps -w -C tinymapper --no-heading -o pid,args 2>/dev/null | grep -P "tinymapper\.exe\s\-l\s(${ip_localREG}:${port_local}|.*\s\-r\s${ip_remoteREG}:${port_remote})" | awk '{print $1,$4,$6}')
	elif [[ $OS_NAME =~ OpenWrt ]];then
		procs=$($procps -w 2>/dev/null | grep -E "\s+tinymapper\s\-l\s(${ip_localREG}:${port_local}|.*\s\-r\s${ip_remoteREG}:${port_remote})" | awk '{print $1,$7,$9}')
	fi
	
	while read pid2 ipport_localOld2 ipport_remoteOld2;do
		grep -qE '^\s*(#|$)' <<<"$pid2" && continue
		if test -z "$pid" -a "${ip_local}:${port_local}" = "$ipport_localOld2" -a "${ip_remote}:${port_remote}" = "$ipport_remoteOld2";then
			pid=$pid2
			ipport_localOld=$ipport_localOld2
			ipport_remoteOld=$ipport_remoteOld2
		fi
		test "$pid" = "$pid2" && continue
		kill_pid $pid2
	done <<<"$procs"


	if test "$LOG_QUIENT" = '1';then
		:
	else
		# 上次与本次不同的，在前面就已经终止了，这里出现的上次要么没有，要么与本次相同
		printf "\n上次进程信息>>>	%-10s	本地IP:端口>%32s	远端IP:端口>%32s"	'PID:'$pid	$ipport_localOld	$ipport_remoteOld
		printf "\n本次配置信息>>>	%-10s	本地IP:端口>%32s	远端IP:端口>%32s\n"	''	$ip_local:$port_local	$ip_remote:$port_remote
	fi

	local outfile=/dev/null
	if [ -z "$pid" -a -n "$ip_local" -a -n "$ip_remote" ];then
		if test "$LOG_QUIENT" = '1';then
			:
		else
			echo "正在配置转发..."
			outfile=${LOG_ROOTPATH}/${port_local}.${LOG_NAME}
			if [ ! -f $outfile ];then
				touch $outfile
				chmod a+rw $outfile
			fi
		fi
		
		tinymapper -l ${ip_local}:${port_local} -r ${ip_remote}:${port_remote} -t -u --log-level $LOG_LEVEL >>$outfile 2>&1 &
		#
		#port_new=${port_new}'|'${port_local}
		# echo "查看进程信息可确认是否配置成功"
	else
		if test "$LOG_QUIENT" != '1';then
			if [ -n "$pid" ];then
				echo "转发进程存在且IP未更新"
			#elif [ -z "$ip_local" ];then
			#	echo "本地IP地址获取失败，不配置转发"	
			#elif [ -z "$ip_remote" ];then
			#	echo "目标IP地址获取失败，不配置转发"			
			fi
		fi
	fi
	
	if test "$LOG_QUIENT" != '1';then
		echo "---------------------------------------------------"
	fi
	
	
	if test "$LOG_QUIENT" = '1';then
		:
	else
		# 截断日志文件为不超过指定行数
		local logFileLineCount=`[ -f $outfile ] && wc -l $outfile | awk '{print $1}' || echo 0`
		# echo $logFileLineCount
		# 运算：$(($a-$b)) 或 $[$a-$b] 或 $[a-b] 或 `expr $a - $b`
		# bash环境可支持：$(($a-$b)) 或 $[$a-$b] 或 $[a-b] 或 `expr $a - $b` 或((a-b))
		# ash环境（OpenWrt 18.06.8）可支持： $(($a-$b)) 或 `expr $a - $b`
		local logFileTruncateLineCount=$[logFileLineCount-LOGFILE_TRUNCATE_LATER_RETAIN_LINE_COUNT]
		# echo $logFileTruncateLineCount
		if [ "$logFileTruncateLineCount" -gt 0 ];then
			sed -i '1,'$logFileTruncateLineCount'd' $outfile
		fi
	fi
	
}

#telnet_wait(){
#	local dv=/dev/tty
#	(
#		s=`stty -F $dv -g`;
#		#stty -F $dv -echo inlcr;
#		
#		str=$"\n";
#		sstr=$(echo -e $str);
#		#echo "$sstr" >$dv;
#		
#		dd bs=1 cbs=1 if=$dv iflag=direct,sync,text;
#		
#		stty -F $dv $s
#	) | telnet "$@"
#}

requestNoTimeout(){
	local ip_addr=$1
	
	if [[ $OS_NAME =~ Cygwin|MSYS2 ]];then
		powershell -command "ping -n 1 -w 1000 $ip_addr | ? { $_ -match 'Request timed out|请求超时' }" | grep -q '^\s*$'
	elif [[ $OS_NAME =~ OpenWrt ]];then					
		ping -c 1 -W 1 -q $ip_addr >/dev/null
	fi
	
}

main(){

#local ipportPatterns='';

if test x$1 = x;then

	local _local _remote ip_vers port_telnets portmappers 
	local ip_local ip_remote
	local port_local port_remote port_telnet_local port_telnet_remote

	while read -r _local _remote ip_vers port_telnets portmappers;do
		grep -qE '^\s*(#|$)' <<<"$_local" && continue
		eval $(awk -F: '{printf("port_telnet_local=%s;port_telnet_remote=%s",$1,$2)}' <<<"$port_telnets")
		
		{
			while true;do	
				while true;do
					# 本地记录类型
					if ! grep -qE $_REG_IPV4 <<<"$_local" && grep -qE $_REG_DOMAIN <<<"$_local";then
						ip_local=$(readRemoteIPFromDomainName $(awk -F: '{print $1}' <<<$ip_vers) $_local)
					else
						ip_local=$_local
					fi
					test -z "$ip_local" && continue
					grep -qE '(0\.){3}0|::' <<<"$ip_local" && break
				
					if requestNoTimeout $ip_local;then
						break					
					else
						sleep 2
						continue
					fi
					
				done
			
				while true;do
					# 远程记录类型
					if ! grep -qE $_REG_IPV4 <<<"$_remote" && grep -qE $_REG_DOMAIN <<<"$_remote";then
						ip_remote=$(readRemoteIPFromDomainName $(awk -F: '{print $2}' <<<$ip_vers) $_remote)
					else
						ip_remote=$_remote
					fi
					test -z "$ip_remote" && continue
					grep -qE '(0\.){3}0|::' <<<"$ip_remote" && break
					
					echo "$ip_remote"
					if requestNoTimeout $ip_remote;then
						break					
					else
						sleep 2
						continue
					fi
			
				done

				while read -r port_local port_remote;do
					keep_alive $ip_local $port_local $ip_remote $port_remote
				done <<<$(awk -F: '{print $1,$2}' <<<$(sed 's|,|\n|g' <<<"$portmappers"))
				
				#tail -f /dev/null
				# 目录只考虑 映射目标 的域名
				
				#telnet_wait 192.168.1.10 22223
				#telnet_wait omv.pdj9na.top 80
				#telnet_wait 192.168.1.111 22223
				#telnet_wait $ip_remote $port_telnet_remote
				
				# telnet_wait 中必须要在终端中输入 回车，才能终止关闭的连接，不然会一直停着
				# 而 作为服务运行时，不能手动输入任何字符，所以 telnet_wait 不能用！
				sleep $RESOLVE_WAIT
				
			done
			
		} &
		
		main_pids=$main_pids$'\n'$!
		
	done <${RECORD_FILE}
	
else

	local mpid
	
	if test "$LOG_QUIENT" != '1';then
		echo ===mainpids=$main_pids
	fi
	for mpid in $main_pids;do
		kill_pid $mpid	
	done
	
	unset main_pids

	# 结束不存在于record的port运行的taskPID

	local pid ipport_local ipport_remote
	local procs
	
	if [[ $OS_NAME =~ Cygwin|MSYS2 ]];then
		procs=$($procps --no-heading -Awo pid,args 2>/dev/null | grep -E "tinymapper\.exe\s+" | awk '{print $1,$4,$6}')
	elif [[ $OS_NAME =~ OpenWrt ]];then
		procs=$($procps -w 2>/dev/null | grep -E "\s+tinymapper\s+" | awk '{print $1,$7,$9}')
	fi
	while read pid ipport_local ipport_remote;do
		test -z "$pid" && continue
		ip_local=$(sed -E 's/\[|\]//g' <<<${ipport_local%:*})
		port_local=${ipport_local##*:}
		
		ip_remote=$(sed -E 's/\[|\]//g' <<<${ipport_remote%:*})
		port_remote=${ipport_remote##*:}
		
		#if ! grep -qE '^'"$ip_local $port_local $ip_remote $port_remote"'$' <<<"$ipportPatterns";then
			
			if test "$LOG_QUIENT" != '1';then
				echo -e "不再使用的本地 IP 端口: $ip_local ${port_local} \c"
			fi
			
			kill_pid $pid
			if test "$LOG_QUIENT" = '1';then
				:
			else
				[ -f "${LOG_ROOTPATH}/${port_local}.${LOG_NAME}" ] && rm "${LOG_ROOTPATH}/${port_local}.${LOG_NAME}"
			fi
		#fi

	done <<<"$procs"

fi

}



fn_OSProc() {

	OS_NAME=$(uname -o)
	
	# Cygwin 没有 /etc/os-release
	if test -r /etc/os-release;then
		eval OS_$(grep '^NAME=' /etc/os-release)
	fi
	
	if [[ $OS_NAME =~ Cygwin|MSYS2 ]];then
		procps=procps
	else
		procps=ps
	fi
	
	# OS_NAME: OpenWrt MSYS2 Cygwin
	export OS_NAME procps
}


# 所以不需要通过cd 到目录，然后通过pwd来取路径
REALFILE=$(readlink -f $0)
DIR=${REALFILE%/*}/

#日志级别	0: never    1: fatal   2: error   3: warn	4: info(default)	5: debug   6: trace
LOG_LEVEL=4

# 日志文件名
LOG_NAME='tinymapper.log'

LOG_ROOTPATH=/tmp/tinymapper

mkdir -p $LOG_ROOTPATH

# 是否抑制日志输出
grep -qE '(^|\s)q(\s|$)' <<<"$*" && LOG_QUIENT=1

# 日志文件截断后保留的最大行数，只在调用keep_alive函数时操作
LOGFILE_TRUNCATE_LATER_RETAIN_LINE_COUNT=50

RECORD_FILE="/root/.config/tinymapper/tinymapper_record.conf"

# DNS 域名解析指定DNS，采用域名解析服务提供商的DNS最好，指定其他DNS如114，更新会有延迟
# 经过测试，指定为运营商DNS反而容易出现解析错误 Parse error
# 可用DNS有：dns3.hichina.com, dns5.hichina.com, dns10.hichina.com, dns4.hichina.com ...
DNSDN='dns3.hichina.com'


_REG_IPV4_='([0-9]+\.){3}[0-9]+'
_REG_IPV6_='([0-9a-fA-F\:]*\:){2}[0-9a-fA-F\:]*'

_REG_IPV4='^'$_REG_IPV4_'$'
_REG_IPV6='^'$_REG_IPV6_'$'
# IPV4 地址格式符合 域名格式，验证时需要排除 IPV4 的情况
_REG_DOMAIN='^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+\.?$'


# 重新解析域名的等待时间（s）
RESOLVE_WAIT=300

fn_OSProc

tail -f /dev/null &

main
trap "main u" TSTP TERM QUIT INT

wait

# 配置文件修改后，重启服务
# 暂不考虑监视 配置 文件修改
#record_change


