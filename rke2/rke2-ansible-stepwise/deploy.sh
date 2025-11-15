#!/bin/bash
# RKE2 分步骤部署主脚本

set -e

SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 函数: 打印步骤标题
print_step() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
}

# 函数: 打印错误
print_error() {
    echo -e "${RED}❌ 错误: $1${NC}"
}

# 函数: 打印警告
print_warning() {
    echo -e "${YELLOW}⚠️  警告: $1${NC}"
}

# 函数: 打印成功
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 函数: 执行步骤
run_step() {
    local step_num=$1
    local step_name=$2
    local playbook=$3
    
    print_step "Step $step_num: $step_name"
    
    if ansible-playbook "$playbook"; then
        print_success "Step $step_num 完成"
        return 0
    else
        print_error "Step $step_num 失败"
        echo ""
        echo "失败的步骤: Step $step_num - $step_name"
        echo "Playbook: $playbook"
        echo ""
        echo "故障排查建议:"
        echo "1. 查看详细日志: ansible-playbook $playbook -vvv"
        echo "2. 检查目标节点状态"
        echo "3. 修复问题后重新运行: ./deploy.sh --from-step $step_num"
        echo ""
        return 1
    fi
}

# 解析参数
START_STEP=1
if [ "$1" == "--from-step" ] && [ -n "$2" ]; then
    START_STEP=$2
    print_warning "从 Step $START_STEP 开始执行"
fi

# 显示部署信息
echo ""
echo "=========================================="
echo "RKE2 Kubernetes 集群分步骤部署"
echo "=========================================="
echo ""
echo "部署计划:"
echo "  Step 1: 初始化环境 (测试连接、收集信息)"
echo "  Step 2: 准备服务器 (系统优化、安装依赖)"
echo "  Step 3: 安装 Master (RKE2 Server)"
echo "  Step 4: 安装 Worker (RKE2 Agent)"
echo ""
echo "目标节点:"
echo "  Master: $(grep -A1 '\[rke2_servers\]' inventories/production/hosts | tail -1 | awk '{print $2}' | cut -d= -f2)"
echo "  Workers: $(grep -A3 '\[rke2_agents\]' inventories/production/hosts | tail -3 | awk '{print $2}' | cut -d= -f2 | tr '\n' ' ')"
echo ""

# 确认继续
read -p "是否继续? [y/N] " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "部署已取消"
    exit 0
fi

# 执行步骤
if [ $START_STEP -le 1 ]; then
    run_step 1 "初始化环境" "playbooks/steps/step1-init-env.yml" || exit 1
fi

if [ $START_STEP -le 2 ]; then
    run_step 2 "准备服务器" "playbooks/steps/step2-prepare-server.yml" || exit 1
fi

if [ $START_STEP -le 3 ]; then
    run_step 3 "安装 Master" "playbooks/steps/step3-install-server.yml" || exit 1
fi

if [ $START_STEP -le 4 ]; then
    run_step 4 "安装 Worker" "playbooks/steps/step4-install-agent.yml" || exit 1
fi

# 部署完成
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 部署完成!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "验证集群:"
echo "  ansible-playbook playbooks/verify-cluster.yml"
echo ""
echo "或者直接登录 Master 查看:"
echo "  ssh caiqian@MASTER_IP"
echo "  sudo kubectl get nodes"
echo "  sudo kubectl get pods -A"
echo ""
