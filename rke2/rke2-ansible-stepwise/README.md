# RKE2 Ansible 分步骤部署

基于实战经验优化的分步骤部署方案，便于问题定位和调试。

## 设计理念

**传统方式的问题:**
- 一个大脚本包含所有步骤
- 出错后难以定位问题
- 需要从头重新执行
- 浪费时间和资源

**分步骤方案的优势:**
- ✓ 快速定位问题所在步骤
- ✓ 失败后仅重跑问题步骤
- ✓ 可单独测试某个环节
- ✓ 符合小步快跑理念
- ✓ 提高部署效率

## 部署步骤

```
Step 1: 初始化环境
  └─ 测试连接、收集信息、配置主机名

Step 2: 准备服务器  
  └─ 系统优化、安装依赖、配置内核

Step 3: 安装 Master
  └─ 安装 RKE2 Server、配置 kubectl

Step 4: 安装 Worker
  └─ 安装 RKE2 Agent、加入集群
```

## 快速开始

### 1. 修改配置

```bash
# 修改主机 IP
vim inventories/production/hosts

# 修改集群配置
vim inventories/production/group_vars/all.yml

# 重要: 修改 rke2_token 和 rke2_api_server
```

### 2. 完整部署

```bash
# 方式 1: 使用部署脚本 (推荐)
./deploy.sh

# 方式 2: 手动逐步执行
ansible-playbook playbooks/steps/step1-init-env.yml
ansible-playbook playbooks/steps/step2-prepare-server.yml
ansible-playbook playbooks/steps/step3-install-server.yml
ansible-playbook playbooks/steps/step4-install-agent.yml
```

### 3. 验证集群

```bash
ansible-playbook playbooks/verify-cluster.yml
```

## 分步骤执行

### Step 1: 初始化环境

```bash
ansible-playbook playbooks/steps/step1-init-env.yml
```

**用途:**
- 测试所有节点 SSH 连接
- 收集系统信息 (OS、内核、CPU、内存)
- 配置主机名和 hosts 文件
- 验证节点间网络连通性

**预期结果:**
- 所有节点 ping 通过
- 显示各节点系统信息
- 网络连通性正常

**常见问题:**
- SSH 连接失败 → 检查密钥配置
- 网络不通 → 检查防火墙和路由

---

### Step 2: 准备服务器

```bash
ansible-playbook playbooks/steps/step2-prepare-server.yml
```

**用途:**
- 禁用 swap
- 加载必需内核模块 (overlay, br_netfilter)
- 配置内核参数 (ip_forward, iptables)
- 安装依赖包 (curl, nfs-common, open-iscsi 等)
- 调整系统资源限制

**预期结果:**
- swap 已禁用
- 内核模块已加载
- 软件包安装完成
- 系统参数已优化

**常见问题:**
- apt 更新失败 → 检查网络和源配置
- 内核模块加载失败 → 检查内核版本

---

### Step 3: 安装 Master

```bash
ansible-playbook playbooks/steps/step3-install-server.yml
```

**用途:**
- 创建 RKE2 配置文件
- 下载并安装 RKE2 Server
- 启动 rke2-server 服务
- 配置 kubectl 和环境变量
- 获取 node-token (用于 Worker 加入)

**预期结果:**
- rke2-server 服务运行中
- kubectl 命令可用
- Master 节点 Ready
- node-token 已获取

**验证命令:**
```bash
ssh caiqian@MASTER_IP
sudo systemctl status rke2-server
sudo kubectl get nodes
```

**常见问题:**
- 服务启动失败 → 查看日志 `journalctl -u rke2-server -n 100`
- API 超时 → 检查 6443 端口是否监听
- Token 获取失败 → 等待服务完全启动

---

### Step 4: 安装 Worker

```bash
ansible-playbook playbooks/steps/step4-install-agent.yml
```

**用途:**
- 创建 RKE2 Agent 配置 (使用 Step 3 获取的 token)
- 下载并安装 RKE2 Agent
- 启动 rke2-agent 服务
- Worker 加入集群
- 验证所有节点就绪

**预期结果:**
- 所有 Worker 节点 Ready
- 系统 Pod 运行正常
- 集群完全可用

**验证命令:**
```bash
ssh caiqian@MASTER_IP
sudo kubectl get nodes -o wide
sudo kubectl get pods -A
```

**常见问题:**
- Agent 无法连接 Server → 检查网络和 9345 端口
- Token 错误 → 重新执行 Step 3
- 节点 NotReady → 检查 CNI 插件状态

## 故障恢复

### 从指定步骤重新开始

```bash
# 从 Step 2 重新开始
./deploy.sh --from-step 2

# 从 Step 3 重新开始
./deploy.sh --from-step 3
```

### 单独重跑某个步骤

```bash
# 仅重跑 Step 2
ansible-playbook playbooks/steps/step2-prepare-server.yml

# 仅重跑 Step 3 (Master)
ansible-playbook playbooks/steps/step3-install-server.yml

# 仅重跑某个 Worker
ansible-playbook playbooks/steps/step4-install-agent.yml --limit rke2-worker-01
```

### 查看详细日志

```bash
# 详细模式
ansible-playbook playbooks/steps/step2-prepare-server.yml -vvv

# 逐步执行
ansible-playbook playbooks/steps/step3-install-server.yml --step
```

## 常见故障排查

### 问题 1: Step 1 连接失败

```bash
# 测试单个节点
ansible rke2-master-01 -m ping -vvv

# 手动 SSH 测试
ssh -v caiqian@192.168.1.10

# 解决方案
# 1. 检查 SSH 密钥
# 2. 确认用户名正确
# 3. 验证 IP 地址
```

### 问题 2: Step 2 系统配置失败

```bash
# 检查某个任务
ansible rke2_cluster -m shell -a "swapon --show"
ansible rke2_cluster -m shell -a "lsmod | grep br_netfilter"

# 解决方案
# 1. 手动执行失败的命令
# 2. 检查权限 (sudo)
# 3. 验证系统兼容性
```

### 问题 3: Step 3 Master 启动失败

```bash
# 登录 Master 查看日志
ssh caiqian@MASTER_IP
sudo journalctl -u rke2-server -f

# 检查配置
sudo cat /etc/rancher/rke2/config.yaml

# 检查端口
sudo netstat -tulpn | grep -E '6443|9345'

# 解决方案
# 1. 检查配置文件语法
# 2. 确认端口未被占用
# 3. 查看系统资源是否充足
```

### 问题 4: Step 4 Worker 加入失败

```bash
# 查看 Agent 日志
ssh caiqian@WORKER_IP
sudo journalctl -u rke2-agent -f

# 测试连通性
telnet MASTER_IP 9345

# 检查 token
sudo cat /etc/rancher/rke2/config.yaml

# 解决方案
# 1. 验证 token 正确
# 2. 检查网络连通性
# 3. 确认 Master 的 9345 端口开放
```

## 调试技巧

### 1. 查看任务执行情况

```bash
# 显示所有变量
ansible-inventory --host rke2-master-01 --yaml

# 测试某个模块
ansible rke2_cluster -m setup -a "filter=ansible_distribution*"
```

### 2. 干运行模式

```bash
# 预览执行 (不实际改变系统)
ansible-playbook playbooks/steps/step2-prepare-server.yml --check
```

### 3. 限制执行范围

```bash
# 仅在某个节点执行
ansible-playbook playbooks/steps/step2-prepare-server.yml --limit rke2-worker-01

# 仅在 Master 执行
ansible-playbook playbooks/steps/step3-install-server.yml --limit rke2_servers
```

## 卸载集群

```bash
# 停止所有服务
ansible rke2_servers -m systemd -a "name=rke2-server state=stopped"
ansible rke2_agents -m systemd -a "name=rke2-agent state=stopped"

# 运行卸载脚本
ansible rke2_cluster -m shell -a "/usr/bin/rke2-uninstall.sh"

# 清理残留
ansible rke2_cluster -m file -a "path=/etc/rancher state=absent"
ansible rke2_cluster -m file -a "path=/var/lib/rancher state=absent"
```

## 目录结构

```
.
├── ansible.cfg                         # Ansible 配置
├── inventories/
│   └── production/
│       ├── hosts                       # 主机清单
│       └── group_vars/
│           └── all.yml                 # 全局变量
├── roles/
│   ├── step1-init-env/                # Step 1: 初始化
│   ├── step2-prepare-server/          # Step 2: 准备
│   ├── step3-install-server/          # Step 3: Master
│   └── step4-install-agent/           # Step 4: Worker
├── playbooks/
│   ├── steps/                         # 各步骤 playbook
│   │   ├── step1-init-env.yml
│   │   ├── step2-prepare-server.yml
│   │   ├── step3-install-server.yml
│   │   └── step4-install-agent.yml
│   └── verify-cluster.yml             # 验证脚本
├── deploy.sh                           # 主部署脚本
└── README.md                           # 本文件
```

## 最佳实践

1. **先测试后执行**: 使用 `--check` 模式预览
2. **逐步推进**: 不要跳过步骤
3. **及时验证**: 每步完成后验证结果
4. **保存日志**: 重定向输出到文件
5. **备份配置**: 修改前备份重要文件

## 进阶用法

### 并行部署多个 Worker

```bash
# 修改 ansible.cfg
forks = 3

# 或在命令中指定
ansible-playbook playbooks/steps/step4-install-agent.yml -f 3
```

### 使用 tags 精细控制

可以在 roles 中添加 tags，实现更细粒度的控制。

### 集成 CI/CD

```bash
# GitLab CI 示例
script:
  - ./deploy.sh
```

## 参考资料

- [RKE2 文档](https://docs.rke2.io/)
- [Ansible 最佳实践](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

## 作者

Anthony - DevOps Engineer
基于 15+ 年运维经验总结

## License

MIT
