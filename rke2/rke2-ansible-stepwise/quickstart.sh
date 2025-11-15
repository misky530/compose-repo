#!/bin/bash
# 快速开始向导

cat << 'EOF'
========================================
RKE2 Ansible 分步骤部署 - 快速开始
========================================

这是一个分步骤部署方案，优势:
✓ 快速定位问题
✓ 失败后仅重跑问题步骤  
✓ 提高部署效率

步骤 1: 初始化环境 (测试连接)
步骤 2: 准备服务器 (系统优化)
步骤 3: 安装 Master (RKE2 Server)
步骤 4: 安装 Worker (RKE2 Agent)

========================================
开始配置
========================================
EOF

echo ""
echo "请按照以下步骤配置:"
echo ""

# 1. 配置主机
echo "1. 配置主机清单"
echo "   编辑: inventories/production/hosts"
echo ""
read -p "   按回车继续..."

# 2. 配置变量
echo ""
echo "2. 配置集群参数"
echo "   编辑: inventories/production/group_vars/all.yml"
echo ""
echo "   重要参数:"
echo "   - rke2_token: 使用 'openssl rand -hex 32' 生成"
echo "   - rke2_api_server: 修改为你的 Master IP"
echo ""
read -p "   按回车继续..."

# 3. 测试连接
echo ""
echo "3. 测试 SSH 连接"
echo ""
read -p "   是否测试连接? [y/N] " test_conn

if [ "$test_conn" = "y" ]; then
    if ansible rke2_cluster -m ping; then
        echo "   ✓ 连接测试成功!"
    else
        echo "   ✗ 连接失败，请检查:"
        echo "     - SSH 密钥配置"
        echo "     - inventory 中的 IP 地址"
        echo "     - 目标节点是否可达"
        exit 1
    fi
fi

# 4. 开始部署
echo ""
echo "========================================="
echo "准备开始部署"
echo "========================================="
echo ""
echo "部署方式:"
echo "  1. 自动部署 (推荐): ./deploy.sh"
echo "  2. 使用 Make: make all"
echo "  3. 手动逐步:"
echo "     make step1  # 初始化"
echo "     make step2  # 准备"
echo "     make step3  # Master"
echo "     make step4  # Worker"
echo ""

read -p "是否立即开始部署? [y/N] " start_deploy

if [ "$start_deploy" = "y" ]; then
    ./deploy.sh
else
    echo ""
    echo "配置完成! 准备好后运行:"
    echo "  ./deploy.sh"
    echo ""
fi
EOF
chmod +x /home/claude/rke2-ansible-stepwise/quickstart.sh
