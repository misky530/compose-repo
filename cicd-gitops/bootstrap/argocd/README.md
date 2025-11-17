# ArgoCD 引导部署

这是唯一需要**手动部署**的部分。部署后，所有其他资源都通过 ArgoCD 管理。

## 资源配置说明

所有组件已针对你的 2GB Worker 节点优化：

| 组件 | Request Memory | Limit Memory | 说明 |
|------|---------------|--------------|------|
| argocd-server | 128Mi | 256Mi | Web UI 和 API 服务器 |
| argocd-repo-server | 128Mi | 256Mi | Git 仓库管理 |
| argocd-application-controller | 256Mi | 512Mi | 应用同步控制器（最重要） |
| argocd-redis | 64Mi | 128Mi | 缓存服务 |
| argocd-dex-server | 64Mi | 128Mi | SSO 认证 |
| **总计** | **~640Mi** | **~1280Mi** | 适合 2GB 节点 |

## 部署步骤

### 1. 预检查

```bash
# 确认集群连接
kubectl get nodes

# 确认 Worker 节点资源
kubectl top nodes
```

### 2. 部署 ArgoCD

```bash
# 从仓库根目录执行
kubectl apply -k bootstrap/argocd/
```

### 3. 等待就绪

```bash
# 等待所有 Pod 启动（大约 2-3 分钟）
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# 查看部署状态
kubectl get pods -n argocd
```

### 4. 获取初始密码

```bash
# 获取 admin 用户的初始密码
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

**重要：** 请保存这个密码，首次登录后建议立即修改。

### 5. 访问 ArgoCD UI

#### 方式一：端口转发（推荐用于测试）

```bash
# 转发到本地 8080 端口
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 访问 https://localhost:8080
# 用户名: admin
# 密码: 上一步获取的密码
```

#### 方式二：NodePort（推荐用于持续使用）

```bash
# 修改 Service 类型为 NodePort
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'

# 获取 NodePort
kubectl get svc argocd-server -n argocd

# 访问 https://<任意节点IP>:<NodePort>
# 例如: https://192.168.23.135:31234
```

### 6. 安装 ArgoCD CLI（可选但推荐）

```bash
# Linux x86_64
curl -sSL -o /usr/local/bin/argocd \
  https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# 登录
argocd login <ARGOCD_SERVER> --username admin --password <密码>

# 修改密码
argocd account update-password
```

## 验证部署

```bash
# 检查所有 Pod 状态
kubectl get pods -n argocd

# 检查资源使用
kubectl top pods -n argocd

# 检查 Pod 调度到了哪些节点（应该都在 Worker 节点）
kubectl get pods -n argocd -o wide
```

预期输出：所有 Pod 应该都调度到 `rke2-worker-01/02/03`，而不是 `rke2-master-01`。

## 故障排查

### Pod 无法启动

```bash
# 查看 Pod 详情
kubectl describe pod <pod-name> -n argocd

# 查看日志
kubectl logs <pod-name> -n argocd
```

### 内存不足

如果 Worker 节点内存不足，可以进一步降低资源限制：

```bash
# 编辑 patches/argocd-*-resources.yaml 文件
# 将 requests 和 limits 都降低 20-30%
```

### 访问 UI 时证书警告

ArgoCD 默认使用自签名证书，浏览器会警告，这是正常的。点击"继续访问"即可。

## 下一步

ArgoCD 部署成功后，进入 `infrastructure/argocd-apps/` 目录，部署其他组件。
