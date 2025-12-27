#!/bin/bash
# Development startup script for Docker container
# Runs both Vite dev server (frontend) and FastAPI backend (with debugpy)

set -e

echo "🔧 Development mode: Starting backend and frontend..."

# Verify Node.js is available (should be installed in Dockerfile, but check anyway)
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "❌ Error: Node.js or npm not found!"
    echo "   Node.js path: $(which node 2>/dev/null || echo 'not found')"
    echo "   npm path: $(which npm 2>/dev/null || echo 'not found')"
    echo "   PATH: $PATH"
    exit 1
fi

echo "✅ Node.js version: $(node --version)"
echo "✅ npm version: $(npm --version)"
echo "✅ Node.js path: $(which node)"
echo "✅ npm path: $(which npm)"

# Set CORS for development
export CORS_ALLOW_ORIGIN="http://localhost:5173;http://localhost:8080;http://localhost:3000"
export PORT="${PORT:-8080}"

# Function to handle cleanup on exit
cleanup() {
    echo "🛑 Shutting down services..."
    kill $VITE_PID $BACKEND_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Start Vite dev server (frontend)
cd /app

# Check if node_modules exists and package files haven't changed
# Named volume preserves node_modules, so only install if missing or package files changed
if [ ! -d "node_modules" ] || [ ! "$(ls -A node_modules 2>/dev/null)" ] || \
   [ "package.json" -nt "node_modules" ] || \
   ([ -f "package-lock.json" ] && [ "package-lock.json" -nt "node_modules" ]); then
    echo "📦 Installing/updating frontend dependencies..."
    npm ci --force || npm install --force
else
    echo "✅ node_modules already installed (from named volume), skipping npm install"
fi

# Check if Pyodide is already cached
if [ -d "static/pyodide" ] && [ -f "static/pyodide/pyodide-lock.json" ]; then
    echo "✅ Pyodide packages already cached, skipping fetch"
    # Create a wrapper script that skips pyodide:fetch
    export SKIP_PYODIDE=true
else
    echo "📦 Pyodide packages not cached, will fetch on startup"
fi

echo "🚀 Starting Vite dev server (frontend) on port 5173..."
# Export DOCKER=true so Vite can detect Docker mode
export DOCKER=true

# Conditionally skip Pyodide fetch if already cached
if [ "$SKIP_PYODIDE" = "true" ]; then
    # Run vite dev directly via npx, skipping pyodide:fetch
    echo "   (Skipping Pyodide fetch - using cached packages)"
    npx vite dev --host --port 5173 &
else
    # Run normal dev script (includes pyodide:fetch)
    npm run dev -- --host --port 5173 &
fi
VITE_PID=$!

# Wait for Vite to be ready (check if port 5173 is listening)
echo "⏳ Waiting for Vite to be ready..."
for i in {1..30}; do
    if nc -z localhost 5173 2>/dev/null; then
        echo "✅ Vite dev server is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "⚠️  Vite may not be ready yet, but continuing..."
    fi
    sleep 1
done

# Start backend with debugpy
# TEMPORARY TEST: Running without debugpy to test if it affects streaming responses
# Uncomment the debugpy line and comment the direct uvicorn line to restore debugpy
echo "🐍 Starting backend (TEST MODE: without debugpy)..."
cd /app/backend
# python -m debugpy --listen 0.0.0.0:5678 -m uvicorn open_webui.main:app \
python -m uvicorn open_webui.main:app \
    --host 0.0.0.0 \
    --port $PORT &
# --reload (commented out for testing)
BACKEND_PID=$!

echo "✅ Both services started!"
echo "   Frontend: http://localhost:5173"
echo "   Backend:  http://localhost:3000 (mapped from 8080)"
echo "   Debug:    Port 5678"
echo ""
echo "📝 Edit files in ./openwebui-source/open-webui/ for live changes"
echo "🛑 Press Ctrl+C to stop"

# Wait for both processes
wait $VITE_PID $BACKEND_PID

