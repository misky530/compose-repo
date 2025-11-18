# Gitea - Production 配置

轻量级的自托管 Git 服务。

## 资源配置

- **内存**: 256Mi request, 512Mi limit
- **存储**: 5Gi PVC（可根据需要调整）
- **数据库**: SQLite（无需额外数据库）

## 访问方式

部署后可以通过以下方式访问：

### Web UI
```
http://192.168.23.135:30300
http://192.168.23.136:30300
http://192.168.23.137:30300
```

### SSH Git 操作
```bash
# Clone 仓库示例
git clone ssh://git@192.168.23.135:30022/username/repo.git

# 添加 SSH Key
# 1. 生成密钥: ssh-keygen -t rsa -b 4096
# 2. 在 Gitea Web UI: 设置 → SSH/GPG 密钥 → 添加密钥
```

## 首次安装配置

### 1. 访问 Gitea Web UI

首次访问会进入安装向导：http://192.168.23.135:30300/install

### 2. 安装配置建议

**数据库设置：**
- 数据库类型: SQLite3 ✅（已配置，无需修改）
- 路径: /data/gitea/gitea.db

**一般设置：**
- 网站标题: 自定义
- 仓库根目录: /data/git/repositories（已配置）
- Git LFS 根目录: /data/git/lfs（已配置）

**服务器和第三方设置：**
- SSH 服务器域名: 192.168.23.135
- SSH 端口: 30022
- Gitea HTTP 端口: 3000
- Gitea 基础 URL: http://192.168.23.135:30300/

**管理员账号：**
- 管理员用户名: admin（推荐）
- 密码: 设置强密码
- 邮箱: admin@example.com

### 3. 完成安装

点击"立即安装"，等待几秒钟，完成后会自动跳转到首页。

## 配置 Drone CI 集成

### 1. 在 Gitea 创建 OAuth 应用

1. 登录 Gitea（管理员账号）
2. 右上角头像 → 设置 → 应用 → 管理 OAuth2 应用程序
3. 点击"创建新的 OAuth2 应用程序"

**配置如下：**
```
应用名称: Drone CI
重定向 URI: http://192.168.23.135:30080/login
```

4. 创建后，复制 **客户端 ID** 和 **客户端密钥**

### 2. 更新 Drone 配置

编辑 `infrastructure/drone/base/configmap.yaml`，添加：
```yaml
DRONE_GITEA_SERVER: "http://192.168.23.135:30300"
DRONE_GITEA_CLIENT_ID: "<刚才复制的客户端ID>"
DRONE_GITEA_CLIENT_SECRET: "<刚才复制的客户端密钥>"
```

编辑 `infrastructure/drone/overlays/production/secret-patch.yaml`，添加：
```yaml
DRONE_GITEA_CLIENT_ID: "your-client-id"
DRONE_GITEA_CLIENT_SECRET: "your-client-secret"
```

### 3. 重新部署 Drone

通过 ArgoCD 同步 Drone Application，或者：
```bash
kubectl rollout restart deployment/drone-server -n drone
```

## 存储说明

Gitea 使用 PVC 持久化数据，包括：
- Git 仓库
- SQLite 数据库
- 用户上传的文件
- LFS 对象

### 检查存储使用

```bash
# 查看 PVC 状态
kubectl get pvc -n gitea

# 查看存储使用情况（需要进入 Pod）
kubectl exec -it deployment/gitea -n gitea -- du -sh /data
```

### 如果需要扩容

编辑 `base/pvc.yaml`，修改 storage 大小：
```yaml
storage: 10Gi  # 从 5Gi 改为 10Gi
```

## 验证部署

```bash
# 查看 Pod 状态
kubectl get pods -n gitea

# 查看 Service
kubectl get svc -n gitea

# 查看日志
kubectl logs -f deployment/gitea -n gitea

# 查看 PVC
kubectl get pvc -n gitea
```

## 故障排查

### Pod 一直 Pending

可能是 PVC 无法绑定，检查：
```bash
kubectl describe pvc gitea-data -n gitea
```

如果集群没有动态 PV 供应，需要手动创建 PV 或使用 hostPath（测试环境）。

### 无法访问 Web UI

检查 Service 和 Pod：
```bash
kubectl get svc,pods -n gitea
kubectl logs deployment/gitea -n gitea
```

### SSH Clone 失败

确认 SSH 端口配置：
```bash
# 测试 SSH 连接
ssh -T git@192.168.23.135 -p 30022
```

## 备份建议

定期备份 `/data` 目录内容：
```bash
# 在 Pod 内执行
kubectl exec deployment/gitea -n gitea -- tar czf /tmp/backup.tar.gz /data

# 复制到本地
kubectl cp gitea/gitea-xxx:/tmp/backup.tar.gz ./gitea-backup-$(date +%Y%m%d).tar.gz
```
