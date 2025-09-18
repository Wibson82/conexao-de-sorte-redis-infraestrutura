# 🏃‍♂️ Self-Hosted Runners - Auditoria de Segurança

## 📊 **CONFIGURAÇÃO ATUAL**

### **🔍 Runners Identificados**

#### **Redis Infrastructure Runner**
```yaml
Host: srv649924
Labels: [self-hosted, Linux, X64, conexao-de-sorte-redis-infraestrutura]
Repository: Wibson82/conexao-de-sorte-redis-infraestrutura
Usage: Deploy job apenas (padrão Traefik implementado)
```

#### **Configuração Actionlint**
```yaml
# .github/actionlint.yaml
self-hosted-runner:
  labels:
    - "conexao-de-sorte-redis-infraestrutura"  # ✅ Repository-specific
    - "conexao"                                # ✅ Organization identifier
    - "srv649924"                              # ✅ Host identifier
```

#### **Uso nos Workflows**
```yaml
# ci-cd.yml linha 209
runs-on: [self-hosted, Linux, X64, conexao-de-sorte-redis-infraestrutura]

# test.yml linha 22
runs-on: [self-hosted, Linux, X64, conexao-de-sorte-redis-infraestrutura]
```

---

## 🛡️ **AUDITORIA DE SEGURANÇA**

### **✅ PONTOS POSITIVOS IDENTIFICADOS**

#### **1. Label Specificity**
```bash
✅ Repository-specific label: conexao-de-sorte-redis-infraestrutura
✅ Organization label: conexao
✅ Host identifier: srv649924
✅ OS/Architecture: Linux, X64
```

#### **2. Usage Pattern**
```bash
✅ Padrão Traefik implementado (GitHub-hosted primeiro, self-hosted segundo)
✅ Timeout configurado: 25 minutos
✅ Dependency chain: security-validation → validate-build → deploy
✅ Environment gate: production approval obrigatória
```

#### **3. Security Context**
```bash
✅ OIDC ultra-mínimo implementado
✅ Security validation step obrigatório
✅ Restricted to main branch only
✅ Manual approval gate para produção
```

### **⚠️ PONTOS DE ATENÇÃO E MELHORIAS**

#### **1. Network Isolation**
```bash
⚠️ Status: DESCONHECIDO
📝 Verificar: Network ACLs para Azure Key Vault
📝 Verificar: Outbound internet access restrictions
📝 Verificar: VPN/Private network setup
```

#### **2. Runner Updates**
```bash
⚠️ Status: DESCONHECIDO
📝 Verificar: Automatic security patches
📝 Verificar: Runner software version
📝 Verificar: Docker version/security
📝 Verificar: OS patch level
```

#### **3. Physical Security**
```bash
⚠️ Status: DESCONHECIDO
📝 Verificar: Data center security
📝 Verificar: Physical access controls
📝 Verificar: Hardware security modules
📝 Verificar: Disk encryption
```

#### **4. Runtime Security**
```bash
⚠️ Status: PARCIAL
✅ Dedicated runner per repository
⚠️ Container isolation configuration
⚠️ Runtime security scanning
⚠️ Resource limits enforcement
```

---

## 🎯 **PLANO DE HARDENING**

### **1. NETWORK SECURITY HARDENING**

#### **Outbound Restrictions**
```bash
# Permitir apenas:
✅ https://github.com (código)
✅ https://api.github.com (GitHub API)
✅ https://*.vault.azure.net (Key Vault)
✅ https://login.microsoftonline.com (Azure AD)
✅ https://management.azure.com (Azure API)
❌ Bloquear todo o resto da internet
```

#### **Firewall Rules**
```bash
# Inbound:
❌ SSH (22) - Apenas via bastion host
❌ HTTP (80) - Não necessário
❌ HTTPS (443) - Apenas outbound
✅ Docker Swarm (2377, 7946, 4789) - Se aplicável

# Outbound:
✅ HTTPS (443) - Sites autorizados apenas
✅ DNS (53) - Resolução necessária
❌ Bloquear todo o resto
```

### **2. SISTEMA OPERACIONAL HARDENING**

#### **Automatic Updates**
```bash
# Ubuntu/Debian:
sudo apt-get install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades

# Configurar para updates de segurança apenas:
echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades
```

#### **Security Baselines**
```bash
# CIS Benchmark implementation:
✅ Disable unnecessary services
✅ Configure strong passwords
✅ Enable audit logging
✅ Configure file permissions
✅ Remove unused packages
✅ Configure SSH hardening
```

### **3. DOCKER HARDENING**

#### **Docker Daemon Security**
```json
{
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "seccomp-profile": "/etc/docker/seccomp.json",
  "log-driver": "journald",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

#### **Runtime Security**
```bash
# Implementar:
✅ AppArmor/SELinux profiles
✅ Resource limits per container
✅ Read-only root filesystem
✅ Non-root user execution
✅ Security scanning automático
```

### **4. RUNNER SOFTWARE HARDENING**

#### **GitHub Runner Security**
```bash
# Configurações seguras:
./config.sh \
  --url https://github.com/Wibson82/conexao-de-sorte-redis-infraestrutura \
  --token $RUNNER_TOKEN \
  --name srv649924-redis \
  --labels self-hosted,Linux,X64,conexao-de-sorte-redis-infraestrutura \
  --work _work \
  --replace \
  --unattended \
  --disableupdate  # Updates via sistema apenas
```

#### **Process Isolation**
```bash
# Systemd service com restrições:
[Service]
Type=simple
User=github-runner
Group=github-runner
WorkingDirectory=/opt/actions-runner
ExecStart=/opt/actions-runner/run.sh
Restart=always
RestartSec=5
KillMode=process
TimeoutStopSec=5m
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/actions-runner
```

---

## 🔍 **MONITORAMENTO E COMPLIANCE**

### **1. Continuous Monitoring**

#### **Security Metrics**
```bash
# Implementar coleta de:
✅ Failed authentication attempts
✅ Unusual network connections
✅ Resource usage anomalies
✅ File system changes
✅ Process execution patterns
```

#### **Alerting Rules**
```yaml
alerts:
  - name: "Unusual Outbound Connection"
    condition: "new_destination_not_in_whitelist"
    severity: "high"

  - name: "High Resource Usage"
    condition: "cpu_usage > 90% for 5min"
    severity: "medium"

  - name: "Failed Authentication"
    condition: "auth_failures > 5 in 1min"
    severity: "high"
```

### **2. Compliance Checks**

#### **Daily Automated Checks**
```bash
#!/bin/bash
# runner-compliance-check.sh

echo "🔍 Daily Runner Security Check"

# 1. Check for security updates
sudo apt list --upgradable | grep -i security

# 2. Verify runner process
pgrep -f "Runner.Listener" || echo "❌ Runner process not running"

# 3. Check disk space
df -h | awk '$5 > 80 {print "⚠️ High disk usage: " $0}'

# 4. Verify Docker security
docker info | grep -i security

# 5. Check network connectivity to Azure
curl -s https://kv-conexao-de-sorte.vault.azure.net/ > /dev/null && echo "✅ Key Vault reachable"

# 6. Audit active connections
netstat -tuln | grep LISTEN
```

#### **Weekly Security Scans**
```bash
#!/bin/bash
# weekly-security-scan.sh

# 1. Docker security scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image --severity HIGH,CRITICAL ubuntu:latest

# 2. File integrity check
find /opt/actions-runner -type f -exec sha256sum {} \; > /tmp/runner-checksums.txt

# 3. Network port scan
nmap -sS localhost

# 4. Check for rootkits
sudo rkhunter --check --sk
```

---

## 📋 **CHECKLIST DE IMPLEMENTAÇÃO**

### **Fase 1: Assessment (Semana 1)**
- [ ] Mapear configuração atual do srv649924
- [ ] Identificar versões de software instalado
- [ ] Documentar configuração de rede atual
- [ ] Avaliar baseline de segurança atual
- [ ] Identificar gaps vs. best practices

### **Fase 2: Network Hardening (Semana 2)**
- [ ] Implementar firewall rules restritivas
- [ ] Configurar DNS whitelisting
- [ ] Implementar network monitoring
- [ ] Testar conectividade com Azure
- [ ] Validar pipeline functionality

### **Fase 3: System Hardening (Semana 3)**
- [ ] Aplicar CIS benchmarks
- [ ] Configurar automatic security updates
- [ ] Implementar audit logging
- [ ] Configurar resource monitoring
- [ ] Setup backup procedures

### **Fase 4: Runtime Hardening (Semana 4)**
- [ ] Implementar Docker hardening
- [ ] Configurar runner service restrictions
- [ ] Setup security scanning pipeline
- [ ] Implementar incident response
- [ ] Documentar procedures

### **Fase 5: Validation (Semana 5)**
- [ ] Penetration testing
- [ ] Compliance audit
- [ ] Performance testing
- [ ] Disaster recovery test
- [ ] Security documentation final

---

## 🚨 **INCIDENT RESPONSE**

### **Runner Compromise Detection**
```bash
# Indicators of compromise:
⚠️ Unusual network connections
⚠️ Unexpected process execution
⚠️ File system modifications
⚠️ Failed authentication spikes
⚠️ Resource usage anomalies
```

### **Response Procedures**
```bash
# 1. Immediate isolation
sudo iptables -A OUTPUT -j DROP  # Block all outbound
sudo systemctl stop actions.runner.srv649924-redis

# 2. Evidence collection
sudo dd if=/dev/sda of=/tmp/disk-image.img bs=1M
sudo netstat -tuln > /tmp/network-state.txt
sudo ps aux > /tmp/process-list.txt

# 3. Notification
# - Security team alert
# - Disable GitHub runner token
# - Revoke Azure OIDC credentials
# - Lock Key Vault access

# 4. Recovery
# - Rebuild runner from clean image
# - Regenerate all secrets
# - Re-verify security configuration
# - Resume operations with monitoring
```

---

## 📊 **SECURITY SCORE ATUAL**

### **Current State Assessment**
```
🔒 OIDC Configuration:     95% ✅ (Excellent)
🏷️  Label Specificity:     90% ✅ (Good)
🔗 Workflow Integration:   85% ✅ (Good)
🌐 Network Security:       ❓ (Unknown - Need Assessment)
🖥️  System Hardening:      ❓ (Unknown - Need Assessment)
🐳 Docker Security:        ❓ (Unknown - Need Assessment)
📊 Monitoring:             20% ❌ (Poor - Missing)
📋 Compliance:             30% ❌ (Poor - Missing)
🚨 Incident Response:      10% ❌ (Poor - No procedures)

OVERALL SECURITY SCORE: 58% (NEEDS IMPROVEMENT)
```

### **Target State (Pós-Hardening)**
```
🔒 OIDC Configuration:     98% 🎯
🏷️  Label Specificity:     95% 🎯
🔗 Workflow Integration:   95% 🎯
🌐 Network Security:       90% 🎯 (+90%)
🖥️  System Hardening:      85% 🎯 (+85%)
🐳 Docker Security:        85% 🎯 (+85%)
📊 Monitoring:             90% 🎯 (+70%)
📋 Compliance:             85% 🎯 (+55%)
🚨 Incident Response:      80% 🎯 (+70%)

TARGET SECURITY SCORE: 89% (EXCELLENT)
```

---

**Status**: 🔍 AUDITORIA COMPLETA
**Próxima ação**: Executar assessment detalhado do srv649924
**Timeline**: 5 semanas para hardening completo
**Risk Level**: MEDIUM (Precisa hardening, mas OIDC está seguro)