#!/bin/bash

# GitOps 部署检查脚本
# 用于验证 ArgoCD + Gitea + Drone 部署状态

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：打印分隔线
print_separator() {
    echo -e "${BLUE}================================================${NC}"
}

# 函数：检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ $1 命令未找到，请先安装${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ $1 命令可用${NC}"
    return 0
}

# 函数：检查 Pod 状态
check_pods() {
    local namespace=$1
    local app_name=$2
    
    echo -e "${YELLOW}检查 $app_name Pod 状态...${NC}"
    
    # 获取 Pod 数量
    local pod_count=$(kubectl get pods -n $namespace --no-headers 2>/dev/null | wc -l)
    
    if [ $pod_count -eq 0 ]; then
        echo -e "${RED}✗ 命名空间 $namespace 中没有找到 Pod${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ 找到 $pod_count 个 Pod${NC}"
    
    # 检查 Pod 状态
    local not_running=$(kubectl get pods -n $namespace --no-headers 2>/dev/null | grep -v "Running" | grep -v "Completed" | wc -l)
    
    if [ $not_running -gt 0 ]; then
        echo -e "${RED}✗ 有 $not_running 个 Pod 未处于 Running 状态${NC}"
        kubectl get pods -n $namespace
        return 1
    fi
    
    echo -e "${GREEN}✓ 所有 Pod 都在运行中${NC}"
    
    # 显示 Pod 列表
    kubectl get pods -n $namespace -o wide
    
    return 0
}

# 函数：检查 Service
check_service() {
    local namespace=$1
    local service_name=$2
    local expected_port=$3
    
    echo -e "${YELLOW}检查 Service: $service_name${NC}"
    
    if ! kubectl get svc $service_name -n $namespace &> /dev/null; then
        echo -e "${RED}✗ Service $service_name 不存在${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Service $service_name 存在${NC}"
    
    # 获取 NodePort
    local nodeport=$(kubectl get svc $service_name -n $namespace -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null)
    
    if [ -n "$nodeport" ]; then
        echo -e "${GREEN}✓ NodePort: $nodeport${NC}"
        if [ -n "$expected_port" ] && [ "$nodeport" != "$expected_port" ]; then
            echo -e "${YELLOW}⚠ 预期端口 $expected_port，实际端口 $nodeport${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Service 不是 NodePort 类型${NC}"
    fi
    
    return 0
}

# 函数：检查资源使用
check_resources() {
    local namespace=$1
    
    echo -e "${YELLOW}检查资源使用情况...${NC}"
    
    if kubectl top nodes &> /dev/null; then
        echo -e "${GREEN}✓ Node 资源使用:${NC}"
        kubectl top nodes
        echo ""
        
        echo -e "${GREEN}✓ Pod 资源使用 ($namespace):${NC}"
        kubectl top pods -n $namespace 2>/dev/null || echo -e "${YELLOW}⚠ metrics-server 未安装，无法查看资源使用${NC}"
    else
        echo -e "${YELLOW}⚠ kubectl top 不可用，可能 metrics-server 未安装${NC}"
    fi
    
    return 0
}

# 函数：检查 ArgoCD Application
check_argocd_app() {
    local app_name=$1
    
    echo -e "${YELLOW}检查 ArgoCD Application: $app_name${NC}"
    
    if ! kubectl get application $app_name -n argocd &> /dev/null; then
        echo -e "${RED}✗ Application $app_name 不存在${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Application $app_name 存在${NC}"
    
    # 检查同步状态
    local sync_status=$(kubectl get application $app_name -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
    local health_status=$(kubectl get application $app_name -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
    
    echo -e "  同步状态: ${sync_status}"
    echo -e "  健康状态: ${health_status}"
    
    if [ "$sync_status" == "Synced" ] && [ "$health_status" == "Healthy" ]; then
        echo -e "${GREEN}✓ Application 状态正常${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Application 状态异常${NC}"
        return 1
    fi
}

# 函数：检查 PVC
check_pvc() {
    local namespace=$1
    local pvc_name=$2
    
    echo -e "${YELLOW}检查 PVC: $pvc_name${NC}"
    
    if ! kubectl get pvc $pvc_name -n $namespace &> /dev/null; then
        echo -e "${RED}✗ PVC $pvc_name 不存在${NC}"
        return 1
    fi
    
    local status=$(kubectl get pvc $pvc_name -n $namespace -o jsonpath='{.status.phase}' 2>/dev/null)
    
    if [ "$status" == "Bound" ]; then
        echo -e "${GREEN}✓ PVC $pvc_name 已绑定${NC}"
        kubectl get pvc $pvc_name -n $namespace
        return 0
    else
        echo -e "${RED}✗ PVC $pvc_name 状态: $status${NC}"
        kubectl describe pvc $pvc_name -n $namespace
        return 1
    fi
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "======================================"
    echo "  GitOps 部署状态检查脚本"
    echo "======================================"
    echo -e "${NC}"
    
    # 检查依赖命令
    print_separator
    echo -e "${BLUE}1. 检查依赖命令${NC}"
    print_separator
    check_command kubectl || exit 1
    
    # 检查集群连接
    print_separator
    echo -e "${BLUE}2. 检查集群连接${NC}"
    print_separator
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✓ 集群连接正常${NC}"
        kubectl get nodes
    else
        echo -e "${RED}✗ 无法连接到集群${NC}"
        exit 1
    fi
    
    # 检查 ArgoCD
    print_separator
    echo -e "${BLUE}3. 检查 ArgoCD${NC}"
    print_separator
    if kubectl get namespace argocd &> /dev/null; then
        echo -e "${GREEN}✓ ArgoCD 命名空间存在${NC}"
        check_pods "argocd" "ArgoCD"
        check_resources "argocd"
        
        # 检查 ArgoCD Service
        if kubectl get svc argocd-server -n argocd &> /dev/null; then
            local argocd_nodeport=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null)
            if [ -n "$argocd_nodeport" ]; then
                echo -e "${GREEN}✓ ArgoCD UI 访问地址: https://192.168.23.135:$argocd_nodeport${NC}"
            else
                echo -e "${YELLOW}⚠ ArgoCD Service 不是 NodePort 类型${NC}"
                echo -e "  请运行: kubectl patch svc argocd-server -n argocd -p '{\"spec\": {\"type\": \"NodePort\"}}'"
            fi
        fi
    else
        echo -e "${RED}✗ ArgoCD 未部署${NC}"
        echo -e "  请运行: kubectl apply -k bootstrap/argocd/"
    fi
    
    # 检查 Gitea
    print_separator
    echo -e "${BLUE}4. 检查 Gitea${NC}"
    print_separator
    if kubectl get namespace gitea &> /dev/null; then
        echo -e "${GREEN}✓ Gitea 命名空间存在${NC}"
        
        # 检查 ArgoCD Application
        check_argocd_app "gitea"
        
        # 检查 PVC
        check_pvc "gitea" "gitea-data"
        
        # 检查 Pods
        check_pods "gitea" "Gitea"
        
        # 检查 Services
        check_service "gitea" "gitea-http" "30300"
        check_service "gitea" "gitea-ssh" "30022"
        
        # 检查资源使用
        check_resources "gitea"
        
        echo ""
        echo -e "${GREEN}✓ Gitea 访问地址:${NC}"
        echo -e "  Web UI: http://192.168.23.135:30300"
        echo -e "  SSH Git: ssh://git@192.168.23.135:30022"
    else
        echo -e "${YELLOW}⚠ Gitea 未部署${NC}"
        echo -e "  请运行: kubectl apply -f infrastructure/argocd-apps/gitea.yaml"
    fi
    
    # 检查 Drone
    print_separator
    echo -e "${BLUE}5. 检查 Drone${NC}"
    print_separator
    if kubectl get namespace drone &> /dev/null; then
        echo -e "${GREEN}✓ Drone 命名空间存在${NC}"
        
        # 检查 ArgoCD Application
        check_argocd_app "drone"
        
        # 检查 Pods
        check_pods "drone" "Drone"
        
        # 检查 Service
        check_service "drone" "drone-server" "30080"
        
        # 检查资源使用
        check_resources "drone"
        
        # 检查 Secret 是否配置
        local rpc_secret=$(kubectl get secret drone-secret -n drone -o jsonpath='{.data.DRONE_RPC_SECRET}' 2>/dev/null | base64 -d 2>/dev/null)
        if [ "$rpc_secret" == "PLEASE-CHANGE-ME-TO-RANDOM-32-CHARS" ] || [ "$rpc_secret" == "change-me-to-random-string-32-chars" ]; then
            echo -e "${RED}✗ Drone RPC Secret 未修改，请更新配置${NC}"
            echo -e "  生成密钥: openssl rand -hex 16"
            echo -e "  编辑文件: infrastructure/drone/overlays/production/secret-patch.yaml"
        else
            echo -e "${GREEN}✓ Drone RPC Secret 已配置${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}✓ Drone 访问地址: http://192.168.23.135:30080${NC}"
    else
        echo -e "${YELLOW}⚠ Drone 未部署${NC}"
        echo -e "  请先部署 Gitea 并配置 OAuth"
        echo -e "  然后运行: kubectl apply -f infrastructure/argocd-apps/drone.yaml"
    fi
    
    # 总体资源摘要
    print_separator
    echo -e "${BLUE}6. 集群资源总览${NC}"
    print_separator
    echo -e "${YELLOW}Node 资源使用:${NC}"
    kubectl top nodes 2>/dev/null || echo -e "${YELLOW}⚠ metrics-server 未安装${NC}"
    
    echo ""
    echo -e "${YELLOW}所有命名空间的 Pod:${NC}"
    kubectl get pods --all-namespaces -o wide | grep -E "argocd|gitea|drone"
    
    # 最终总结
    print_separator
    echo -e "${BLUE}7. 部署检查总结${NC}"
    print_separator
    
    local argocd_ok=0
    local gitea_ok=0
    local drone_ok=0
    
    kubectl get namespace argocd &> /dev/null && argocd_ok=1
    kubectl get namespace gitea &> /dev/null && gitea_ok=1
    kubectl get namespace drone &> /dev/null && drone_ok=1
    
    echo -e "ArgoCD: $([ $argocd_ok -eq 1 ] && echo -e "${GREEN}✓ 已部署${NC}" || echo -e "${RED}✗ 未部署${NC}")"
    echo -e "Gitea:  $([ $gitea_ok -eq 1 ] && echo -e "${GREEN}✓ 已部署${NC}" || echo -e "${YELLOW}⚠ 未部署${NC}")"
    echo -e "Drone:  $([ $drone_ok -eq 1 ] && echo -e "${GREEN}✓ 已部署${NC}" || echo -e "${YELLOW}⚠ 未部署${NC}")"
    
    echo ""
    echo -e "${BLUE}检查完成！${NC}"
    
    if [ $argocd_ok -eq 1 ] && [ $gitea_ok -eq 1 ] && [ $drone_ok -eq 1 ]; then
        echo -e "${GREEN}🎉 所有组件都已部署！${NC}"
        echo ""
        echo -e "${YELLOW}下一步操作:${NC}"
        echo -e "1. 访问 Gitea 完成初始化: http://192.168.23.135:30300"
        echo -e "2. 在 Gitea 中创建 OAuth 应用"
        echo -e "3. 更新 Drone 配置并重新同步"
        echo -e "4. 访问 Drone: http://192.168.23.135:30080"
    else
        echo -e "${YELLOW}⚠ 部分组件未部署，请按照文档继续部署${NC}"
    fi
}

# 执行主函数
main "$@"
