#!/bin/bash
# PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
# export PATH

# tinyPortMapper
# git version:25ea4ec047    build date:Nov  4 2017 22:55:23
# repository: https://github.com/wangyu-/tinyPortMapper

# usage:
    # ./this_program  -l <listen_ip>:<listen_port> -r <remote_ip>:<remote_port>  [options]

# main options:
    # -t                                    enable TCP forwarding/mapping
    # -u                                    enable UDP forwarding/mapping

# other options:
    # --sock-buf            <number>        buf size for socket, >=10 and <=10240, unit: kbyte, default: 1024
    # --log-level           <number>        0: never    1: fatal   2: error   3: warn
                                          # 4: info (default)      5: debug   6: trace
    # --log-position                        enable file name, function name, line number in log
    # --disable-color                       disable log color
    # -h,--help                             print this help message

Green="\033[32m"
Font="\033[0m"
Blue="\033[33m"


#echo $(readlink -f $0)

# $0可能是相对路径，要看是怎么调用的，readlink出来的是绝对路径
#dir1=$(readlink -f $0)
#echo ${dir1%/*}

# readlink出来的是绝对路径，这个dirname取出来的肯定是绝对路径
#echo $(dirname $(readlink -f $0))

# 所以不需要通过cd 到目录，然后通过pwd来去路径
REALFILE=$(readlink -f $0)
[ -z "$DIR" ] && DIR=$(dirname $REALFILE) && [ "${DIR:0-1}" != '/' ] && DIR=$DIR/

#日志级别	0: never    1: fatal   2: error   3: warn	4: info(default)	5: debug   6: trace
LOG_LEVEL=4
# 日志文件名
LOG_NAME='tinymapper.log'

# 日志文件截断后保留的最大行数，只在调用keep_alive函数时操作
LOGFILE_TRUNCATE_LATER_RETAIN_LINE_COUNT=50

RECORD_FILE="${DIR}tinymapper_record.txt"
CRONTAB_FILE="/etc/crontabs/root"
RC_LOCAL_FILE="/etc/rc.local"

# DNS 域名解析指定DNS，采用域名解析服务提供商的DNS最好，指定其他DNS如114，更新会有延迟
# 经过测试，指定为运营商DNS反而容易出现解析错误 Parse error
# 可用DNS有：dns3.hichina.com, dns5.hichina.com, dns10.hichina.com, dns4.hichina.com ...
DNSDN='dns3.hichina.com'

# ===============直接设置静态IP=============
#转发记录格式:本地端口 本地IP版本(4，6) 远程端口 IP地址
#例子:
#65535 4 65535 11.22.33.44
#65535 6 65535 11.22.33.44

# ===============域名获取IP=================
#转发记录格式:本地端口 本地IP版本(4，6) 远程端口 远端IP版本(4，6) 域名
# 当本地IP版本为6的时候，通过本机IPv4和IPv6地址都可以正常访问端口
# 	通过IPv4访问时，会自动将访问者IPv4地址转换为兼容的IPv6地址
# 当本地IP版本为4的时候，只能通过本机IPv4地址访问端口（程序版本：20200818.0）
#例子:
#65535 4 65535 4 abc.com
#65535 4 65535 6 abc.com
#65535 6 65535 6 abc.com

# -------------------------------



config_ip(){
echo -e "${Green}请输入tinyPortMapper配置信息！${Font}"

local flag ret=0

if [ "$ret" -eq 0 ];then
	unset port_local
	while [ -z "$port_local" ] || echo "$port_local" | grep -qvE "^-?\d+$" || [ "$port_local" -lt 1 -o "$port_local" -gt 65535 ];do
		[ -n "$flag" ] && echo "端口是介于1到65535的整数！"
		read -p "请输入本地监听端口，输入q可取消设置：" port_local
		[ "$port_local" = 'q' ] && ret=1 && break
		[ -z "$flag" ] && flag="1"
	done
	unset flag
fi


if [ "$ret" -eq 0 ];then
	unset port_remote
	while [ -z "$port_remote" ] || echo "$port_remote" | grep -qvE "^-?\d+$" || [ "$port_remote" -lt 1 -o "$port_remote" -gt 65535 ];do
		[ -n "$flag" ] && echo "端口是介于1到65535的整数！"
		read -p "请输入远端转发端口，输入q可取消设置：" port_remote
		[ "$port_remote" = 'q' ] && ret=1 && break
		[ -z "$flag" ] && flag="1"
	done
	unset flag
fi

# 当本地IP版本为6的时候，通过本机IPv4和IPv6地址都可以正常访问端口
# 	通过IPv4访问时，会自动将访问者IPv4地址转换为兼容的IPv6地址
# 当本地IP版本为4的时候，只能通过本机IPv4地址访问端口（程序版本：20200818.0）
if [ "$ret" -eq 0 ];then
	unset localIPTag
	while [ -z "$localIPTag" ] || echo "$localIPTag" | grep -qvE "^[46]$";do
		[ -n "$flag" ] && echo "有效字符为46"
		read -p "请输入本地IP版本(4，6)，输入q可取消设置：" localIPTag
		[ "$localIPTag" = 'q' ] && ret=1 && break
		[ -z "$flag" ] && flag="1"
	done
	unset flag
fi

if [ "$ret" -eq 0 ];then
	unset ip_remote
	while [ -z "$ip_remote" ] \
		|| echo "$ip_remote" | grep -qvE "^(\d{1,3}\.){3}\d{1,3}$|^([0-9a-fA-F\:]*\:){2}[0-9a-fA-F\:]*$";do
		[ -n "$flag" ] && echo "有效IP地址是形如0.0.0.0或1:2:3::4的格式！"
		read -p "请输入被转发IP（对于IPv6地址不要用'[]'包裹），输入q可取消设置：" ip_remote
		[ "$ip_remote" = 'q' ] && ret=1 && break
		[ -z "$flag" ] && flag="1"
	done
	unset flag
fi

[ "$ret" = '1' ] && unset port_local port_remote localIPTag ip_remote
return $ret
}

config_domain(){
echo -e "${Green}请输入tinyPortMapper配置信息！${Font}"

local flag ret=0

if [ "$ret" -eq 0 ];then
	unset port_local
	while [ -z "$port_local" ] || echo "$port_local" | grep -qvE "^-?\d+$" || [ "$port_local" -lt 1 -o "$port_local" -gt 65535 ];do
		[ -n "$flag" ] && echo "端口是介于1到65535的整数！"
		read -p "请输入本地监听端口，输入q可取消设置：" port_local
		[ "$port_local" = 'q' ] && ret=1 && break
		[ -z "$flag" ] && flag="1"
	done
	unset flag
fi

if [ "$ret" -eq 0 ];then
	unset port_remote
	while [ -z "$port_remote" ] || echo "$port_remote" | grep -qvE "^-?\d+$" || [ "$port_remote" -lt 1 -o "$port_remote" -gt 65535 ];do
		[ -n "$flag" ] && echo "端口是介于1到65535的整数！"
		read -p "请输入远端转发端口，输入q可取消设置：" port_remote
		[ "$port_remote" = 'q' ] && ret=1 && break
		[ -z "$flag" ] && flag="1"
	done
	unset flag
fi

if [ "$ret" -eq 0 ];then
	unset localIPTag
	while [ -z "$localIPTag" ] || echo "$localIPTag" | grep -qvE "^[46]$";do
		[ -n "$flag" ] && echo "有效字符为46"
		read -p "请输入本地IP版本(4，6)，输入q可取消设置：" localIPTag
		[ "$localIPTag" = 'q' ] && ret=1 && break
		[ -z "$flag" ] && flag="1"
	done
	unset flag
fi

if [ "$ret" -eq 0 ];then
	unset remoteIPTag
	while [ -z "$remoteIPTag" ] || echo "$remoteIPTag" | grep -qvE "^[46]$";do
		[ -n "$flag" ] && echo "有效字符为46"
		read -p "请输入远端IP版本(4，6)，输入q可取消设置：" remoteIPTag
		[ "$remoteIPTag" = 'q' ] && ret=1 && break
		[ -z "$flag" ] && flag="1"
	done
	unset flag
fi

if [ "$ret" -eq 0 ];then
	unset domainName
	while [ -z "$domainName" ] || echo "$domainName" | grep -qvE "^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+\.?$";do
		[ -n "$flag" ] && echo "一个完整的域名，由根域名、顶级域名、二级域名、三级域名……构成
	每级域名之间用点分开，每级域名由字母、数字和减号构成（第一个字母不能是减号），不区分大小写，长度不超过63"
		read -p "请输入被转发域名，输入q可取消设置：" domainName
		[ "$domainName" = 'q' ] && ret=1 && break
		[ -z "$flag" ] && flag="1"
	done
	unset flag
fi

[ "$ret" = '1' ] && unset port_local port_remote localIPTag remoteIPTag domainName
return $ret
}

show_rule(){
	printf "%-15s%-17s%-15s%-s\n" 本地端口	本地IP版本	远程端口	远程IP地址
	[ -r $RECORD_FILE ] && cat $RECORD_FILE | grep -E '^i' | awk '{printf("%-11s%-13s%-11s%-s\n",$2,$3,$4,$5)}'

	printf "\n%-15s%-17s%-15s%-17s%s\n" 本地端口	本地IP版本	远程端口	远端IP版本	域名
	[ -r $RECORD_FILE ] && cat $RECORD_FILE | grep -E '^d' | awk '{printf("%-11s%-13s%-11s%-13s%s\n",$2,$3,$4,$5,$6)}'
	
	echo
    ps -w | grep -E "^(\s+)PID(\s+)USER(\s+)VSZ(\s+)STAT(\s+)COMMAND|${DIR}tinymapper\s\-l\s(.+)\:(\d+)\s\-r"
}

active_rule(){

	local p line pid
	read -p "输入r可重新激活，输入其他的仅恢复失活的映射：" p
	
	if [ "$p" = 'r' ];then
		ps -w | grep -E "${DIR}tinymapper\s\-l\s(.+)\:(\d+)\s\-r" | while read -r line;do
			eval `echo $line | awk '{printf("pid=%s",$1)}'`
			kill_pid $pid
		done
		sleep 1
	fi
	[ -r $RECORD_FILE ] && run_record "id"
}

#删除转发规则
delete_rule(){
local flag ret=0
unset port_local
while [ -z "$port_local" ] || echo "$port_local" | grep -qvE "^-?\d+$" || [ "$port_local" -lt 1 -o "$port_local" -gt 65535 ];do
	[ -n "$flag" -a "$port_local" != 's' -a "$port_local" != 'q' ] && echo "端口是介于1到65535的整数！"
	read -p "请输入转发规则的本地端口，输入s可查看转发规则配置和进程信息，输入q可取消操作:" port_local
	[ "$port_local" = 's' ] && echo && show_rule
	[ "$port_local" = 'q' ] && ret=1 && break
	[ -z "$flag" ] && flag="1"
done

if [ "$ret" = '0' ];then
	kill_pid `ps -w | grep -E "${DIR}tinymapper\s\-l\s(.+)\:${port_local}" | awk 'NR==1{print $1}'`
	delete_rule3
	echo -e "${Blue}转发规则删除成功！${Font}"
fi
return $ret
}

delete_rule3(){
[ -w $RECORD_FILE ] && sed -i -E '/^[id]\s+'${port_local}'/d' $RECORD_FILE
}

mark_IPRecord(){
delete_rule3
echo "i ${port_local} $localIPTag ${port_remote} ${ip_remote}" >>$RECORD_FILE
}

mark_DomainRecord(){
delete_rule3
echo "d ${port_local} $localIPTag ${port_remote} $remoteIPTag ${domainName}" >>$RECORD_FILE
}

#设置定时任务，保活转发规则并检查DDNS IP更新
set_cronjob(){

local flag ip_EveryMinute domain_EveryMinute
while [ -z "$ip_EveryMinute" ] || echo "$ip_EveryMinute" | grep -qvE "^-?\d+$" || [ "$ip_EveryMinute" -lt 1 -o "$ip_EveryMinute" -gt 1200 ];do
	[ -n "$flag" ] && echo "请把分钟设置为介于1到1200的整数！"
	read -p "请输入IP转发规则的分钟数:(1-1200)，输入b可跳过不设置，输入d代表删除，输入q取消设置：" ip_EveryMinute
	[ "$ip_EveryMinute" = 'b' -o "$ip_EveryMinute" = 'd' ] && break
	[ "$ip_EveryMinute" = 'q' ] && return
	[ -z "$flag" ] && flag="1"
done
unset flag

while [ -z "$domain_EveryMinute" ] || echo "$domain_EveryMinute" | grep -qvE "^-?\d+$" || [ "$domain_EveryMinute" -lt 1 -o "$domain_EveryMinute" -gt 120 ];do
	[ -n "$flag" ] && echo "请把分钟设置为介于1到120的整数！"
	read -p "请输入域名转发规则的分钟数:(1-120)，输入b可跳过不设置，输入d代表删除，输入q取消设置：" domain_EveryMinute
	[ "$domain_EveryMinute" = 'b' -o "$domain_EveryMinute" = 'd' ] && break
	[ "$domain_EveryMinute" = 'q' ] && return
	[ -z "$flag" ] && flag="1"
done
unset flag

# OpenWrt

if [ "$ip_EveryMinute" != 'b' ];then
	delete_cronjob2 -i '&'
	[ "$ip_EveryMinute" != 'd' ] && echo "*/$ip_EveryMinute * * * * ${REALFILE} -i &" >>${CRONTAB_FILE}
fi
if [ "$domain_EveryMinute" != 'b' ];then
	delete_cronjob2 -d '&'
	[ "$domain_EveryMinute" != 'd' ] && echo "*/$domain_EveryMinute * * * * ${REALFILE} -d &" >>${CRONTAB_FILE}
fi

echo
if [ "$ip_EveryMinute" = 'b' -a "$domain_EveryMinute" = 'b' ];then
	echo "IP和Domain都未设置，不需要重启服务"
else
	echo -e "设置后 \c"
	show_cronjob
	restart_cron
fi

}

# 重启定时任务
restart_cron(){
# local result=`/etc/init.d/cron restart && echo 1 || echo 0`
/etc/init.d/cron restart
# echo "$?"
if [ "$?" = '0' ];then
	echo "cron服务重启成功！"
elif [ "$?" = '1' ];then
	echo "cron服务重启失败！"
fi
}

# 显示定时任务
show_cronjob(){
echo "定时任务明细："
[ -r ${CRONTAB_FILE} ] && cat ${CRONTAB_FILE} | grep -E "${REALFILE}"
}

# 删除定时任务
delete_cronjob2(){

# 假设我们定义了一个变量为：
# file=/dir1/dir2/dir3/my.file.txt
# ${file//dir/path}：将全部dir 替换为 path：/path1/path2/path3/my.file.txt

# ${DIR//\//\\\/} 分割符不能改成其他的如#
# 可用的格式：
# -i '/'${DIR//\//\\\/}'tinymapper.sh --run --domain/d'
# -i "/${DIR//\//\\\/}tinymapper.sh --run --domain/d"

# echo "\"${*}\""
# echo "\"${*//\-/\\\-}\""
# sed中不能直接使用带空格的$* --找到原因为“unterminated address regex”错误， 对于含有空格的变量，需要""包起来
# sed中不能使用非贪婪模式，添加-r选项也没用 --原因为sed命令被简化了，完整的sed是支持的
sed -i /"${REALFILE//\//\\\/}"' '"${*//\-/\\\-}"/d ${CRONTAB_FILE}
}

set_bootup(){

local flag num
while [ -z "$num" ] || echo "$num" | grep -qvE "^[adq]$";do
	[ -n "$flag" ] && echo "a代表添加转发，d代表删除转发；或输入q取消设置"
	read -p "请输入(a|d|q)，a:添加转发，d:删除转发，q:取消设置：" num
	[ "$num" = 'q' ] && return
	[ -z "$flag" ] && flag="1"
done
unset flag

# OpenWrt
[ ! -f ${RC_LOCAL_FILE} ] && touch ${RC_LOCAL_FILE} && chmod u+rw ${RC_LOCAL_FILE}
[ ! -x ${RC_LOCAL_FILE} ] && chmod ug+x ${RC_LOCAL_FILE}

# [ "$num" = a -o "$num" = d ] && 
sed -i /"${REALFILE//\//\\\/}"' -id &'/d ${RC_LOCAL_FILE}
if [ "$num" = a ];then
	if cat ${RC_LOCAL_FILE} | grep -qE '^\s*exit($|\s)';then
		sed -i -E '/^\s*exit\b/i\'"${REALFILE}"' -id &' ${RC_LOCAL_FILE}
	else
		sed -i '$a\'"${REALFILE}"' -id &' ${RC_LOCAL_FILE}
		# echo ${DIR}'tinymapper.sh --run '${part2}' &' >>${RC_LOCAL_FILE}
	fi
fi

show_bootup
}

show_bootup(){
echo "开机启动任务信息："
[ -r ${RC_LOCAL_FILE} ] && cat ${RC_LOCAL_FILE} | grep "${REALFILE}"' -id &'
}

set_forwardmethod(){
    echo
    echo -e "${Green}选择脚本功能${Font}"
	echo -e "${Blue}1. 添加IP转发${Font}"
	echo -e "${Blue}2. 添加域名转发(支持DDNS)${Font}"
	echo -e "${Blue}3. 查看转发规则配置和进程信息${Font}"
	echo -e "${Blue}4. 激活转发规则${Font}"
	echo -e "${Blue}5. 删除转发规则${Font}"
	echo -e "${Blue}6. 设置定时任务${Font}"
	echo -e "${Blue}7. 查看定时任务${Font}"
	echo -e "${Blue}8. 设置开机启动任务${Font}"
	echo -e "${Blue}9. 查看开机启动任务${Font}"
	
	echo -e "${Blue}q. 退出脚本${Font}"	
	echo
	local num
	read -p "请输入一个编号:" num
	echo
	case "$num" in
    1)
    config_ip && (
		mark_IPRecord
		keep_alive
	)
    ;;
    2)
    config_domain && (
		mark_DomainRecord
		readRemoteIPFromDomainName
		keep_alive
	)
    ;;
	3)
    show_rule
    ;;
	4)
    active_rule
    ;;
	5)
    delete_rule
    ;;
	6)
	set_cronjob
	;;
	7)
	show_cronjob
	;;
	8)
	set_bootup
	;;
	9)
	show_bootup
	;;
	q)
    exit 0
    ;;
    esac
	
    set_forwardmethod
}

# 读取域名的IP地址 domainName remoteIPTag
readRemoteIPFromDomainName(){
	unset ip_remote
	local qt pattern
	if [ $remoteIPTag = '4' ];then qt='A';pattern='Name:\\\s\\\S+\\\sAddress:\\\s'
	elif [ $remoteIPTag = '6' ];then qt='AAAA';pattern='has\\\sAAAA\\\saddress\\\s'
	fi

	# dnsmasq解析可能会有问题，还容易出现 Parse error，所以指定DNS解析
	# awk NF变量表示最后列的列号
	if [ -n "$qt" ];then
		local count=0
		while [ -z "$ip_remote" -a $count -le 10 ];do
			ip_remote=`echo $(nslookup -qt=$qt "$domainName" "$DNSDN") | awk -F$pattern '{print $2}'`
			[ -z "$ip_remote" ] && sleep $((++count))
		done
	fi
}

kill_pid(){

echo "准备结束的PID: $1"
if [ -n "$1" ];then
	kill $1 >/dev/null 2>&1
	if ps | grep -q '^\s*'$1'\b';then
		echo "kill ${1}未正常结束，使用kill -9 强制结束"
		kill -9 $1 >/dev/null 2>&1
	fi
fi
}

keep_alive(){
	if [ $localIPTag = '4' ];then		
		local ip_local='0.0.0.0'
	elif [ $localIPTag = '6' ];then
		local ip_local='[::]'
	fi
	local pid ipport_localOld ip_localOld ipport_remoteOld ip_remoteOld port_remoteOld
	eval `ps -w | grep -E "${DIR}tinymapper\s\-l\s(.+)\:${port_local}" | awk 'NR==1{printf("pid=%s;ipport_localOld=%s;ipport_remoteOld=%s",$1,$7,$9)}'`

	# 去掉:及右边的所有内容
	ip_localOld=${ipport_localOld%:*}
	
	ip_remoteOld=${ipport_remoteOld%:*}
	port_remoteOld=${ipport_remoteOld##*:}
	
	local ip_remote2=$ip_remote
	echo "$ip_remote" | grep -qE "^([0-9a-fA-F\:]*\:){2}[0-9a-fA-F\:]*$" && ip_remote2=[$ip_remote]
	
	printf "\n上次进程信息>>>	%-10s	本地IP:端口>%15s	远端IP:端口>%36s"	'PID:'$pid	$ipport_localOld	$ipport_remoteOld
	printf "\n本次配置信息>>>	%-10s	本地IP:端口>%15s	远端IP:端口>%36s\n"	''	$ip_local:$port_local	$ip_remote2:$port_remote
	
	if [ -n "$pid" ] && [ "$ip_local" != "$ip_localOld" -o "$ip_remote2:$port_remote" != "$ipport_remoteOld" ];then
		echo "转发进程存在且IP或远端端口已更新"
		kill_pid $pid
		unset pid
		[ -n "$ip_remote" ] && sleep 1
	fi

	# unset 后的变量 -z 验证为真，等同于空串
	if [ -z "$pid" -a -n "$ip_remote" ];then
		echo "正在配置转发..."
		if [ ! -f ${DIR}${port_local}.${LOG_NAME} ];then
			touch ${DIR}${port_local}.${LOG_NAME}
			chmod a+rw ${DIR}${port_local}.${LOG_NAME}
		fi
		nohup ${DIR}tinymapper -l ${ip_local}:${port_local} -r ${ip_remote2}:${port_remote} -t -u --log-level $LOG_LEVEL >>${DIR}${port_local}.${LOG_NAME} 2>&1 &
		#
		[ "$1" = 'list' ] && port_new=${port_new}'|'${port_local}
		# echo "查看进程信息可确认是否配置成功"
	else
		if [ -n "$pid" ];then
			echo "转发进程存在且IP和远端端口未更新"
		elif [ -z "$ip_remote" -o "$ip_remote" = '[]' ];then
			echo "远端IP地址获取失败，本地不配置转发"			
		fi	
	fi
	echo "---------------------------------------------------"
	
	# 截断日志文件为不超过指定行数
	local logFileLineCount=`[ -f ${DIR}${port_local}.${LOG_NAME} ] && wc -l ${DIR}${port_local}.${LOG_NAME} | awk '{print $1}' || echo 0`
	# echo $logFileLineCount
	# 运算：$(($a-$b)) 或 $[$a-$b] 或 $[a-b] 或 `expr $a - $b`
	# bash环境可支持：$(($a-$b)) 或 $[$a-$b] 或 $[a-b] 或 `expr $a - $b` 或((a-b))
	# ash环境（OpenWrt 18.06.8）可支持： $(($a-$b)) 或 `expr $a - $b`
	local logFileTruncateLineCount=$[logFileLineCount-LOGFILE_TRUNCATE_LATER_RETAIN_LINE_COUNT]
	# echo $logFileTruncateLineCount
	if [ "$logFileTruncateLineCount" -gt 0 ];then
		sed -i '1,'$logFileTruncateLineCount'd' ${DIR}${port_local}.${LOG_NAME}
	fi
}

run_record(){
# 正则匹配的所有端口
local portsPattern='';
local line port pid
# 新增或更新的端口
port_new=''

while read -r line;do
	# _recordtype :i,d
	local _recordtype
	eval `echo $line | awk '{printf("port_local=%s;localIPTag=%s;port_remote=%s;ip_remote=%s;remoteIPTag=%s;domainName=%s",$1,$2,$3,$4,$4,$NF)}'`
	if echo "$domainName" | grep -qE '^([0-9a-fA-F\:]*\:){2}[0-9a-fA-F\:]*$';then
		_recordtype='i'
	elif echo "$domainName" | grep -qE '^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+\.?$';then
		_recordtype='d'
	fi
	portsPattern=${portsPattern}'|'${port_local}
	# 这里不能开子shell，用()包起来会创建子shell，子shell修改值在父shell不生效
	if [[ "$_recordtype" =~ [$1] ]];then [ "$_recordtype" = d ] && readRemoteIPFromDomainName;keep_alive 'list';fi
	# [[ "$_recordtype" =~ [$1] ]] && ([ "$_recordtype" = d ] && readRemoteIPFromDomainName;keep_alive 'list')
done < ${RECORD_FILE}

portsPattern=${portsPattern:-'|\D'}

echo
# 结束不存在于record的port运行的taskPID
ps -w | grep -E "${DIR}tinymapper\s\-l\s(.+)\:(\d+)\s\-r" | awk '{print $7,$1}' | awk -F'\\\s+|\\\[::\\\]:|(0\\\.){3}0' '{print $2,$3}' | grep -vE "^(${portsPattern:1})\s" | while read -r line;do
	eval $(echo $line | awk '{printf("port=%s;pid=%s",$1,$2)}')
	echo -e "--不再使用的本地端口:${port} \c"
	kill_pid $pid
	# echo "${DIR}${port}.${LOG_NAME}"
	[ -f "${DIR}${port}.${LOG_NAME}" ] && rm "${DIR}${port}.${LOG_NAME}"
done

sleep 1
port_new=${port_new:-'|\D'}
# echo ${port_new:1}
echo  -e "\n=========新增或更新的端口转发进程信息：==========="
ps -w | grep -E "^(\s+)PID(\s+)USER(\s+)VSZ(\s+)STAT(\s+)COMMAND|${DIR}tinymapper\s\-l\s(.+)\:(${port_new:1})\s\-r"
echo

}

showhelp(){
	echo -e "Usage: \n-c	配置转发	\n-i	应用IP转发\n-d	应用域名转发\n-h | --help	查看帮助"
}

main(){
# 测试：  /root/tinyPortMapper/tinymapper.sh -a "b" -c "d e" 'f g'
# echo "进入运行..."
# echo "参数列表：$*"
# echo "参数列表：$@"
# echo "参数个数：$# ${#@}"
 
 # 创建符号链接
 # echo $PATH
# echo ${REALFILE}
[ ! -f /usr/sbin/tpm ] && mkdir -p /usr/sbin && ln -s ${REALFILE} /usr/sbin/tpm

if [ $# = 0 ] || echo "$@" | grep -qE '(^|\s)\-(\w*?h\w*?|\-help)($|\s)';then
	showhelp
# 带有-c参数后，不考虑其他参数
elif echo "$@" | grep -qE '(^|\s)\-\w*?c';then
	set_forwardmethod
else
	local i j p
	for ((i=1;i<=$#;++i));do
		eval 'j=${'"$i"'}'
		
		echo "$j" | grep -qE '^\-\w*?i' && [ -r $RECORD_FILE ] && p=i$p
		echo "$j" | grep -qE '^\-\w*?d' && [ -r $RECORD_FILE ] && p=d$p
	done
	[ -n "$p" ] && run_record "$p"
fi

}

# 与$*相同，但是使用时加引号，并在引号中返回每个参数。
main "$@"

