#!/bin/bash

# 部署前配置验证脚本
# 检查所有必需的配置是否已修改

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${BLUE}"
echo "======================================"
echo "  部署前配置验证"
echo "======================================"
echo -e "${NC}"

# 检查 Git 配置
echo -e "${YELLOW}1. 检查 Git 仓库配置${NC}"
if [ -d ".git" ]; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -z "$REMOTE_URL" ]; then
        echo -e "${RED}✗ Git remote 未配置${NC}"
        echo "  请运行: git remote add origin <your-repo-url>"
        ((ERRORS++))
    elif [[ "$REMOTE_URL" == *"your-username"* ]] || [[ "$REMOTE_URL" == *"example"* ]]; then
        echo -e "${RED}✗ Git remote 仍是示例地址: $REMOTE_URL${NC}"
        echo "  请修改为实际仓库地址"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ Git remote 已配置: $REMOTE_URL${NC}"
    fi
else
    echo -e "${RED}✗ 不是 Git 仓库${NC}"
    echo "  请运行: git init"
    ((ERRORS++))
fi
echo ""

# 检查 ArgoCD Application 配置
echo -e "${YELLOW}2. 检查 ArgoCD Application 配置${NC}"

check_app_config() {
    local file=$1
    local app_name=$2
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ 文件不存在: $file${NC}"
        ((ERRORS++))
        return
    fi
    
    # 检查 repoURL
    local repo_url=$(grep "repoURL:" "$file" | head -1 | awk '{print $2}')
    if [[ "$repo_url" == *"your-username"* ]] || [[ "$repo_url" == *"example"* ]]; then
        echo -e "${RED}✗ $app_name: repoURL 未修改 ($repo_url)${NC}"
        echo "  请编辑: $file"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ $app_name: repoURL 已配置${NC}"
    fi
}

check_app_config "infrastructure/argocd-apps/gitea.yaml" "Gitea"
check_app_config "infrastructure/argocd-apps/drone.yaml" "Drone"
echo ""

# 检查 Drone Secret
echo -e "${YELLOW}3. 检查 Drone Secret 配置${NC}"
DRONE_SECRET_FILE="infrastructure/drone/overlays/production/secret-patch.yaml"

if [ ! -f "$DRONE_SECRET_FILE" ]; then
    echo -e "${RED}✗ Drone Secret 文件不存在${NC}"
    ((ERRORS++))
else
    # 检查 RPC Secret
    if grep -q "PLEASE-CHANGE-ME" "$DRONE_SECRET_FILE" || grep -q "change-me-to-random" "$DRONE_SECRET_FILE"; then
        echo -e "${RED}✗ DRONE_RPC_SECRET 未修改${NC}"
        echo "  生成密钥: openssl rand -hex 16"
        echo "  编辑文件: $DRONE_SECRET_FILE"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ DRONE_RPC_SECRET 已修改${NC}"
    fi
    
    # 检查是否配置了 Git OAuth（可选）
    if ! grep -q "DRONE_GITEA_CLIENT_ID" "$DRONE_SECRET_FILE" && \
       ! grep -q "DRONE_GITHUB_CLIENT_ID" "$DRONE_SECRET_FILE" && \
       ! grep -q "DRONE_GITLAB_CLIENT_ID" "$DRONE_SECRET_FILE"; then
        echo -e "${YELLOW}⚠ 未配置 Git OAuth（可以稍后配置）${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓ Git OAuth 已配置${NC}"
    fi
fi
echo ""

# 检查 Gitea 配置
echo -e "${YELLOW}4. 检查 Gitea 配置${NC}"
GITEA_CONFIG_FILE="infrastructure/gitea/overlays/production/configmap-patch.yaml"

if [ ! -f "$GITEA_CONFIG_FILE" ]; then
    echo -e "${YELLOW}⚠ Gitea 配置文件不存在（使用默认配置）${NC}"
    ((WARNINGS++))
else
    # 检查域名配置
    if grep -q "localhost" "$GITEA_CONFIG_FILE" || grep -q "example.com" "$GITEA_CONFIG_FILE"; then
        echo -e "${YELLOW}⚠ Gitea 域名仍是示例值${NC}"
        echo "  建议修改为实际 IP: 192.168.23.135"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓ Gitea 域名已配置${NC}"
    fi
fi
echo ""

# 检查必需文件
echo -e "${YELLOW}5. 检查必需文件${NC}"
REQUIRED_FILES=(
    "bootstrap/argocd/kustomization.yaml"
    "infrastructure/gitea/base/kustomization.yaml"
    "infrastructure/drone/base/kustomization.yaml"
    "infrastructure/argocd-apps/gitea.yaml"
    "infrastructure/argocd-apps/drone.yaml"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ 缺少文件: $file${NC}"
        ((ERRORS++))
    fi
done

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有必需文件都存在${NC}"
fi
echo ""

# 检查 Kubernetes 连接
echo -e "${YELLOW}6. 检查 Kubernetes 连接${NC}"
if kubectl cluster-info &> /dev/null; then
    echo -e "${GREEN}✓ 可以连接到 Kubernetes 集群${NC}"
    
    # 检查节点
    NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    echo -e "${GREEN}✓ 找到 $NODE_COUNT 个节点${NC}"
    
    # 检查 ArgoCD 是否已部署
    if kubectl get namespace argocd &> /dev/null; then
        echo -e "${GREEN}✓ ArgoCD 已部署${NC}"
    else
        echo -e "${YELLOW}⚠ ArgoCD 未部署${NC}"
        echo "  请先运行: kubectl apply -k bootstrap/argocd/"
        ((WARNINGS++))
    fi
else
    echo -e "${RED}✗ 无法连接到 Kubernetes 集群${NC}"
    ((ERRORS++))
fi
echo ""

# 总结
echo "======================================"
echo -e "${BLUE}验证结果总结${NC}"
echo "======================================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ 所有检查通过！可以开始部署${NC}"
    echo ""
    echo -e "${YELLOW}下一步操作:${NC}"
    echo "1. 提交并推送配置到 Git:"
    echo "   git add ."
    echo "   git commit -m 'Ready for deployment'"
    echo "   git push"
    echo ""
    echo "2. 部署 Gitea:"
    echo "   kubectl apply -f infrastructure/argocd-apps/gitea.yaml"
    echo ""
    echo "3. 等待 Gitea 就绪并完成初始配置"
    echo ""
    echo "4. 部署 Drone:"
    echo "   kubectl apply -f infrastructure/argocd-apps/drone.yaml"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ 有 $WARNINGS 个警告，但可以继续部署${NC}"
    exit 0
else
    echo -e "${RED}✗ 发现 $ERRORS 个错误，请修复后再部署${NC}"
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ 另有 $WARNINGS 个警告${NC}"
    fi
    exit 1
fi
