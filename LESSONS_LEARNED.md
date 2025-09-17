# 📚 Lições Aprendidas - Redis Infrastructure

## 🎯 **LIÇÃO CRÍTICA: Padrão de Jobs GitHub Actions**

### ❌ **Problema Identificado**
Workflows que usam `self-hosted` runners desde o primeiro job ficam em **queue infinito**.

### ✅ **Solução: Padrão Traefik**

**Estrutura Correta (2 Jobs):**

```yaml
jobs:
  # JOB 1: GitHub-hosted (sempre disponível)
  validate-and-build:
    runs-on: ubuntu-latest  # ← CRÍTICO: GitHub-hosted
    steps:
      - name: Validação e Build
      - name: Security Scan
      - name: Upload Artifacts

  # JOB 2: Self-hosted (apenas para deploy)
  deploy-production:
    needs: validate-and-build  # ← CRÍTICO: Dependency
    runs-on: [self-hosted, Linux, X64, srv649924, conexao, conexao-de-sorte-redis-infraestrutura]
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy para produção
```

### 🔍 **Por que Funciona:**
1. **Job 1** executa no GitHub (sempre disponível)
2. **Job 2** só tenta conectar ao self-hosted **após Job 1 passar**
3. Self-hosted runner usado apenas para deploy final
4. Evita queue infinito por indisponibilidade de runner

### ⚠️ **Estrutura Problemática (Evitar):**
```yaml
jobs:
  validate-compose:
    runs-on: [self-hosted, ...]  # ❌ PROBLEMA: Self-hosted no primeiro job
```

### 📋 **Regra de Ouro:**
- **Primeiro job**: SEMPRE `ubuntu-latest` (GitHub-hosted)
- **Jobs subsequentes**: Podem usar `self-hosted`
- **Dependency**: Jobs self-hosted devem ter `needs: [primeiro-job]`

### 🎯 **Aplicação:**
Esta estrutura deve ser usada em **TODOS** os workflows de infraestrutura:
- ✅ Redis Infrastructure (corrigido)
- ✅ MySQL Infrastructure (corrigido)
- ✅ Traefik Infrastructure (exemplo original)
- 🔄 Demais infraestruturas (aplicar padrão)

---

## 🔐 **Docker Compose no Ubuntu 24.04**

### ❌ **Problema:**
```bash
Package 'docker-compose-plugin' has no installation candidate
```

### ✅ **Solução:**
```bash
# Adicionar repositório oficial Docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-compose-plugin
```

---

## 📝 **Template de Workflow Padrão**

```yaml
name: 🔧 [SERVICE] Infrastructure - CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]
  workflow_dispatch:

env:
  SERVICE_NAME: [service-name]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  validate-and-build:
    runs-on: ubuntu-latest  # ← OBRIGATÓRIO: GitHub-hosted
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4.3.0
      - name: Install dependencies
      - name: Validate configs
      - name: Security validation
      - name: Upload artifacts

  deploy-production:
    needs: validate-and-build  # ← OBRIGATÓRIO: Dependency
    runs-on: [self-hosted, Linux, X64, srv649924, conexao, [service-specific-label]]
    timeout-minutes: 25
    if: github.ref == 'refs/heads/main'
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4.3.0
      - name: Download artifacts
      - name: Azure Login via OIDC
      - name: Load secrets from Azure Key Vault
      - name: Create Docker Secrets
      - name: Deploy production stack
      - name: Health check
```

---

## 🚨 **Checklist de Validação**

Antes de criar/modificar qualquer workflow de infraestrutura:

- [ ] Primeiro job usa `runs-on: ubuntu-latest`
- [ ] Jobs self-hosted têm `needs: [primeiro-job]`
- [ ] Docker Compose instalado corretamente para Ubuntu 24.04
- [ ] Azure OIDC configurado (`permissions: id-token: write`)
- [ ] Secrets mascarados com `echo "::add-mask::$SECRET"`
- [ ] Timeout definido para todos os jobs
- [ ] Health check implementado
- [ ] Artifacts uploadados/downloadados entre jobs

---

## 📊 **Resultados da Implementação**

### Antes (Problemático):
- ❌ Workflows em queue por 10+ minutos
- ❌ Timeouts e cancelamentos
- ❌ Impossibilidade de deploy

### Depois (Padrão Traefik):
- ✅ Job 1 executa imediatamente (GitHub-hosted)
- ✅ Job 2 conecta aos self-hosted runners
- ✅ Deploy automatizado funcional
- ✅ Integração Azure Key Vault operacional

---

**Data da Lição**: 2025-09-17
**Contexto**: Debugging workflows Redis/MySQL em queue infinito
**Descoberta**: Análise do workflow funcional do Traefik
**Impacto**: Solução aplicável a toda infraestrutura do projeto