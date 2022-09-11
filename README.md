# tinyPortMapper_sh
tinyPortMapper config shell

application from:
https://github.com/wangyu-/tinyPortMapper


# ==================== windows ======================


对于Win7
不能使用带_wepoll的程序，否则存在问题，如ATTODiskBenchmark 会无法写入SMB共享存储


# 2022-8-13 更新，已经通过 AlwaysUp 执行 msys bash 脚本，不再使用之前的 powershell 脚本

# 脚本文件："D:\_SharedSpace\bin\tinymapper.sh"
#	msys 路径 /media/SharedSpace/bin/tinymapper.sh

# 解析记录文件："C:\root\.config\tinymapper\tinymapper_record.conf"
#	msys 路径 /root/.config/tinymapper/tinymapper_record.conf


把 tinymapper.exe 添加到防火墙允许应用列表，否则端口映射不通




# ==================== OpenWrt =============================

# 可尝试 Docker 版，不过由于 Windows 系统 Docker 网络不完善，所以还是采用虚拟机使用 OpenWrt





执行 install.sh 完成初始化，编辑 /root/.config/tinymapper/tinymapper_record.conf


