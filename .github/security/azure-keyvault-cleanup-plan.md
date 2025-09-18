# 🗄️ Azure Key Vault - Plano de Enxugamento e Padronização

## 📊 **ANÁLISE ATUAL DOS SECRETS**

### **🔍 Secrets Identificados (49+ Total)**

#### **✅ REDIS INFRASTRUCTURE (4 secrets - MANTER)**
```bash
conexao-de-sorte-redis-password          # ✅ ATIVO - Usado em ci-cd.yml:170
conexao-de-sorte-redis-host              # ✅ ATIVO - Usado em ci-cd.yml:172
conexao-de-sorte-redis-port              # ✅ ATIVO - Usado em ci-cd.yml:173
conexao-de-sorte-redis-database          # ✅ ATIVO - Usado em ci-cd.yml:171
```

#### **🔄 DATABASE INFRASTRUCTURE (13 secrets - PADRONIZAR)**
```bash
# DUPLICAÇÃO DETECTADA - Padronizar nomenclatura:

# Padrão CORRETO (manter):
conexao-de-sorte-database-host           # ✅ ATIVO
conexao-de-sorte-database-port           # ✅ ATIVO
conexao-de-sorte-database-username       # ✅ ATIVO
conexao-de-sorte-database-password       # ✅ ATIVO
conexao-de-sorte-database-proxysql-password # ✅ ATIVO
conexao-de-sorte-database-jdbc-url       # ✅ ATIVO
conexao-de-sorte-database-r2dbc-url      # ✅ ATIVO
conexao-de-sorte-database-url            # ✅ ATIVO
conexao-de-sorte-database-flyway-url     # ✅ ATIVO

# Padrão INCONSISTENTE (migrar/deprecar):
conexao-de-sorte-db-host                 # ⚠️ DEPRECAR -> use database-host
conexao-de-sorte-db-port                 # ⚠️ DEPRECAR -> use database-port
conexao-de-sorte-db-username             # ⚠️ DEPRECAR -> use database-username
conexao-de-sorte-db-password             # ⚠️ DEPRECAR -> use database-password
```

#### **🔐 JWT/AUTH (2 secrets - MANTER)**
```bash
conexao-de-sorte-jwt-issuer              # ✅ ATIVO - Usado em microservices
conexao-de-sorte-jwt-jwks-uri            # ✅ ATIVO - Usado em microservices
```

#### **☁️ AZURE INTEGRATION (5 secrets - REVISAR)**
```bash
AZURE_CLIENT_ID                          # ⚠️ DUPLICADO (GitHub Secrets)
AZURE_TENANT_ID                          # ⚠️ DUPLICADO (GitHub Secrets)
AZURE_SUBSCRIPTION_ID                    # ⚠️ DUPLICADO (GitHub Secrets)
AZURE_KEYVAULT_ENDPOINT                  # ✅ ATIVO - Necessário para apps
AZURE_KEYVAULT_NAME                      # ⚠️ DUPLICADO (GitHub Secrets)
```

#### **🏗️ INFRASTRUCTURE ADICIONAL (25+ secrets - AUDITAR)**
```bash
MYSQL_ROOT_PASSWORD                      # ✅ NECESSÁRIO para MySQL Infrastructure
MYSQL_REPLICATION_PASSWORD               # ✅ NECESSÁRIO para MySQL Replication
PROXYSQL_PASSWORD                        # ✅ NECESSÁRIO para ProxySQL
ZIPKIN_ENDPOINT                          # 🤔 REVISAR - pode ser config não secret
TRACING_PROBABILITY                      # 🤔 REVISAR - pode ser config não secret
SPRING_PROFILES_ACTIVE                   # 🤔 REVISAR - não é secret
# ... outros secrets por mapear detalhadamente
```

---

## 🎯 **PLANO DE AÇÃO**

### **1. PADRONIZAÇÃO DE NOMENCLATURA**

#### **Migração Database Secrets**
```bash
# Criar aliases padronizados mantendo compatibilidade:

# FASE 1: Criar novos secrets padronizados
conexao-de-sorte-database-host           # Já existe ✅
conexao-de-sorte-database-port           # Já existe ✅
conexao-de-sorte-database-username       # Já existe ✅
conexao-de-sorte-database-password       # Já existe ✅

# FASE 2: Deprecar secrets inconsistentes (após migração códigos)
conexao-de-sorte-db-*                    # Marcar como deprecated
```

#### **Padrão de Nomenclatura Oficial**
```bash
# ESTRUTURA: conexao-de-sorte-{service}-{resource}-{property}

✅ conexao-de-sorte-redis-password
✅ conexao-de-sorte-database-username
✅ conexao-de-sorte-jwt-issuer
❌ MYSQL_ROOT_PASSWORD → conexao-de-sorte-mysql-root-password
❌ ZIPKIN_ENDPOINT → conexao-de-sorte-zipkin-endpoint
```

### **2. CATEGORIZAÇÃO POR TAGS**

```bash
# Implementar tagging system:

# Por serviço:
service:redis, service:database, service:jwt, service:mysql

# Por tipo:
type:password, type:endpoint, type:connection-string, type:config

# Por ambiente:
environment:production, environment:staging, environment:development

# Por criticidade:
criticality:high, criticality:medium, criticality:low

# Por rotação:
rotation:daily, rotation:weekly, rotation:monthly, rotation:yearly
```

### **3. REMOÇÃO DE DUPLICATAS**

#### **Azure Secrets (REMOVER do Key Vault)**
```bash
# Estes devem estar APENAS no GitHub Secrets:
❌ AZURE_CLIENT_ID           → GitHub Secrets apenas
❌ AZURE_TENANT_ID           → GitHub Secrets apenas
❌ AZURE_SUBSCRIPTION_ID     → GitHub Secrets apenas
❌ AZURE_KEYVAULT_NAME       → GitHub Secrets apenas

# Manter apenas no Key Vault:
✅ AZURE_KEYVAULT_ENDPOINT   → Apps precisam deste endpoint
```

#### **Configs vs Secrets**
```bash
# Migrar para variables (não secrets):
❌ SPRING_PROFILES_ACTIVE     → GitHub Variables
❌ TRACING_PROBABILITY        → GitHub Variables
❌ ZIPKIN_ENDPOINT            → GitHub Variables (se não sensível)
```

### **4. VERSIONAMENTO E AUDITORIA**

```json
{
  "secret_name": "conexao-de-sorte-redis-password",
  "version": "2025.01.001",
  "created_date": "2025-01-17T10:00:00Z",
  "last_rotation": "2025-01-17T10:00:00Z",
  "next_rotation": "2025-04-17T10:00:00Z",
  "tags": {
    "service": "redis",
    "type": "password",
    "environment": "production",
    "criticality": "high",
    "rotation": "quarterly"
  },
  "access_policy": {
    "allowed_services": ["github-actions-oidc"],
    "network_restriction": "azure-only"
  }
}
```

### **5. CRONOGRAMA DE IMPLEMENTAÇÃO**

#### **SEMANA 1: Audit e Mapeamento**
- [ ] Mapear todos os 49+ secrets existentes
- [ ] Identificar dependências de cada secret
- [ ] Classificar por criticidade e uso
- [ ] Definir plano de rotação

#### **SEMANA 2: Padronização**
- [ ] Criar secrets padronizados para database
- [ ] Implementar sistema de tags
- [ ] Migrar configs não-sensíveis para variables
- [ ] Documentar mudanças

#### **SEMANA 3: Limpeza**
- [ ] Remover duplicatas Azure OIDC
- [ ] Deprecar secrets com nomenclatura inconsistente
- [ ] Implementar network restrictions
- [ ] Validar access policies

#### **SEMANA 4: Validação**
- [ ] Testar todos os pipelines
- [ ] Validar funcionamento dos microserviços
- [ ] Documentar secrets finais
- [ ] Implementar monitoramento

---

## 🛡️ **SEGURANÇA APRIMORADA**

### **Network Access Restrictions**
```json
{
  "network_acls": {
    "default_action": "Deny",
    "ip_rules": [],
    "virtual_network_rules": [
      {
        "subnet": "/subscriptions/.../vnet-github-runners/subnet-redis"
      }
    ]
  }
}
```

### **Access Policies Rigorosas**
```json
{
  "access_policies": [
    {
      "tenant_id": "${AZURE_TENANT_ID}",
      "object_id": "${GITHUB_OIDC_SERVICE_PRINCIPAL}",
      "permissions": {
        "secrets": ["get", "list"],
        "keys": [],
        "certificates": []
      }
    }
  ]
}
```

### **Audit Logging Completo**
```bash
# Habilitar logs para:
✅ Secret access attempts
✅ Failed authentication
✅ Permission changes
✅ Network policy violations
✅ Key rotation events
```

---

## 📈 **MÉTRICAS DE SUCESSO**

### **Antes da Limpeza**
- 🔢 **49+ secrets** (muitos duplicados)
- ❌ **Nomenclatura inconsistente**
- ❌ **Sem versionamento**
- ❌ **Sem categorização**
- ❌ **Duplicatas Azure OIDC**

### **Após a Limpeza**
- 🎯 **~35 secrets** únicos e necessários
- ✅ **Nomenclatura padronizada** (conexao-de-sorte-*)
- ✅ **Versionamento semântico**
- ✅ **Tags completas** para auditoria
- ✅ **Zero duplicatas** com GitHub Secrets

### **KPIs de Segurança**
- 📊 **Redução de 30%** no número de secrets
- 🔒 **100% dos secrets** com network restrictions
- 📋 **100% dos secrets** com tags de auditoria
- 🔄 **100% dos secrets** com cronograma de rotação
- 🛡️ **Zero duplicatas** entre GitHub/Azure

---

**Status**: 🚧 EM IMPLEMENTAÇÃO
**Próximo passo**: Mapear detalhadamente os 25+ secrets adicionais