#!/bin/bash
# Gavra Development Environment Setup Script
# Optimized for Intel Celeron N4020 + 8GB RAM

echo "🚀 Starting Gavra optimized development environment..."

# Set resource limits for Supabase containers
export SUPABASE_DB_MEMORY=512m
export SUPABASE_API_MEMORY=256m
export SUPABASE_AUTH_MEMORY=128m

# PostgreSQL optimizations for Gavra app
export POSTGRES_SHARED_BUFFERS=128MB
export POSTGRES_EFFECTIVE_CACHE_SIZE=512MB
export POSTGRES_WORK_MEM=4MB
export POSTGRES_MAX_CONNECTIONS=25

# Start Supabase with resource constraints
echo "📊 Starting Supabase with optimized settings..."
supabase start --ignore-health-check

echo "✅ Gavra development environment ready!"
echo "📱 Run 'flutter run' to start the app"
echo "🌐 Studio: http://127.0.0.1:54323"
echo "🔗 API: http://127.0.0.1:54321"

# Memory usage info
echo "💾 Current memory usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -10