#!/bin/bash

# GitOps 快速状态检查
# 显示所有组件的快速概览

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "  GitOps 快速状态检查"
echo "======================================"
echo ""

# ArgoCD
echo -e "${YELLOW}[ArgoCD]${NC}"
if kubectl get namespace argocd &> /dev/null; then
    ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
    ARGOCD_RUNNING=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c "Running")
    ARGOCD_NODEPORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' 2>/dev/null)
    
    if [ "$ARGOCD_PODS" -eq "$ARGOCD_RUNNING" ]; then
        echo -e "${GREEN}✓${NC} 状态: 运行中 ($ARGOCD_RUNNING/$ARGOCD_PODS pods)"
    else
        echo -e "${RED}✗${NC} 状态: 异常 ($ARGOCD_RUNNING/$ARGOCD_PODS pods running)"
    fi
    
    if [ -n "$ARGOCD_NODEPORT" ]; then
        echo "  访问: https://192.168.23.135:$ARGOCD_NODEPORT"
    else
        echo "  访问: ClusterIP (需要配置 NodePort)"
    fi
else
    echo -e "${RED}✗${NC} 未部署"
fi
echo ""

# Gitea
echo -e "${YELLOW}[Gitea]${NC}"
if kubectl get namespace gitea &> /dev/null; then
    GITEA_PODS=$(kubectl get pods -n gitea --no-headers 2>/dev/null | wc -l)
    GITEA_RUNNING=$(kubectl get pods -n gitea --no-headers 2>/dev/null | grep -c "Running")
    GITEA_PVC=$(kubectl get pvc -n gitea --no-headers 2>/dev/null | grep -c "Bound")
    
    if [ "$GITEA_PODS" -eq "$GITEA_RUNNING" ] && [ "$GITEA_PVC" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} 状态: 运行中 ($GITEA_RUNNING/$GITEA_PODS pods, PVC已绑定)"
    elif [ "$GITEA_PODS" -eq "$GITEA_RUNNING" ]; then
        echo -e "${YELLOW}⚠${NC} 状态: 运行中但PVC未绑定 ($GITEA_RUNNING/$GITEA_PODS pods)"
    else
        echo -e "${RED}✗${NC} 状态: 异常 ($GITEA_RUNNING/$GITEA_PODS pods running)"
    fi
    
    echo "  Web UI: http://192.168.23.135:30300"
    echo "  SSH Git: ssh://git@192.168.23.135:30022"
    
    # 检查 ArgoCD App
    if kubectl get application gitea -n argocd &> /dev/null; then
        SYNC=$(kubectl get application gitea -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
        HEALTH=$(kubectl get application gitea -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
        echo "  ArgoCD: $SYNC / $HEALTH"
    fi
else
    echo -e "${YELLOW}⚠${NC} 未部署"
fi
echo ""

# Drone
echo -e "${YELLOW}[Drone]${NC}"
if kubectl get namespace drone &> /dev/null; then
    DRONE_PODS=$(kubectl get pods -n drone --no-headers 2>/dev/null | wc -l)
    DRONE_RUNNING=$(kubectl get pods -n drone --no-headers 2>/dev/null | grep -c "Running")
    
    if [ "$DRONE_PODS" -eq "$DRONE_RUNNING" ]; then
        echo -e "${GREEN}✓${NC} 状态: 运行中 ($DRONE_RUNNING/$DRONE_PODS pods)"
    else
        echo -e "${RED}✗${NC} 状态: 异常 ($DRONE_RUNNING/$DRONE_PODS pods running)"
    fi
    
    echo "  访问: http://192.168.23.135:30080"
    
    # 检查 ArgoCD App
    if kubectl get application drone -n argocd &> /dev/null; then
        SYNC=$(kubectl get application drone -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null)
        HEALTH=$(kubectl get application drone -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null)
        echo "  ArgoCD: $SYNC / $HEALTH"
    fi
    
    # 检查 Secret
    RPC_SECRET=$(kubectl get secret drone-secret -n drone -o jsonpath='{.data.DRONE_RPC_SECRET}' 2>/dev/null | base64 -d 2>/dev/null)
    if [ "$RPC_SECRET" == "PLEASE-CHANGE-ME-TO-RANDOM-32-CHARS" ] || [ "$RPC_SECRET" == "change-me-to-random-string-32-chars" ]; then
        echo -e "  ${RED}⚠ RPC Secret 需要修改${NC}"
    fi
else
    echo -e "${YELLOW}⚠${NC} 未部署"
fi
echo ""

# 资源使用
echo -e "${YELLOW}[资源使用]${NC}"
if kubectl top nodes &> /dev/null; then
    kubectl top nodes | awk 'NR==1 || /worker/ {print}'
else
    echo "  metrics-server 未安装"
fi
echo ""

# 快速命令提示
echo "======================================"
echo -e "${YELLOW}快速命令:${NC}"
echo "  查看所有 Pod:  kubectl get pods -A | grep -E 'argocd|gitea|drone'"
echo "  查看日志:      kubectl logs -f deployment/<name> -n <namespace>"
echo "  重新同步:      kubectl patch app <name> -n argocd --type merge -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/refresh\":\"hard\"}}}'"
echo "  完整检查:      ./check-deployment.sh"
echo "======================================"
