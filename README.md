# 🔴 Redis Infrastructure - Conexão de Sorte

**Projeto:** conexao-de-sorte-redis-infraestrutura
**Versão:** Redis 8.2.2 (Atualizada - Setembro 2025)

Este stack provisiona um Redis dedicado e otimizado, compartilhável entre todos os microserviços na rede Docker `conexao-network`.

## 🚀 **Principais características**

- **Imagem:** `redis:8.2.2` (versão estável mais recente)
- **Segurança:** `requirepass` via variável de ambiente (não versionar senhas)
- **Persistência:** AOF + RDB com `save 60 1000`
- **Memória:** 256MB max com política `allkeys-lru`
- **Performance:** Bind 0.0.0.0, otimizado para múltiplas conexões
- **Health Check:** Melhorado com 30s interval, 3 retries
- **Rede:** Externa `conexao-network` (compatível com todos os microsserviços)
- **Resource Limits:** 300M memory limit, 0.5 CPU limit

## Uso

1. Crie um arquivo `.env` (a partir do exemplo):
   - `cp .env.example .env`
   - Edite `REDIS_PASSWORD` com uma senha forte
2. Suba o stack:
   - `docker compose up -d`
3. Verifique:
   - `docker ps --filter name=conexao-redis`
   - `docker logs -f conexao-redis`

O serviço ficará acessível internamente pelo hostname `conexao-redis:6379` na rede Docker `conexao-network`.

## Integração com microserviços

- Defina os segredos no Azure Key Vault (por microserviço):
  - `REDIS_HOST = conexao-redis`
  - `REDIS_PORT = 6379`
  - `REDIS_PASSWORD = <senha do .env>`
  - `REDIS_DB = <inteiro>` (sugestões: 2=resultado, 3=scheduler, 5=observabilidade)
- Gere os arquivos em `/run/secrets` com os scripts `scripts/setup-secrets.sh` de cada microserviço.
- Reative a auto-configuração do Redis removendo as exclusões em `spring.autoconfigure.exclude` e reabilite o health quando o serviço estiver disponível.

## Exposição externa (opcional e não recomendada)

Por padrão o Redis NÃO é exposto externamente. Se precisar (somente para diagnóstico temporário), descomente a seção `ports:` no `docker-compose.yml`, limite IPs no firewall e remova a exposição após o uso.

## Observações

- A rede `conexao-network` deve existir. Se necessário crie com:
  - `docker network create conexao-network`
- Backups AOF: o volume `redis-data` persiste o AOF. Planeje cópias/rotação conforme sua política.
- Segurança: proteja `.env` e não versione senhas.

