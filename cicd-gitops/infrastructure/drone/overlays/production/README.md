# Drone CI - Production 配置

这是 Drone CI 的生产环境配置。

## 部署前的必要配置

### 1. 生成 RPC Secret

```bash
# 生成随机密钥
openssl rand -hex 16

# 将生成的值填入 secret-patch.yaml 的 DRONE_RPC_SECRET
```

### 2. 修改 ConfigMap（如果需要）

如果你需要使用 Git 服务（GitHub/GitLab/Gitea），需要修改 `base/configmap.yaml`：

```yaml
# 示例：使用 Gitea
DRONE_GITEA_SERVER: "https://your-gitea-server.com"

# 示例：使用 GitHub
# DRONE_GITHUB_SERVER: "https://github.com"

# 示例：使用 GitLab
# DRONE_GITLAB_SERVER: "https://gitlab.com"
```

### 3. 配置 OAuth（如果使用 Git 服务）

在你的 Git 服务中创建 OAuth 应用，然后将 Client ID 和 Secret 填入 `secret-patch.yaml`。

**Gitea OAuth 配置示例：**
1. 登录 Gitea
2. 设置 → 应用 → 管理 OAuth2 应用程序
3. 创建新应用
   - 应用名称: Drone CI
   - 重定向 URI: `http://192.168.23.135:30080/login`
4. 复制 Client ID 和 Client Secret 到 secret-patch.yaml

## 访问方式

部署后，可以通过以下方式访问 Drone：

### NodePort（当前配置）
```
http://192.168.23.135:30080
或
http://192.168.23.136:30080
或
http://192.168.23.137:30080
```

### 如果想改用 Ingress（生产环境推荐）

创建 `ingress.yaml`：
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: drone-server
  namespace: drone
spec:
  rules:
  - host: drone.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: drone-server
            port:
              number: 80
```

然后修改 `kustomization.yaml`，添加：
```yaml
resources:
  - ingress.yaml
```

## 部署（通过 ArgoCD）

不要手动部署！应该通过 ArgoCD Application 来部署。

请继续下一步：创建 ArgoCD Application 定义。

## 验证部署

```bash
# 查看 Pod 状态
kubectl get pods -n drone

# 查看 Service
kubectl get svc -n drone

# 查看日志
kubectl logs -f deployment/drone-server -n drone
kubectl logs -f deployment/drone-runner-kube -n drone
```

## 故障排查

### Drone Server 无法启动

```bash
# 查看详细信息
kubectl describe pod -n drone -l app=drone-server

# 查看日志
kubectl logs -n drone -l app=drone-server
```

### Drone Runner 无法连接 Server

检查 RPC Secret 是否一致：
```bash
kubectl get secret drone-secret -n drone -o yaml
```

### 无法访问 Drone UI

检查 NodePort：
```bash
kubectl get svc drone-server -n drone
```
