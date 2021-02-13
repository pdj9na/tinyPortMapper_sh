
# echo $MyInvocation.MyCommand.Definition
$DIR=Split-Path -Parent $MyInvocation.MyCommand.Definition
# echo $DIR
$RECORD_FILE="${DIR}\tinymapper_record.txt"
$TASKINFO_FILE="${DIR}\tinymapper_taskinfo.txt"
# echo $RECORD_FILE
# echo $DIR
# exit 0
$DNS='dns3.hichina.com'





function showhelp{
	echo "Usage: `n-c	配置转发	`n-i	应用IP转发`n-d	应用域名转发`n-h | --help	查看帮助"
}
function gettaskPID(){
#?为where-object的简写
# -last 简写为 -l
$(netstat -ano | ? {$_ -match "\s+?(TCP|UDP)\s+(\[::\]|(0\.){3}0):${port_local}\s"} | select -f 1) -csplit '\s+' | select -l 1;
}

function main{
# showhelp
if ( $args.count -eq 0 ){
# showhelp
}
# 正则匹配的所有端口
$portsPattern=''
$port_new=''

(cat ${RECORD_FILE}) | foreach {
	#echo $_.trim()
	$private:split=$_.trim() -csplit '\s+';
	$private:index=-1;
	$port_local=$split[++$index];
	$port_remote=$split[++$index];
	$_record_last=$split[++$index];
	if("$_record_last" -match "^([0-9a-fA-F\:]*\:){2}[0-9a-fA-F\:]*$"){
		$ip_Remote='['+$_record_last+']';
	}
	elseif("$_record_last" -match "^[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+\.?$"){
		$count=0
		while("$ip_Remote" -eq "" -and $count -le 10){
			$ip_Remote='['+"$("$(nslookup -qt=AAAA $_record_last $DNS)" -csplit '.*?名称:\s+\S+\s+Address(?:es)?:\s+(\S+)(?:$|\s+.*)')".trim()+']'
			if("$ip_Remote" -eq ""){++$count|sleep}
		}
	}
	# echo "$ip_Remote "
	$portsPattern="${portsPattern}|${port_local}";

	#############
	$_TaskPIDOld=gettaskPID;
	echo $_TaskPIDOld
	# $_PIDOld=''
	$port_LocalOld='';
	$ip_RemoteOld='';
	$port_RemoteOld='';
	if ("$_TaskPIDOld" -ne ""){
		(cat ${TASKINFO_FILE}) | ? {$_ -match "^\s*$_TaskPIDOld"} | foreach {
			$private:split=$_.trim() -csplit '\s+';
			$private:index=0;
			#$_PIDOld=$split[++$index];
			# $ip_LocalOld=$split[1];
			$port_LocalOld=$split[++$index];
			$ip_RemoteOld=$split[++$index];
			$port_RemoteOld=$split[++$index];
		}
	}
	
	echo $("`n上次进程信息>>>	{0}	本地IP:端口>{1}	远端IP:端口>{2}" -f	"PID:$_TaskPIDOld    ","[::]:$port_LocalOld","${ip_RemoteOld}:$port_RemoteOld")
	echo $("本次配置信息>>>	{0}	本地IP:端口>{1}	远端IP:端口>{2}`n" -f '        ',"[::]:$port_local","${ip_Remote}:$port_remote")
	
	if ( "" -ne "$_TaskPIDOld" -and "${ip_Remote}:$port_remote" -ne "${ip_RemoteOld}:$port_RemoteOld" ){
		echo "转发进程存在且IP或远端端口已更新"
		$null=taskkill /PID $_TaskPIDOld /F
		if ( "[]" -ne "$ip_Remote" ){
			for ($private:i=1;$i -le 500;++$i){
				$_TaskPIDOld=gettaskPID;
				if ("$_TaskPIDOld" -eq ""){break}
				sleep -mill 1
			}
		}
		$_TaskPIDOld=""
	}
	
	# 删除taskPID不存在的taskinfo记录
	(cat ${TASKINFO_FILE}) | ? {$_ -notmatch "^\s*\d+\s+${port_local}\s" -or ("$_TaskPIDOld" -ne "" -and $_ -match "^\s*${_TaskPIDOld}\s")} >${TASKINFO_FILE}
	
	if ( "" -eq "$_TaskPIDOld" -and "$ip_Remote" -ne '[]' ){
		echo "正在配置转发..."
		Invoke-Expression "${DIR}\hideexec.exe ${DIR}\tinymapper.exe -l [::]:$port_local -r ${ip_Remote}:$port_remote -t -u"
		for ($private:i=1;$i -le 500;++$i){
			sleep -mill 1
			$_TaskPID=gettaskPID;
			if ("$_TaskPID" -ne ""){
				echo "PID获取延迟（毫秒）:$i"
				echo "记录进程关联信息:`nPID	本地端口	远程IP地址			远程端口"
				echo "$_TaskPID	${port_local}		${ip_Remote}	${port_remote}"
				"$_TaskPID ${port_local} ${ip_Remote} ${port_remote}" >>${TASKINFO_FILE}
				$port_new="$port_new|$port_local"
				break
			}
		}
	}
	else {
		if ( "" -ne "$_TaskPIDOld" ){
			echo "转发进程存在且IP和远端端口未更新"
		}
		elseif ( "" -eq "$ip_Remote" ){
			echo "远端IP地址获取失败，本地不配置转发"			
		}
	}
	echo "---------------------------------------------------"
}
# $port_local 若没有指定访问级别，会从小往大搜索所有级别中存在的值
# 指定global和script级别不能访问local和private级别的变量，private级别可以访问local级别的变量
# 也就是说小范围能访问大范围，大范围不能访问小范围
# echo $global:port_local+$script:port_local$local:port_local+$private:port_local

if ("$portsPattern" -eq ""){$portsPattern='|\D'}
# echo $portsPattern

echo ''
# 结束不存在于record的port运行的taskPID
(cat ${TASKINFO_FILE}) | ? {$_ -notmatch "^\s*\d+\s+(?:$(${portsPattern}.substring(1)))\s"} | foreach {
	#echo $_.trim()
	$private:split=$_.trim() -csplit '\s+';
	$port_local=$split[1];
	$_TaskPIDOld=gettaskPID;
	if ("" -ne "$_TaskPIDOld"){
		$null=taskkill /PID $_TaskPIDOld /F
		echo "--不再使用的本地端口:$port_local 已成功结束进程（PID:${_TaskPIDOld}）"
	}
}

# 删除不存在于record的taskinfo记录
(cat ${TASKINFO_FILE}) | ? {$_ -match "^\s*\d+\s+(?:$(${portsPattern}.substring(1)))\s"} >${TASKINFO_FILE}

if ("$port_new" -eq ''){$port_new='|\D'}
# echo ${port_new:1}
echo "`n=========新增或更新的端口转发网络状态信息：==========="
netstat -ano | ? {$_ -match "\s*协议\s+本地地址\s+外部地址\s+状态\s+PID|\s+?(TCP|UDP)\s+\[::\]:$(${port_new}.substring(1))\s"}
echo ''
}

main

