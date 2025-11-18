# ArgoCD Applications

这个目录包含 ArgoCD Application 定义，用于管理基础设施组件。

## 应用列表

- **gitea.yaml**: Gitea Git 服务
- **drone.yaml**: Drone CI/CD 服务

## 部署前的准备

### 1. 将配置推送到 Git 仓库

```bash
# 初始化 Git 仓库（如果还没有）
cd cicd-gitops
git init
git add .
git commit -m "Initial commit: ArgoCD + Gitea + Drone"

# 添加远程仓库并推送
git remote add origin https://github.com/your-username/cicd-gitops.git
git branch -M main
git push -u origin main
```

### 2. 修改 Application 配置

编辑以下文件，将 `repoURL` 修改为你的实际 Git 仓库地址：
- `infrastructure/argocd-apps/gitea.yaml`
- `infrastructure/argocd-apps/drone.yaml`

```yaml
source:
  repoURL: https://github.com/your-username/cicd-gitops.git  # 修改这里
  targetRevision: main
```

### 3. 修改敏感配置

**Drone Secret（必须修改）：**
```bash
# 生成 RPC Secret
openssl rand -hex 16

# 编辑文件
vim infrastructure/drone/overlays/production/secret-patch.yaml
# 将生成的值填入 DRONE_RPC_SECRET
```

**Gitea 配置（可选）：**
```bash
# 如果需要修改域名或端口
vim infrastructure/gitea/overlays/production/configmap-patch.yaml
```

## 部署步骤

### 方式一：通过 ArgoCD UI（推荐）

1. 登录 ArgoCD UI
2. 点击 "NEW APP"
3. 填写信息：
   - Application Name: gitea
   - Project: default
   - Sync Policy: Automatic
   - Repository URL: 你的 Git 仓库地址
   - Path: infrastructure/gitea/overlays/production
   - Cluster: https://kubernetes.default.svc
   - Namespace: gitea
4. 点击 "CREATE"
5. 重复上述步骤创建 Drone Application

### 方式二：通过 kubectl（快速）

```bash
# 部署 Gitea
kubectl apply -f infrastructure/argocd-apps/gitea.yaml

# 部署 Drone
kubectl apply -f infrastructure/argocd-apps/drone.yaml

# 查看 Application 状态
kubectl get applications -n argocd

# 查看详细信息
kubectl describe application gitea -n argocd
kubectl describe application drone -n argocd
```

### 方式三：通过 ArgoCD CLI

```bash
# 部署 Gitea
argocd app create gitea \
  --repo https://github.com/your-username/cicd-gitops.git \
  --path infrastructure/gitea/overlays/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace gitea \
  --sync-policy automated \
  --self-heal \
  --auto-prune

# 部署 Drone
argocd app create drone \
  --repo https://github.com/your-username/cicd-gitops.git \
  --path infrastructure/drone/overlays/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace drone \
  --sync-policy automated \
  --self-heal \
  --auto-prune
```

## 部署顺序建议

1. **先部署 Gitea**（Drone 依赖 Gitea）
   ```bash
   kubectl apply -f infrastructure/argocd-apps/gitea.yaml
   ```

2. **等待 Gitea 就绪**
   ```bash
   kubectl wait --for=condition=Ready pods --all -n gitea --timeout=300s
   ```

3. **配置 Gitea**
   - 访问 http://192.168.23.135:30300
   - 完成初始安装向导
   - 创建 OAuth 应用（用于 Drone）

4. **更新 Drone 配置**
   - 将 Gitea OAuth 信息填入 Drone Secret
   - Git commit + push

5. **部署 Drone**
   ```bash
   kubectl apply -f infrastructure/argocd-apps/drone.yaml
   ```

## 监控部署状态

### 查看 ArgoCD Applications

```bash
# 列出所有应用
kubectl get applications -n argocd

# 查看应用详情
kubectl get application gitea -n argocd -o yaml
kubectl get application drone -n argocd -o yaml
```

### 查看同步状态

在 ArgoCD UI 中：
- 绿色勾号：同步成功
- 黄色圆圈：正在同步
- 红色叉号：同步失败

### 手动同步

```bash
# 通过 kubectl
kubectl patch application gitea -n argocd \
  --type merge \
  --patch '{"operation": {"initiatedBy": {"username": "admin"}, "sync": {}}}'

# 或通过 ArgoCD CLI
argocd app sync gitea
argocd app sync drone
```

## GitOps 工作流

从现在开始，所有变更都通过 Git：

```bash
# 1. 修改配置
vim infrastructure/gitea/overlays/production/configmap-patch.yaml

# 2. 提交变更
git add .
git commit -m "Update Gitea configuration"
git push

# 3. ArgoCD 会自动检测并同步（默认 3 分钟检查一次）
# 或者手动触发同步
argocd app sync gitea
```

## 故障排查

### Application 一直 OutOfSync

```bash
# 查看差异
argocd app diff gitea

# 手动同步
argocd app sync gitea --force
```

### Application 同步失败

```bash
# 查看详细错误
kubectl describe application gitea -n argocd

# 查看 ArgoCD 日志
kubectl logs -n argocd deployment/argocd-application-controller
```

### 删除 Application（谨慎）

```bash
# 删除 Application（会删除所有相关资源）
kubectl delete application gitea -n argocd

# 如果要保留资源，先移除 finalizer
kubectl patch application gitea -n argocd \
  --type json \
  --patch='[{"op": "remove", "path": "/metadata/finalizers"}]'
```

## 访问服务

部署成功后：

- **Gitea**: http://192.168.23.135:30300
- **Drone**: http://192.168.23.135:30080
- **ArgoCD**: http://192.168.23.135:<argocd-nodeport>
