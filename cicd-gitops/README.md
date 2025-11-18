# RKE2 Kubernetes GitOps Repository

基于 **ArgoCD + Kustomize** 的完整 GitOps 配置仓库，用于管理 RKE2 Kubernetes 集群上的所有资源。

## 🎯 项目目标

- ✅ 完全的基础设施即代码（Infrastructure as Code）
- ✅ Git 作为唯一事实来源
- ✅ 自动化部署和同步
- ✅ 完整的变更历史和审计
- ✅ 简单的回滚机制

## 📁 仓库结构

```
cicd-gitops/
├── bootstrap/              # 引导配置（首次手动部署）
│   └── argocd/            # ArgoCD 安装配置
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       └── patches/       # 资源优化补丁
│
├── infrastructure/         # 基础设施层（由 ArgoCD 管理）
│   ├── argocd-apps/       # ArgoCD Application 定义
│   │   ├── drone-app.yaml
│   │   └── demo-app.yaml
│   └── drone/             # Drone CI/CD
│       ├── base/
│       └── overlays/
│           └── production/
│
└── applications/          # 应用层（由 ArgoCD 管理）
    └── demo-app/          # 示例应用
        ├── base/
        └── overlays/
            └── production/
```

## 🖥️ 集群信息

- **Kubernetes**: v1.28.5+rke2r1
- **节点配置**:
  - Master: 1 节点 × 4GB (192.168.23.132)
  - Worker: 3 节点 × 2GB (192.168.23.135-137)
- **容器运行时**: containerd 1.7.11
- **所有配置已针对 2GB 内存优化**

## 🚀 快速开始

### 前置条件

- ✅ RKE2 集群已运行
- ✅ kubectl 已配置
- ✅ Git 客户端已安装

### 部署步骤

#### 第一步：部署 ArgoCD（仅首次，手动部署）

```bash
# 1. 克隆仓库
git clone https://github.com/YOUR_USERNAME/cicd-gitops.git
cd cicd-gitops

# 2. 部署 ArgoCD
kubectl apply -k bootstrap/argocd/

# 3. 等待 ArgoCD 就绪（约 2-3 分钟）
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# 4. 查看部署状态
kubectl get pods -n argocd -o wide
```

#### 第二步：获取 ArgoCD 密码并登录

```bash
# 获取 admin 初始密码
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# 端口转发访问 UI（临时）
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 或改为 NodePort（持久）
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
kubectl get svc argocd-server -n argocd

# 访问 https://localhost:8080 或 https://192.168.23.135:<NodePort>
# 用户名: admin
# 密码: 上一步获取的密码
```

#### 第三步：配置 Git 仓库并部署应用

```bash
# 1. 修改所有 ArgoCD Application 文件中的 repoURL
# 文件位置：infrastructure/argocd-apps/*.yaml
# 将 repoURL 改为你的实际仓库地址

# 2. 生成 Drone RPC Secret
openssl rand -hex 32

# 3. 修改 Drone 配置
vim infrastructure/drone/overlays/production/kustomization.yaml
# 将 DRONE_RPC_SECRET 改为上一步生成的值

# 4. 提交配置到 Git
git add .
git commit -m "configure repository and secrets"
git push

# 5. 部署 ArgoCD Applications
kubectl apply -f infrastructure/argocd-apps/

# 6. 查看应用状态
kubectl get applications -n argocd
watch kubectl get pods -A
```

## 📊 资源占用

| 组件 | 命名空间 | Request | Limit | 说明 |
|------|---------|---------|-------|------|
| ArgoCD | argocd | ~640Mi | ~1280Mi | GitOps 引擎 |
| Drone Server | drone | 128Mi | 256Mi | CI/CD Server |
| Drone Runner | drone | 128Mi | 512Mi | CI/CD Runner (2副本) |
| Demo App | demo | 64Mi | 256Mi | 示例应用 (2副本) |
| **总计** | - | **~960Mi** | **~2.3GB** | 适合你的集群 |

## 🔄 GitOps 工作流

```
┌─────────────────────────────────────────────────────────┐
│  开发者                                                  │
│  ├── 修改 YAML 配置文件                                 │
│  ├── git commit & push                                  │
│  └── 配置变更推送到 Git 仓库                            │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│  ArgoCD                                                  │
│  ├── 自动检测 Git 仓库变化（每 3 分钟）                 │
│  ├── 对比期望状态 vs 实际状态                           │
│  ├── 渲染 Kustomize 配置                                │
│  └── 自动同步到 Kubernetes                              │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│  Kubernetes Cluster                                      │
│  ├── 应用新配置                                         │
│  ├── 滚动更新 Pod                                       │
│  └── 运行最新版本                                       │
└─────────────────────────────────────────────────────────┘
```

## 💡 使用示例

### 更新应用副本数

```bash
# 1. 编辑配置文件
vim applications/demo-app/overlays/production/replica-patch.yaml
# 将 replicas 改为 3

# 2. 提交变更
git add .
git commit -m "scale demo-app to 3 replicas"
git push

# 3. ArgoCD 自动同步（或手动触发）
kubectl argo app sync demo-app -n argocd

# 4. 验证
kubectl get pods -n demo
```

### 部署新应用

```bash
# 1. 复制示例应用作为模板
cp -r applications/demo-app applications/my-app

# 2. 修改配置
# - 修改镜像
# - 修改资源限制
# - 修改 Service 端口等

# 3. 创建 ArgoCD Application
cp infrastructure/argocd-apps/demo-app.yaml infrastructure/argocd-apps/my-app.yaml
# 修改 name, path, namespace

# 4. 提交并部署
git add .
git commit -m "add my-app"
git push

kubectl apply -f infrastructure/argocd-apps/my-app.yaml
```

### 回滚变更

```bash
# 方式一：Git 回滚
git revert <commit-hash>
git push
# ArgoCD 自动同步回滚后的版本

# 方式二：ArgoCD UI 回滚
# 在 UI 中选择应用 → History → 选择历史版本 → Rollback

# 方式三：kubectl 回滚
kubectl argo app rollback demo-app <revision> -n argocd
```

## 🔍 常用命令

### ArgoCD

```bash
# 查看所有应用
kubectl get applications -n argocd

# 查看应用详情
kubectl argo app get <app-name> -n argocd

# 手动同步
kubectl argo app sync <app-name> -n argocd

# 查看同步状态
kubectl argo app list

# 查看差异
kubectl argo app diff <app-name> -n argocd
```

### Drone

```bash
# 查看 Drone 状态
kubectl get pods -n drone

# 访问 Drone UI
kubectl port-forward svc/drone-server -n drone 8081:80

# 查看 Runner 日志
kubectl logs -n drone -l app=drone-runner-kube
```

### 通用

```bash
# 查看所有 Pod
kubectl get pods -A

# 查看资源使用
kubectl top nodes
kubectl top pods -A

# 查看事件
kubectl get events -A --sort-by='.lastTimestamp'
```

## 📚 文档

- [ArgoCD 部署文档](bootstrap/argocd/README.md)
- [Drone CI 配置文档](infrastructure/drone/README.md)
- [ArgoCD Applications 说明](infrastructure/argocd-apps/README.md)

## 🛠️ 故障排查

### ArgoCD 应用 OutOfSync

```bash
# 查看差异
kubectl argo app diff <app-name> -n argocd

# 手动同步
kubectl argo app sync <app-name> -n argocd

# 查看同步失败原因
kubectl get application <app-name> -n argocd -o yaml | grep -A 20 status
```

### Pod 无法启动

```bash
# 查看 Pod 详情
kubectl describe pod <pod-name> -n <namespace>

# 查看日志
kubectl logs <pod-name> -n <namespace>

# 查看事件
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### 资源不足

```bash
# 查看节点资源
kubectl top nodes
kubectl describe nodes

# 查看 Pod 资源使用
kubectl top pods -A

# 调整资源限制
# 编辑对应的 *-resources.yaml 文件
# 降低 requests 和 limits
```

## 🔐 安全建议

1. ✅ 修改 ArgoCD admin 初始密码
2. ✅ 使用强随机的 DRONE_RPC_SECRET
3. ✅ 定期轮换密钥
4. ✅ 使用私有 Git 仓库
5. ✅ 配置 RBAC 限制权限
6. ✅ 使用 Ingress TLS 加密通信

## 📈 下一步

- [ ] 配置 Ingress Controller（Traefik/Nginx）
- [ ] 集成 Git 平台（GitHub/GitLab）到 Drone
- [ ] 配置 Drone Webhook 自动触发构建
- [ ] 添加监控（Prometheus + Grafana）
- [ ] 配置日志收集（Loki）
- [ ] 实现多环境部署（dev/staging/prod）

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📝 许可证

MIT License
