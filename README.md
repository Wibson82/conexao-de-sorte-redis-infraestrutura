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

### GitHub OIDC + Azure Key Vault

Este projeto utiliza GitHub OIDC para autenticação segura com o Azure Key Vault, eliminando a necessidade de armazenar credenciais no GitHub.

#### Secrets Necessários no GitHub

Configure os seguintes secrets no repositório:

```bash
# Azure OIDC Configuration
AZURE_CLIENT_ID=<service-principal-client-id>
AZURE_TENANT_ID=<azure-tenant-id>
AZURE_SUBSCRIPTION_ID=<azure-subscription-id>
AZURE_KEYVAULT_ENDPOINT=https://<vault-name>.vault.azure.net
AZURE_KEYVAULT_NAME=<vault-name>
```

#### Secrets no Azure Key Vault

Os seguintes secrets devem estar configurados no Azure Key Vault:

```bash
# Redis Configuration
conexao-de-sorte-redis-password          # Senha do Redis
conexao-de-sorte-redis-host              # Host do Redis (opcional)
conexao-de-sorte-redis-port              # Porta do Redis (opcional)
conexao-de-sorte-redis-database          # Database do Redis (opcional)

# Database Integration (para outros serviços)
conexao-de-sorte-database-password       # Senha do banco principal
conexao-de-sorte-database-username       # Usuário do banco principal
conexao-de-sorte-database-host           # Host do banco principal
conexao-de-sorte-database-port           # Porta do banco principal

# JWT & Security
conexao-de-sorte-jwt-secret              # Secret JWT
conexao-de-sorte-jwt-signing-key         # Chave de assinatura JWT
conexao-de-sorte-jwt-verification-key    # Chave de verificação JWT

# Monitoring & Operations
conexao-de-sorte-monitoring-token        # Token de monitoramento
conexao-de-sorte-session-secret          # Secret de sessão
conexao-de-sorte-encryption-master-key   # Chave mestra de criptografia
```

## 🚀 Deploy

### Automático via GitHub Actions

O deploy é executado automaticamente quando:
- Push para branch `main`
- Alterações em arquivos relevantes (`docker-compose.yml`, `scripts/**`, `.github/workflows/**`)
- Execução manual via `workflow_dispatch`

### Pipeline de Deploy

1. **Validação** - Verificação de sintaxe e configuração
2. **Segurança** - Scan de vulnerabilidades e secrets
3. **Staging** - Deploy em ambiente de teste
4. **Produção** - Deploy em ambiente de produção

### Stacks Criadas

- **Staging**: `conexao-de-sorte-redis-staging`
- **Produção**: `conexao-de-sorte-redis-production`

## 🔧 Configuração Local

### Pré-requisitos

- Docker 20.10+
- Docker Compose 2.0+
- Azure CLI (para sincronização de secrets)
- Acesso ao Azure Key Vault

### Setup Local

1. **Clone o repositório**:
```bash
git clone <repository-url>
cd conexao-de-sorte-redis-infraestrutura
```

2. **Configure Azure CLI**:
```bash
az login
az account set --subscription <subscription-id>
```

3. **Sincronize secrets**:
```bash
chmod +x .github/workflows/scripts/sync-azure-keyvault-secrets.sh
./.github/workflows/scripts/sync-azure-keyvault-secrets.sh kv-conexao-de-sorte redis-infraestrutura
```

4. **Deploy local**:
```bash
# Inicializar Docker Swarm (se necessário)
docker swarm init

# Deploy da stack
docker stack deploy -c docker-compose.yml conexao-redis-local
```

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

# Conectar ao Redis (para debug)
docker exec -it $(docker ps -q -f name=redis) redis-cli -a "$(docker secret inspect REDIS_PASSWORD --format '{{.Spec.Data}}')"
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
# Verificar se secret existe
docker secret ls | grep REDIS_PASSWORD

# Recriar secret se necessário
./.github/workflows/scripts/sync-azure-keyvault-secrets.sh kv-conexao-de-sorte redis-infraestrutura
```

2. **Redis não aceita conexões**:
```bash
# Verificar logs do serviço
docker service logs conexao-de-sorte-redis-production_redis --tail 50

# Verificar health check
docker service ps conexao-de-sorte-redis-production_redis
```

3. **Problemas de rede**:
```bash
# Verificar se rede existe
docker network ls | grep conexao-network-swarm

# Recriar rede se necessário
docker network create --driver overlay --attachable conexao-network-swarm
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

