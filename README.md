ip放进ipv*.conf里面，然后运行./run.sh （会运行端口存活探测、详细服务探测，然后输出到一个以运行时间为名的文件夹）
可选只跑tcp:scan_t.sh,只跑udp：scan_u.sh ,
tcp.conf 手动编辑选择tcp端口，udp.conf手动编辑选择udp端口
[该文件需要有nmap才能运行，无Nmap可手动找一个nmap单文件程序]
