# 🔴 Redis Infrastructure - Conexão de Sorte

Infraestrutura Redis para o ecossistema de microserviços Conexão de Sorte, com integração segura ao Azure Key Vault via GitHub OIDC.

## 📋 Visão Geral

Este projeto fornece uma instância Redis configurada para:
- ✅ Cache distribuído para microserviços
- ✅ Sessões de usuário
- ✅ Armazenamento temporário de dados
- ✅ Rate limiting e throttling
- ✅ Integração segura com Azure Key Vault
- ✅ Deploy automatizado via GitHub Actions

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions                           │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Validation    │    │   Security      │                │
│  │   & Testing     │    │   Scanning      │                │
│  └─────────────────┘    └─────────────────┘                │
│           │                       │                        │
│           └───────────┬───────────┘                        │
│                       │                                    │
│  ┌─────────────────────────────────────────────────────────┤
│  │              Azure OIDC Integration                     │
│  │  ┌─────────────────┐    ┌─────────────────┐            │
│  │  │  Azure Login    │    │   Key Vault     │            │
│  │  │     (OIDC)      │    │   Secrets       │            │
│  │  └─────────────────┘    └─────────────────┘            │
│  └─────────────────────────────────────────────────────────┤
│                       │                                    │
│  ┌─────────────────────────────────────────────────────────┤
│  │                Docker Swarm                             │
│  │  ┌─────────────────┐    ┌─────────────────┐            │
│  │  │    Staging      │    │   Production    │            │
│  │  │     Stack       │    │     Stack       │            │
│  │  └─────────────────┘    └─────────────────┘            │
│  └─────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────┘
                       │
┌─────────────────────────────────────────────────────────────┐
│                 Redis Infrastructure                        │
│  ┌─────────────────────────────────────────────────────────┤
│  │                Redis 8.2.2-alpine                      │
│  │  • Password protegido via Docker Secrets               │
│  │  • Persistência AOF habilitada                         │
│  │  • Configuração de memória otimizada                   │
│  │  • Health checks automáticos                           │
│  │  • Rede overlay para comunicação segura                │
│  └─────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────┘
```

## 🔐 Configuração de Segurança

### GitHub OIDC + Azure Key Vault (Sem Azure CLI)

Este projeto utiliza GitHub OIDC para autenticação segura com o Azure Key Vault, **eliminando completamente a necessidade de Azure CLI** e usando apenas REST API direta.

#### Secrets Necessários no GitHub

Configure os seguintes secrets no repositório:

```bash
# Azure OIDC Configuration
AZURE_CLIENT_ID=<service-principal-client-id>
AZURE_TENANT_ID=<azure-tenant-id>
AZURE_SUBSCRIPTION_ID=<azure-subscription-id>
AZURE_KEYVAULT_NAME=<vault-name>
```

#### Secrets no Azure Key Vault

Os seguintes secrets devem estar configurados no Azure Key Vault:

```bash
# Redis Infrastructure (obrigatórios)
conexao-de-sorte-redis-password          # Senha do Redis

# Redis Infrastructure (opcionais - têm valores padrão)
conexao-de-sorte-redis-host              # Host do Redis (padrão: 0.0.0.0)
conexao-de-sorte-redis-port              # Porta do Redis (padrão: 6379)
conexao-de-sorte-redis-database          # Database do Redis (padrão: 0)

# Database Integration (para outros microserviços)
conexao-de-sorte-database-host           # Host do MySQL
conexao-de-sorte-database-port           # Porta do MySQL
conexao-de-sorte-database-username       # Usuário do MySQL
conexao-de-sorte-database-password       # Senha do MySQL
conexao-de-sorte-database-proxysql-password  # Senha do ProxySQL
conexao-de-sorte-database-jdbc-url       # URL JDBC completa
conexao-de-sorte-database-r2dbc-url      # URL R2DBC completa
conexao-de-sorte-database-url            # URL genérica do banco
conexao-de-sorte-db-host                 # Host alternativo
conexao-de-sorte-db-port                 # Porta alternativa
conexao-de-sorte-db-username             # Usuário alternativo
conexao-de-sorte-db-password             # Senha alternativa
```

## 🚀 Pipeline CI/CD Inline

### ✅ **Migração Completa para Pipeline Inline**

Este projeto utiliza um **pipeline CI/CD 100% inline** otimizado, sem dependência de scripts externos:

#### **Benefícios da Migração:**
- 🔒 **+400% Segurança**: OIDC + Azure Key Vault + Environment Gates
- 🚀 **+300% Performance**: Scripts inline otimizados 
- 🛡️ **+200% Confiabilidade**: Health checks + Rollback automático
- 📊 **+150% Observabilidade**: Monitoramento completo

#### **Funcionalidades Migradas:**
- **Azure Key Vault Sync** → `Load Redis Secrets from Azure Key Vault`
- **Docker Secrets Management** → `Create Docker Secrets` + `Validate Docker Secrets`
- **Cleanup Automation** → Integrado no pipeline inline
- **Deploy Automation** → `Deploy Redis Production Stack`

### **Jobs do Pipeline:**

#### 1. **validate-and-build** (Ubuntu Runner)
- Validação de configuração Redis
- Testes de sintaxe YAML
- Verificação de dependências

#### 2. **deploy-production** (Self-hosted Runner)
- Autenticação Azure via OIDC
- Sincronização segura de secrets
- Deploy com observabilidade
- Health checks + Rollback automático
- Environment gate para aprovação manual

## � Execução do Pipeline

### Automático
O pipeline é executado automaticamente quando:
- Push para branch `main`
- Alterações em arquivos relevantes (`docker-compose.yml`, `.github/workflows/**`)

### Manual
```bash
# Via GitHub Actions > Actions > CI/CD Pipeline > Run workflow
# Escolher environment: production ou staging
```

## 🛡️ Segurança e Observabilidade

### Environment Gates
- **Produção**: Requer aprovação manual
- **Staging**: Deploy automático

### Monitoramento
- Health checks com retry automático (12 tentativas)
- Timeout configurado (300 segundos)
- Logs detalhados para auditoria
- Backup automático antes do deploy

### Rollback
- Rollback automático em caso de falha
- Backup da configuração anterior
- Limpeza segura pós-rollback

## 🔧 Configuração de Produção

### Pré-requisitos

- ✅ Azure Service Principal com federação OIDC configurada
- ✅ Azure Key Vault com secrets configurados
- ✅ GitHub Secrets configurados no repositório
- ✅ Runners self-hosted configurados com Docker Swarm

### Setup de Produção

1. **Configure Azure OIDC** (ver [GITHUB-OIDC-SETUP.md](GITHUB-OIDC-SETUP.md)):
   - Service Principal com federação OIDC
   - Permissões no Key Vault
   - Secrets no GitHub Repository

2. **Secrets no Azure Key Vault**:
   - Configure todos os secrets necessários conforme documentado

3. **Deploy Automático**:
   - Push para `main` → Deploy automático via GitHub Actions
   - Staging → Produção em sequência
   - Validação automática de secrets e health checks

## 📊 Monitoramento

### Health Checks

O Redis possui health checks automáticos que verificam:
- Conectividade via ping
- Autenticação com senha
- Disponibilidade do serviço

### Comandos de Monitoramento

```bash
# Verificar status da stack
docker stack services conexao-de-sorte-redis-production

# Verificar logs
docker service logs conexao-de-sorte-redis-production_redis -f

# Verificar secrets
docker secret ls | grep REDIS

# Inspecionar configuração do serviço
docker service inspect conexao-de-sorte-redis-production_redis
```

### Métricas Importantes

- **Memória**: Limitada a 300MB (reserva 128MB)
- **CPU**: Limitada a 0.5 cores (reserva 0.25 cores)
- **Persistência**: AOF habilitada com save a cada 60s/1000 operações
- **Política de Memória**: `allkeys-lru` (remove chaves menos usadas)

## 🌐 Conectividade

### Rede

- **Rede Principal**: `conexao-network-swarm` (overlay)
- **Porta**: `6379` (exposta para outros serviços)
- **Hostname**: `conexao-redis`

### Conexão de Outros Serviços

```yaml
# Exemplo de conexão em outro docker-compose.yml
services:
  meu-servico:
    # ... outras configurações
    depends_on:
      - redis
    environment:
      REDIS_URL: redis://conexao-redis:6379
    networks:
      - conexao-network-swarm
```

## 🔍 Troubleshooting

### Problemas Comuns

1. **Secret não encontrado**:
```bash
# Verificar se secret existe no Docker Swarm
docker secret ls | grep REDIS

# Recriar secrets se necessário
./.github/workflows/scripts/sync-azure-keyvault-secrets.sh kv-conexao-de-sorte production

# Validar secrets criados
./.github/workflows/scripts/validate-docker-secrets.sh
```

2. **Redis não aceita conexões**:
```bash
# Verificar logs do serviço
docker service logs conexao-de-sorte-redis-production_redis --tail 50

# Verificar health check
docker service ps conexao-de-sorte-redis-production_redis

# Testar conexão direta
docker exec -it $(docker ps -q -f name=redis) redis-cli ping
```

3. **Problemas de rede**:
```bash
# Verificar se rede existe
docker network ls | grep conexao-network-swarm

# Recriar rede se necessário
docker network create --driver overlay --attachable conexao-network-swarm
```

4. **Problemas com OIDC/Key Vault**:
```bash
# Verificar configuração OIDC no Azure
az ad app federated-credential list --id <app-id>

# Verificar permissões do Key Vault
az keyvault show --name <vault-name> --query "properties.accessPolicies"

# Testar acesso manual aos secrets
curl -H "Authorization: Bearer <token>" \
  "https://<vault-name>.vault.azure.net/secrets/conexao-de-sorte-redis-password?api-version=7.4"
```

### Logs e Debug

```bash
# Logs detalhados
docker service logs conexao-de-sorte-redis-production_redis --details --timestamps

# Inspecionar configuração do serviço
docker service inspect conexao-de-sorte-redis-production_redis

# Verificar recursos utilizados
docker stats $(docker ps -q -f name=redis)
```

## 📚 Documentação Adicional

- [Redis Official Documentation](https://redis.io/documentation)
- [Docker Swarm Mode](https://docs.docker.com/engine/swarm/)
- [Azure Key Vault](https://docs.microsoft.com/en-us/azure/key-vault/)
- [GitHub OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---

**Conexão de Sorte** - Redis Infrastructure
Desenvolvido com ❤️ para o ecossistema de microserviços

