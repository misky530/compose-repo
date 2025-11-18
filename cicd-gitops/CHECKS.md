# 自动化检查脚本说明

本仓库包含三个自动化检查脚本，帮助验证部署状态。

## 脚本列表

### 1. pre-deployment-check.sh - 部署前验证

**用途：** 在部署前检查所有配置是否正确

**运行时机：** 在执行任何 kubectl apply 之前

**检查项：**
- Git 仓库配置
- ArgoCD Application 的 repoURL
- Drone RPC Secret 是否已修改
- 必需文件是否存在
- Kubernetes 集群连接
- ArgoCD 是否已部署

**使用方法：**
```bash
./pre-deployment-check.sh
```

**输出示例：**
```
======================================
  部署前配置验证
======================================

1. 检查 Git 仓库配置
✓ Git remote 已配置: https://github.com/yourusername/cicd-gitops.git

2. 检查 ArgoCD Application 配置
✓ Gitea: repoURL 已配置
✓ Drone: repoURL 已配置

3. 检查 Drone Secret 配置
✓ DRONE_RPC_SECRET 已修改

...

======================================
验证结果总结
======================================
✓ 所有检查通过！可以开始部署
```

---

### 2. quick-check.sh - 快速状态检查

**用途：** 快速查看所有组件的运行状态

**运行时机：** 随时，用于快速了解当前状态

**检查项：**
- ArgoCD 状态和访问地址
- Gitea 状态和访问地址
- Drone 状态和访问地址
- 资源使用情况
- ArgoCD Application 同步状态

**使用方法：**
```bash
./quick-check.sh
```

**输出示例：**
```
======================================
  GitOps 快速状态检查
======================================

[ArgoCD]
✓ 状态: 运行中 (7/7 pods)
  访问: https://192.168.23.135:31234

[Gitea]
✓ 状态: 运行中 (1/1 pods, PVC已绑定)
  Web UI: http://192.168.23.135:30300
  SSH Git: ssh://git@192.168.23.135:30022
  ArgoCD: Synced / Healthy

[Drone]
✓ 状态: 运行中 (2/2 pods)
  访问: http://192.168.23.135:30080
  ArgoCD: Synced / Healthy

[资源使用]
NAME             CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
rke2-worker-01   234m         11%    1456Mi          74%
rke2-worker-02   189m         9%     1289Mi          66%
rke2-worker-03   201m         10%    1367Mi          69%
```

---

### 3. check-deployment.sh - 完整部署检查

**用途：** 详细检查所有组件的部署状态，包括资源使用、健康状态等

**运行时机：** 部署后验证，或排查问题时使用

**检查项：**
- 所有快速检查的内容
- Pod 详细状态和调度信息
- Service 配置
- PVC 绑定状态
- 资源使用详情
- 配置验证（如 Drone Secret）

**使用方法：**
```bash
./check-deployment.sh
```

**输出示例：**
```
======================================
  GitOps 部署状态检查脚本
======================================

1. 检查依赖命令
================================================
✓ kubectl 命令可用

2. 检查集群连接
================================================
✓ 集群连接正常
NAME             STATUS   ROLES                       AGE
rke2-master-01   Ready    control-plane,etcd,master   1d
rke2-worker-01   Ready    <none>                      1d
rke2-worker-02   Ready    <none>                      1d
rke2-worker-03   Ready    <none>                      1d

3. 检查 ArgoCD
================================================
✓ ArgoCD 命名空间存在
检查 ArgoCD Pod 状态...
✓ 找到 7 个 Pod
✓ 所有 Pod 都在运行中
NAME                                               READY   STATUS
argocd-application-controller-0                    1/1     Running
argocd-server-xxx                                  1/1     Running
...

4. 检查 Gitea
================================================
✓ Gitea 命名空间存在
检查 ArgoCD Application: gitea
✓ Application gitea 存在
  同步状态: Synced
  健康状态: Healthy
✓ Application 状态正常

检查 PVC: gitea-data
✓ PVC gitea-data 已绑定
...
```

---

## 使用建议

### 首次部署流程

```bash
# 1. 修改配置后，运行部署前检查
./pre-deployment-check.sh

# 2. 如果检查通过，提交并推送到 Git
git add .
git commit -m "Configure for production"
git push

# 3. 部署 ArgoCD（如果还没部署）
kubectl apply -k bootstrap/argocd/

# 4. 部署 Gitea
kubectl apply -f infrastructure/argocd-apps/gitea.yaml

# 5. 等待几分钟后，运行快速检查
./quick-check.sh

# 6. 如果有问题，运行完整检查查看详情
./check-deployment.sh
```

### 日常维护

```bash
# 每天快速检查状态
./quick-check.sh

# 如果发现问题，运行完整检查
./check-deployment.sh
```

### 故障排查

```bash
# 1. 运行完整检查，查看详细错误
./check-deployment.sh

# 2. 查看特定组件的日志
kubectl logs -f deployment/gitea -n gitea
kubectl logs -f deployment/drone-server -n drone

# 3. 查看 ArgoCD Application 状态
kubectl describe application gitea -n argocd

# 4. 手动触发同步
kubectl patch application gitea -n argocd \
  --type merge \
  --patch '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

---

## 常见问题

### Q: pre-deployment-check.sh 报错 "Git remote 未配置"

**A:** 运行以下命令配置 Git remote：
```bash
git remote add origin https://github.com/yourusername/cicd-gitops.git
```

### Q: check-deployment.sh 显示 "metrics-server 未安装"

**A:** 这是正常的。metrics-server 是可选组件，不影响核心功能。如果需要安装：
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Q: quick-check.sh 显示 Pod 数量不匹配

**A:** 可能是 Pod 正在启动或重启。等待几分钟后重新检查：
```bash
kubectl get pods -n <namespace> -w  # 监控 Pod 状态
```

### Q: Drone RPC Secret 警告

**A:** 生成并更新 Secret：
```bash
# 生成密钥
openssl rand -hex 16

# 编辑文件
vim infrastructure/drone/overlays/production/secret-patch.yaml

# 提交并推送
git add .
git commit -m "Update Drone RPC Secret"
git push

# ArgoCD 会自动同步（或手动触发）
```

---

## 脚本退出码

所有脚本遵循标准退出码：

- **0**: 成功，无错误
- **1**: 发现错误，需要修复

可以在自动化脚本中使用：
```bash
if ./pre-deployment-check.sh; then
    echo "检查通过，继续部署"
    kubectl apply -f infrastructure/argocd-apps/gitea.yaml
else
    echo "检查失败，请修复配置"
    exit 1
fi
```
