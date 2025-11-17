#!/bin/bash

set -e

echo "=========================================="
echo "SSH 免密登录完整修复脚本"
echo "=========================================="

# 配置
HOSTS=("192.168.23.132" "192.168.23.135" "192.168.23.136" "192.168.23.137")
HOST_NAMES=("rke2-master-01" "rke2-worker-01" "rke2-worker-02" "rke2-worker-03")
USER="caiqian"
SSH_KEY="$HOME/.ssh/id_ed25519"

echo ""
echo "步骤 1: 检查 SSH 密钥"
echo "----------------------------------------"
if [ -f "$SSH_KEY" ]; then
    echo "✅ SSH 密钥存在: $SSH_KEY"
    ls -l "$SSH_KEY" "$SSH_KEY.pub"
else
    echo "❌ SSH 密钥不存在，正在生成..."
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N ""
    echo "✅ SSH 密钥已生成"
fi

echo ""
echo "步骤 2: 复制公钥到所有节点"
echo "----------------------------------------"
echo "注意：需要输入每个节点的密码"
echo ""

for i in "${!HOSTS[@]}"; do
    host="${HOSTS[$i]}"
    name="${HOST_NAMES[$i]}"
    
    echo "----------------------------------------"
    echo "配置 $name ($host)"
    echo "请输入密码："
    
    # 先测试能否连接
    if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$SSH_KEY" "$USER@$host" exit 2>/dev/null; then
        echo "✅ $name 已经配置免密登录"
    else
        # 需要复制公钥
        ssh-copy-id -i "$SSH_KEY.pub" "$USER@$host"
        
        if [ $? -eq 0 ]; then
            echo "✅ $name 公钥复制成功"
        else
            echo "❌ $name 公钥复制失败"
            exit 1
        fi
    fi
done

echo ""
echo "步骤 3: 验证 SSH 免密登录"
echo "----------------------------------------"
all_ssh_ok=true
for i in "${!HOSTS[@]}"; do
    host="${HOSTS[$i]}"
    name="${HOST_NAMES[$i]}"
    
    if ssh -o ConnectTimeout=5 -o BatchMode=yes -i "$SSH_KEY" "$USER@$host" "hostname" 2>/dev/null; then
        echo "✅ $name - SSH 免密登录正常"
    else
        echo "❌ $name - SSH 免密登录失败"
        all_ssh_ok=false
    fi
done

if [ "$all_ssh_ok" = false ]; then
    echo ""
    echo "❌ SSH 配置失败，请检查错误"
    exit 1
fi

echo ""
echo "步骤 4: 配置 sudo 免密码"
echo "----------------------------------------"
for i in "${!HOSTS[@]}"; do
    host="${HOSTS[$i]}"
    name="${HOST_NAMES[$i]}"
    
    echo "配置 $name sudo 免密码..."
    ssh -i "$SSH_KEY" "$USER@$host" "echo '$USER ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/$USER >/dev/null && sudo chmod 0440 /etc/sudoers.d/$USER"
    
    if [ $? -eq 0 ]; then
        # 验证 sudo
        if ssh -i "$SSH_KEY" "$USER@$host" "sudo whoami" 2>/dev/null | grep -q "root"; then
            echo "✅ $name sudo 免密码配置成功"
        else
            echo "⚠️  $name sudo 验证失败"
        fi
    else
        echo "❌ $name sudo 配置失败"
    fi
done

echo ""
echo "步骤 5: 更新 Ansible 配置"
echo "----------------------------------------"
cd ~/cai/rke2/compose-repo/rke2/rke2-ansible-stepwise

# 修复所有配置文件中的密钥路径
find . -type f \( -name "*.cfg" -o -name "hosts" -o -name "inventory.ini" \) -exec sed -i 's|id_rsa|id_ed25519|g' {} \;

echo "✅ Ansible 配置已更新"

echo ""
echo "步骤 6: 测试 Ansible 连接"
echo "----------------------------------------"
if ansible all -m ping; then
    echo ""
    echo "=========================================="
    echo "✅ 所有配置完成！"
    echo "=========================================="
    echo ""
    echo "可以开始部署了："
    echo "  cd ~/cai/rke2/compose-repo/rke2/rke2-ansible-stepwise"
    echo "  ansible-playbook playbooks/steps/step1-init-env.yml"
    echo ""
else
    echo ""
    echo "❌ Ansible 测试失败，请检查错误"
    exit 1
fi
