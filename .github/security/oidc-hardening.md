# 🛡️ OIDC Security Hardening Configuration

## 🔒 **Hardening Implementado - Redis Infrastructure**

### **1. Subject Claim Validation**
```json
{
  "subject": "repo:Wibson82/conexao-de-sorte-redis-infraestrutura:ref:refs/heads/main",
  "issuer": "https://token.actions.githubusercontent.com",
  "audience": "api://AzureADTokenExchange"
}
```

### **2. Azure Federated Credential Configuration**
```bash
# Configuração Azure CLI para setup inicial
az ad app federated-credential create \
    --id ${AZURE_CLIENT_ID} \
    --parameters '{
        "name": "GitHub-OIDC-Redis-Infrastructure-Hardened",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "repo:Wibson82/conexao-de-sorte-redis-infraestrutura:ref:refs/heads/main",
        "audiences": ["api://AzureADTokenExchange"],
        "description": "Hardened OIDC for Redis Infrastructure - main branch only"
    }'
```

### **3. Branch Protection Rules (OBRIGATÓRIO)**
- ✅ **Require pull request reviews**: 1 reviewer mínimo
- ✅ **Require status checks**: Security validation obrigatória
- ✅ **Require branches to be up to date**: Sempre
- ✅ **Require conversation resolution**: Antes do merge
- ✅ **Restrict pushes**: Apenas administradores
- ✅ **Block force pushes**: Proibido
- ✅ **Delete protection**: Branch main protegida

### **4. Environment Protection Rules**
```yaml
Environment: production
Required reviewers: [ "admin-user" ]
Wait timer: 0 minutes (aprovação manual obrigatória)
Deployment branches: main only
```

### **5. GitHub Secrets Validation**
```bash
# Apenas estes 4 secrets são permitidos:
AZURE_CLIENT_ID           # Service Principal ID
AZURE_TENANT_ID           # Azure AD Tenant ID
AZURE_SUBSCRIPTION_ID     # Target subscription
AZURE_KEYVAULT_NAME       # Key Vault name

# ❌ PROIBIDOS:
# - Passwords, connection strings, API keys
# - Qualquer secret que não seja para OIDC Azure
```

### **6. Audience Validation Rigorosa**
```yaml
# Token OIDC deve ter exatamente:
aud: ["api://AzureADTokenExchange"]
iss: "https://token.actions.githubusercontent.com"
sub: "repo:Wibson82/conexao-de-sorte-redis-infraestrutura:ref:refs/heads/main"
```

### **7. Permissions Ultra-Mínimas**
```yaml
permissions:
  contents: read          # Leitura do código apenas
  id-token: write         # OIDC token apenas
  actions: none           # ❌ Desabilitado
  checks: none            # ❌ Desabilitado
  deployments: none       # ❌ Desabilitado
  issues: none            # ❌ Desabilitado
  packages: none          # ❌ Desabilitado
  pages: none             # ❌ Desabilitado
  pull-requests: none     # ❌ Desabilitado
  repository-projects: none # ❌ Desabilitado
  security-events: none   # ❌ Desabilitado
  statuses: none          # ❌ Desabilitado
```

### **8. Context Validation**
```bash
# Validações obrigatórias antes de qualquer operação:
✅ Repository: Wibson82/conexao-de-sorte-redis-infraestrutura
✅ Branch: main (para produção)
✅ Event: push ou workflow_dispatch
✅ Actor: Não bots maliciosos
✅ Subscription ID: Correto
✅ Tenant ID: Correto
```

### **9. Timeout Configurations**
```yaml
# Timeouts rigorosos para prevenir ataques:
OIDC Login: 2 minutes
Security Validation: 1 minute
Key Vault Access: 30 seconds
Overall Job: 25 minutes
```

### **10. Self-Hosted Runner Security**
```yaml
Labels Required:
  - self-hosted
  - Linux
  - X64
  - conexao-de-sorte-redis-infraestrutura

Security Requirements:
  - Isolated network environment
  - No internet access (except Azure APIs)
  - Regular security patches
  - Dedicated runner per repository
  - No shared runners between projects
```

## 🚨 **Incident Response**

### **OIDC Token Compromise**
1. Revocar federated credential no Azure AD
2. Regenerar Service Principal se necessário
3. Auditar logs do Key Vault
4. Verificar deployments suspeitos
5. Atualizar secrets no Key Vault

### **Unauthorized Access**
1. Desabilitar workflow runs
2. Revisar branch protection rules
3. Auditar environment approvals
4. Verificar runner permissions
5. Escalar para security team

### **Key Vault Breach**
1. Rotate todos os secrets imediatamente
2. Revisar access policies
3. Habilitar audit logging
4. Verificar network access rules
5. Implementar private endpoints

## 📊 **Compliance Validation**

### **Daily Checks**
- [ ] GitHub Secrets audit (apenas 4 OIDC)
- [ ] Branch protection rules ativas
- [ ] Environment gates funcionando
- [ ] Runner security patches atualizados
- [ ] Azure RBAC permissions corretas

### **Weekly Checks**
- [ ] Key Vault access logs review
- [ ] Failed authentication attempts
- [ ] Workflow execution patterns
- [ ] Secret rotation schedule
- [ ] Incident response test

### **Monthly Checks**
- [ ] Full security assessment
- [ ] OIDC configuration review
- [ ] Runner infrastructure audit
- [ ] Emergency access procedures test
- [ ] Disaster recovery validation

---

**Implementado em**: 2025-01-17
**Próxima revisão**: 2025-02-17
**Owner**: Security Team
**Status**: ✅ HARDENING COMPLETO IMPLEMENTADO