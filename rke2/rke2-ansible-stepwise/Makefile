.PHONY: help step1 step2 step3 step4 verify all clean

help:
	@echo "RKE2 分步骤部署 - 快捷命令"
	@echo ""
	@echo "完整部署:"
	@echo "  make all        - 执行完整部署流程"
	@echo ""
	@echo "分步执行:"
	@echo "  make step1      - Step 1: 初始化环境"
	@echo "  make step2      - Step 2: 准备服务器"
	@echo "  make step3      - Step 3: 安装 Master"
	@echo "  make step4      - Step 4: 安装 Worker"
	@echo ""
	@echo "验证和清理:"
	@echo "  make verify     - 验证集群状态"
	@echo "  make clean      - 卸载集群"
	@echo ""

step1:
	@echo "执行 Step 1: 初始化环境..."
	ansible-playbook playbooks/steps/step1-init-env.yml

step2:
	@echo "执行 Step 2: 准备服务器..."
	ansible-playbook playbooks/steps/step2-prepare-server.yml

step3:
	@echo "执行 Step 3: 安装 Master..."
	ansible-playbook playbooks/steps/step3-install-server.yml

step4:
	@echo "执行 Step 4: 安装 Worker..."
	ansible-playbook playbooks/steps/step4-install-agent.yml

verify:
	@echo "验证集群状态..."
	ansible-playbook playbooks/verify-cluster.yml

all:
	@echo "开始完整部署..."
	./deploy.sh

clean:
	@echo "警告: 即将卸载集群!"
	@read -p "确认继续? [y/N] " confirm; \
	if [ "$$confirm" = "y" ]; then \
		ansible rke2_servers -m systemd -a "name=rke2-server state=stopped" || true; \
		ansible rke2_agents -m systemd -a "name=rke2-agent state=stopped" || true; \
		ansible rke2_cluster -m shell -a "/usr/bin/rke2-uninstall.sh" || true; \
		ansible rke2_cluster -m file -a "path=/etc/rancher state=absent"; \
		ansible rke2_cluster -m file -a "path=/var/lib/rancher state=absent"; \
		echo "集群已卸载"; \
	fi
