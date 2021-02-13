
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
	echo "Usage: `n-c	����ת��	`n-i	Ӧ��IPת��`n-d	Ӧ������ת��`n-h | --help	�鿴����"
}
function gettaskPID(){
#?Ϊwhere-object�ļ�д
# -last ��дΪ -l
$(netstat -ano | ? {$_ -match "\s+?(TCP|UDP)\s+(\[::\]|(0\.){3}0):${port_local}\s"} | select -f 1) -csplit '\s+' | select -l 1;
}

function main{
# showhelp
if ( $args.count -eq 0 ){
# showhelp
}
# ����ƥ������ж˿�
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
			$ip_Remote='['+"$("$(nslookup -qt=AAAA $_record_last $DNS)" -csplit '.*?����:\s+\S+\s+Address(?:es)?:\s+(\S+)(?:$|\s+.*)')".trim()+']'
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
	
	echo $("`n�ϴν�����Ϣ>>>	{0}	����IP:�˿�>{1}	Զ��IP:�˿�>{2}" -f	"PID:$_TaskPIDOld    ","[::]:$port_LocalOld","${ip_RemoteOld}:$port_RemoteOld")
	echo $("����������Ϣ>>>	{0}	����IP:�˿�>{1}	Զ��IP:�˿�>{2}`n" -f '        ',"[::]:$port_local","${ip_Remote}:$port_remote")
	
	if ( "" -ne "$_TaskPIDOld" -and "${ip_Remote}:$port_remote" -ne "${ip_RemoteOld}:$port_RemoteOld" ){
		echo "ת�����̴�����IP��Զ�˶˿��Ѹ���"
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
	
	# ɾ��taskPID�����ڵ�taskinfo��¼
	(cat ${TASKINFO_FILE}) | ? {$_ -notmatch "^\s*\d+\s+${port_local}\s" -or ("$_TaskPIDOld" -ne "" -and $_ -match "^\s*${_TaskPIDOld}\s")} >${TASKINFO_FILE}
	
	if ( "" -eq "$_TaskPIDOld" -and "$ip_Remote" -ne '[]' ){
		echo "��������ת��..."
		Invoke-Expression "${DIR}\hideexec.exe ${DIR}\tinymapper.exe -l [::]:$port_local -r ${ip_Remote}:$port_remote -t -u"
		for ($private:i=1;$i -le 500;++$i){
			sleep -mill 1
			$_TaskPID=gettaskPID;
			if ("$_TaskPID" -ne ""){
				echo "PID��ȡ�ӳ٣����룩:$i"
				echo "��¼���̹�����Ϣ:`nPID	���ض˿�	Զ��IP��ַ			Զ�̶˿�"
				echo "$_TaskPID	${port_local}		${ip_Remote}	${port_remote}"
				"$_TaskPID ${port_local} ${ip_Remote} ${port_remote}" >>${TASKINFO_FILE}
				$port_new="$port_new|$port_local"
				break
			}
		}
	}
	else {
		if ( "" -ne "$_TaskPIDOld" ){
			echo "ת�����̴�����IP��Զ�˶˿�δ����"
		}
		elseif ( "" -eq "$ip_Remote" ){
			echo "Զ��IP��ַ��ȡʧ�ܣ����ز�����ת��"			
		}
	}
	echo "---------------------------------------------------"
}
# $port_local ��û��ָ�����ʼ��𣬻��С�����������м����д��ڵ�ֵ
# ָ��global��script�����ܷ���local��private����ı�����private������Է���local����ı���
# Ҳ����˵С��Χ�ܷ��ʴ�Χ����Χ���ܷ���С��Χ
# echo $global:port_local+$script:port_local$local:port_local+$private:port_local

if ("$portsPattern" -eq ""){$portsPattern='|\D'}
# echo $portsPattern

echo ''
# ������������record��port���е�taskPID
(cat ${TASKINFO_FILE}) | ? {$_ -notmatch "^\s*\d+\s+(?:$(${portsPattern}.substring(1)))\s"} | foreach {
	#echo $_.trim()
	$private:split=$_.trim() -csplit '\s+';
	$port_local=$split[1];
	$_TaskPIDOld=gettaskPID;
	if ("" -ne "$_TaskPIDOld"){
		$null=taskkill /PID $_TaskPIDOld /F
		echo "--����ʹ�õı��ض˿�:$port_local �ѳɹ��������̣�PID:${_TaskPIDOld}��"
	}
}

# ɾ����������record��taskinfo��¼
(cat ${TASKINFO_FILE}) | ? {$_ -match "^\s*\d+\s+(?:$(${portsPattern}.substring(1)))\s"} >${TASKINFO_FILE}

if ("$port_new" -eq ''){$port_new='|\D'}
# echo ${port_new:1}
echo "`n=========��������µĶ˿�ת������״̬��Ϣ��==========="
netstat -ano | ? {$_ -match "\s*Э��\s+���ص�ַ\s+�ⲿ��ַ\s+״̬\s+PID|\s+?(TCP|UDP)\s+\[::\]:$(${port_new}.substring(1))\s"}
echo ''
}

main

