#!/bin/bash
# RKE2 Ansible 分步骤部署 - 目录结构创建
# Step 0: 创建项目结构

set -e

PROJECT_NAME="rke2-ansible"
PROJECT_DIR="${1:-$PROJECT_NAME}"

echo "=========================================="
echo "Step 0: 创建 RKE2 Ansible 项目结构"
echo "=========================================="

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# 创建目录
mkdir -p inventories/production/group_vars
mkdir -p roles/step1-init-env/tasks
mkdir -p roles/step2-prepare-server/tasks
mkdir -p roles/step3-install-server/tasks
mkdir -p roles/step4-install-agent/tasks
mkdir -p playbooks/steps
mkdir -p scripts

echo "✓ 目录结构创建完成"
echo "✓ 项目路径: $(pwd)"
