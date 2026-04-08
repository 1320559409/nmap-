# 网络扫描脚本使用说明

## 依赖
- `nmap`（需 root 权限）
- `bash` 4.3+

## 准备文件
- `ipv4`：IPv4 地址列表（每行一个，支持 CIDR）
- `ipv6`：IPv6 地址列表（若无则留空或删除）
- `tports`：TCP 端口号列表（每行一个）
- `uports`：UDP 端口号列表（每行一个）

## 脚本列表
| 脚本 | 作用 |
|------|------|
| `port_tcp4/6` | TCP 端口扫描（IPv4/IPv6） |
| `port_udp4/6` | UDP 端口扫描（IPv4/IPv6） |
| `service_tcp4/6` | TCP 服务探测 |
| `service_udp4/6` | UDP 服务探测 |
| `run` | 全扫描（TCP+UDP） |
| `run_tcp_only.sh` | 仅 TCP 扫描 |
| `run_udp_only.sh` | 仅 UDP 扫描 |
| `process` | 合并所有结果为 `service_all` |

## 运行
```bash
sudo ./run               # 完整扫描  
sudo ./run_tcp_only.sh   # 只扫 TCP    约3小时
sudo ./run_udp_only.sh   # 只扫 UDP    约3小时
