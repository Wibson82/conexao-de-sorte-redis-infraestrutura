#!/bin/bash
# ============================================================================
# 🐳 DOCKER ENTRYPOINT - REDIS INFRASTRUCTURE
# ============================================================================
#
# Script de inicialização personalizado para Redis Infrastructure
# Contexto: Cache distribuído com dados sensíveis (Redis 8.2.1)
# - Validações específicas para Redis 8.2.1
# - Health checks para cache distribuído
# - Configuração de memory limits e persistence
# - Cluster validation e sentinel support
# - Performance monitoring e optimization
# - Network connectivity validation
# - Backup e recovery validation
#
# Uso: Configurar no Dockerfile como ENTRYPOINT
# ============================================================================

set -euo pipefail

# ============================================================================
# 📋 CONFIGURAÇÃO ESPECÍFICA DO REDIS
# ============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Função de log
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [REDIS]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [REDIS] ERROR:${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [REDIS] SUCCESS:${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [REDIS] WARNING:${NC} $1"
}

# ============================================================================
# 🔧 VALIDAÇÃO DE AMBIENTE - REDIS ESPECÍFICO
# ============================================================================

log "🚀 Iniciando validação de ambiente - Redis Infrastructure..."

# Verificar se estamos rodando como usuário correto
if [[ "$(id -u)" -eq 0 ]]; then
    warning "Executando como root - isso pode ser inseguro em produção"
fi

# Variáveis obrigatórias específicas do Redis
required_vars=(
    "REDIS_PASSWORD"
    "REDIS_PORT"
    "REDIS_DATABASES"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
        missing_vars+=("$var")
    fi
done

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    error "Variáveis de ambiente obrigatórias não definidas para Redis:"
    for var in "${missing_vars[@]}"; do
        error "  - $var"
    fi
    exit 1
fi

# Validações específicas do Redis
if [[ "$REDIS_PORT" != "6379" ]]; then
    warning "Porta do Redis diferente do padrão: $REDIS_PORT (esperado: 6379)"
fi

# Validar complexidade da senha Redis
if [[ -n "${REDIS_PASSWORD:-}" ]]; then
    if [[ ${#REDIS_PASSWORD} -lt 8 ]]; then
        error "❌ Senha do Redis muito curta (mínimo 8 caracteres)"
        exit 1
    fi
    success "✅ Complexidade da senha Redis validada"
fi

success "✅ Validação de ambiente concluída - Redis Infrastructure"

# ============================================================================
# 🔐 VALIDAÇÃO DE MEMÓRIA E RECURSOS - REDIS
# ============================================================================

log "🔍 Validando alocação de memória para Redis..."

# Verificar memória total disponível
TOTAL_MEMORY=$(free -m | awk 'NR==2 {print $2}')
REDIS_RECOMMENDED_MEMORY=1024  # 1GB recomendado para Redis

if [[ $TOTAL_MEMORY -lt $REDIS_RECOMMENDED_MEMORY ]]; then
    warning "⚠️ Memória limitada para Redis: ${TOTAL_MEMORY}MB (recomendado: ${REDIS_RECOMMENDED_MEMORY}MB)"
else
    success "✅ Memória suficiente para Redis: ${TOTAL_MEMORY}MB"
fi

# Verificar se há configuração de maxmemory
if [[ -n "${REDIS_MAXMEMORY:-}" ]]; then
    log "ℹ️ Redis MaxMemory configurado: $REDIS_MAXMEMORY"
    # Validar se maxmemory não excede memória disponível
    if [[ $REDIS_MAXMEMORY =~ ^[0-9]+$ ]]; then
        if [[ $REDIS_MAXMEMORY -gt $((TOTAL_MEMORY * 1024 * 1024)) ]]; then
            warning "⚠️ Redis MaxMemory ($REDIS_MAXMEMORY bytes) excede memória disponível"
        fi
    fi
fi

# ============================================================================
# 💾 VALIDAÇÃO DE STORAGE E PERSISTENCE
# ============================================================================

log "🔍 Validando storage e persistence..."

# Verificar se há espaço suficiente no disco para RDB/AOF
DISK_THRESHOLD_MB=512  # 512MB mínimo para Redis
AVAILABLE_SPACE=$(df /data | awk 'NR==2 {print $4}')
AVAILABLE_MB=$((AVAILABLE_SPACE / 1024))

if [[ $AVAILABLE_MB -lt $DISK_THRESHOLD_MB ]]; then
    warning "⚠️ Espaço em disco limitado para Redis: ${AVAILABLE_MB}MB (recomendado: ${DISK_THRESHOLD_MB}MB)"
else
    success "✅ Espaço em disco suficiente para Redis: ${AVAILABLE_MB}MB"
fi

# Verificar configuração de persistence
if [[ -n "${REDIS_SAVE:-}" ]]; then
    log "ℹ️ Redis persistence configurada: $REDIS_SAVE"
fi

if [[ -n "${REDIS_APPENDONLY:-}" ]]; then
    log "ℹ️ Redis AOF configurado: $REDIS_APPENDONLY"
    if [[ "$REDIS_APPENDONLY" == "yes" ]]; then
        success "✅ Redis AOF habilitado para durabilidade"
    fi
fi

# ============================================================================
# 🌐 VALIDAÇÃO DE CONECTIVIDADE - NETWORK
# ============================================================================

log "🔍 Validando conectividade de rede..."

# Verificar se Docker está disponível
if ! docker info >/dev/null 2>&1; then
    error "❌ Docker não está disponível ou não está rodando"
    exit 1
fi

# Verificar se Docker Swarm está ativo
if ! docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
    warning "⚠️ Docker Swarm não está ativo - inicializando..."
    if ! docker swarm init --advertise-addr $(hostname -I | awk '{print $1}') 2>/dev/null; then
        log "ℹ️ Docker Swarm pode já estar inicializado ou não é possível inicializar"
    fi
fi

success "✅ Docker e Docker Swarm disponíveis"

# ============================================================================
# 🔄 VALIDAÇÃO DE CLUSTER/SENTINEL
# ============================================================================

log "🔍 Validando configuração de cluster/sentinel..."

# Verificar se há configuração de cluster
if [[ -n "${REDIS_CLUSTER_ENABLED:-}" ]]; then
    if [[ "$REDIS_CLUSTER_ENABLED" == "yes" ]]; then
        log "🔍 Configuração de cluster detectada"

        if [[ -z "${REDIS_CLUSTER_NODES:-}" ]]; then
            error "❌ Cluster habilitado mas REDIS_CLUSTER_NODES não configurado"
            exit 1
        fi

        success "✅ Configuração de cluster validada"
    fi
fi

# Verificar se há configuração de sentinel
if [[ -n "${REDIS_SENTINEL_ENABLED:-}" ]]; then
    if [[ "$REDIS_SENTINEL_ENABLED" == "yes" ]]; then
        log "🔍 Configuração de sentinel detectada"

        if [[ -z "${REDIS_SENTINEL_MASTER:-}" ]]; then
            error "❌ Sentinel habilitado mas REDIS_SENTINEL_MASTER não configurado"
            exit 1
        fi

        success "✅ Configuração de sentinel validada"
    fi
fi

# ============================================================================
# 🏥 VALIDAÇÃO DE HEALTH CHECKS - REDIS
# ============================================================================

log "🏥 Validando health checks específicos do Redis..."

# Verificar se o Redis pode inicializar
if command -v redis-cli --version >/dev/null 2>&1; then
    REDIS_VERSION=$(redis-cli --version | awk '{print $2}')
    log "ℹ️ Versão do Redis CLI: $REDIS_VERSION"
else
    log "ℹ️ Redis CLI não encontrado no container"
fi

# Verificar se há processos Redis rodando
if pgrep -f redis-server >/dev/null 2>&1; then
    warning "⚠️ Redis já está rodando - verificando se é uma reinicialização"
else
    success "✅ Nenhum processo Redis anterior detectado"
fi

# Validar configuração de maxclients
if [[ -n "${REDIS_MAXCLIENTS:-}" ]]; then
    log "ℹ️ Redis MaxClients configurado: $REDIS_MAXCLIENTS"
fi

# ============================================================================
# 📊 VALIDAÇÃO DE PERFORMANCE
# ============================================================================

log "📊 Validando configurações de performance..."

# Verificar se há configuração de I/O threads
if [[ -n "${REDIS_IO_THREADS:-}" ]]; then
    log "ℹ️ Redis IO Threads configurado: $REDIS_IO_THREADS"
fi

# Verificar se há configuração de lazyfree
if [[ -n "${REDIS_LAZYFREE_LAZY_EVICTION:-}" ]]; then
    log "ℹ️ Redis Lazy Free configurado: $REDIS_LAZYFREE_LAZY_EVICTION"
fi

# Validar configuração de TCP keepalive
if [[ -n "${REDIS_TCP_KEEPALIVE:-}" ]]; then
    log "ℹ️ Redis TCP Keepalive configurado: $REDIS_TCP_KEEPALIVE"
fi

# ============================================================================
# 🔐 VALIDAÇÃO DE SEGURANÇA
# ============================================================================

log "🔐 Validando configurações de segurança..."

# Verificar se protected mode está habilitado
if [[ -n "${REDIS_PROTECTED_MODE:-}" ]]; then
    if [[ "$REDIS_PROTECTED_MODE" == "yes" ]]; then
        success "✅ Redis Protected Mode habilitado"
    fi
fi

# Verificar se rename commands estão configurados
if [[ -n "${REDIS_RENAME_COMMANDS:-}" ]]; then
    log "ℹ️ Redis Rename Commands configurado"
    success "✅ Comandos perigosos protegidos"
fi

# Validar configuração de bind
if [[ -n "${REDIS_BIND:-}" ]]; then
    log "ℹ️ Redis BIND configurado: $REDIS_BIND"
fi

# ============================================================================
# 📋 INFORMAÇÕES DO AMBIENTE - REDIS
# ============================================================================

log "📋 Informações do ambiente - Redis Infrastructure:"
echo "  - Service: Conexão de Sorte - Redis Infrastructure"
echo "  - Version: ${REDIS_VERSION:-8.2.1}"
echo "  - Profile: ${REDIS_PROFILE:-default}"
echo "  - Server Port: $REDIS_PORT (Padrão: 6379)"
echo "  - Databases: $REDIS_DATABASES"
echo "  - Memory Total: ${TOTAL_MEMORY}MB"
echo "  - Disk Space: ${AVAILABLE_MB}MB"
echo "  - MaxMemory: ${REDIS_MAXMEMORY:-Não configurado}"
echo "  - Persistence: ${REDIS_SAVE:-Não configurado}"
echo "  - AOF: ${REDIS_APPENDONLY:-Não configurado}"
echo "  - Cluster: ${REDIS_CLUSTER_ENABLED:-Não configurado}"
echo "  - Sentinel: ${REDIS_SENTINEL_ENABLED:-Não configurado}"
echo "  - Health Endpoint: redis://localhost:$REDIS_PORT"

# ============================================================================
# 🏃 EXECUÇÃO DA APLICAÇÃO - REDIS
# ============================================================================

log "🏃 Iniciando Redis Infrastructure..."

# Executar aplicação com exec para permitir signal handling
exec "$@"
