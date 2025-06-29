#!/bin/bash

# DevLife Portal Infrastructure Setup - LATEST VERSION
echo "🚀 DevLife Portal Development Setup v2.0"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
print_success() { echo -e "${CYAN}[SUCCESS]${NC} $1"; }

# Check Docker installation
check_docker() {
    print_step "Checking Docker installation..."
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        echo "📥 Download: https://www.docker.com/products/docker-desktop"
        exit 1
    fi
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    print_status "Docker and Docker Compose are installed and running ✅"
}

# Check sibling repositories
check_repositories() {
    print_step "Checking repository structure..."
    
    required_repos=("../devlife-backend" "../devlife-frontend" "../devlife-db-scripts")
    missing_repos=()
    
    for repo in "${required_repos[@]}"; do
        if [ ! -d "$repo" ]; then
            repo_name=$(basename "$repo")
            missing_repos+=("$repo_name")
        fi
    done
    
    if [ ${#missing_repos[@]} -gt 0 ]; then
        print_error "Missing repositories: ${missing_repos[*]}"
        echo ""
        echo "Expected structure:"
        echo "  YourOrganization/"
        echo "  ├── devlife-infrastructure/  (current directory)"
        echo "  ├── devlife-backend/"
        echo "  ├── devlife-frontend/"
        echo "  └── devlife-db-scripts/"
        echo ""
        echo "Please clone missing repositories first."
        exit 1
    fi
    
    print_status "All required repositories found ✅"
}

# Create environment files
create_env_files() {
    print_step "Creating environment files..."
    
    # Backend .env
    if [ ! -f "../devlife-backend/.env" ]; then
        print_status "Creating backend .env..."
        cat > ../devlife-backend/.env << 'EOF'
# Database Configuration (Docker internal network)
DATABASE_URL=postgresql://devlife_user:devlife_password@postgres:5432/devlife
MONGODB_URL=mongodb://devlife_user:devlife_password@mongodb:27017/devlife
REDIS_URL=redis://devlife_user:devlife_password@redis:6379

# For local development (outside Docker)
# DATABASE_URL=postgresql://devlife_user:devlife_password@localhost:6100/devlife
# MONGODB_URL=mongodb://devlife_user:devlife_password@localhost:27017/devlife
# REDIS_URL=redis://devlife_user:devlife_password@localhost:6200

# Application Settings
ASPNETCORE_ENVIRONMENT=Development
CORS_ORIGINS=http://localhost:4200

# External APIs (add your keys)
GITHUB_CLIENT_ID=your_github_client_id
GITHUB_CLIENT_SECRET=your_github_client_secret
OPENAI_API_KEY=your_openai_api_key

# Session Configuration
SESSION_TIMEOUT_MINUTES=30
EOF
    else
        print_warning "Backend .env already exists"
    fi
    
    # Angular environment file
    if [ ! -f "../devlife-frontend/src/environments/environment.ts" ] && [ -d "../devlife-frontend/src" ]; then
        print_status "Creating Angular environment..."
        mkdir -p ../devlife-frontend/src/environments
        cat > ../devlife-frontend/src/environments/environment.ts << 'EOF'
export const environment = {
  production: false,
  apiUrl: 'http://localhost:5000',
  wsUrl: 'ws://localhost:5000/hubs',
  appName: 'DevLife Portal',
  theme: 'dark',
  colors: {
    primary: '#6366f1',
    success: '#10b981', 
    danger: '#ef4444',
    background: '#0f172a'
  },
  casino: {
    initialPoints: 1000
  },
  features: {
    githubIntegration: true
  }
};
EOF
    else
        print_warning "Angular environment file already exists or src directory not found"
    fi
}

# Clean up previous containers
cleanup_containers() {
    print_step "Cleaning up existing containers..."
    
    # Stop and remove existing containers
    containers=("devlife-postgres" "devlife-mongodb" "devlife-redis" "devlife-backend" "devlife-frontend")
    for container in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            print_status "Removing existing container: $container"
            docker rm -f "$container" &>/dev/null || true
        fi
    done
}

# Start services with proper wait
start_services() {
    print_step "Starting Docker services..."
    
    # Start databases first
    print_status "Starting databases..."
    docker-compose up -d postgres mongodb redis
    
    print_status "Waiting for databases to be healthy..."
    
    # Wait for PostgreSQL
    print_status "Waiting for PostgreSQL..."
    for i in {1..60}; do
        if docker exec devlife-postgres pg_isready -U devlife_user -d devlife &>/dev/null; then
            print_success "PostgreSQL is ready!"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    # Wait for MongoDB
    print_status "Waiting for MongoDB..."
    for i in {1..60}; do
        if docker exec devlife-mongodb mongosh --eval "db.runCommand('ping')" &>/dev/null 2>&1; then
            print_success "MongoDB is ready!"
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    # Wait for Redis
    print_status "Waiting for Redis..."
    for i in {1..30}; do
        if docker exec devlife-redis redis-cli -a devlife_password ping &>/dev/null; then
            print_success "Redis is ready!"
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""
    
    print_success "✅ All database services are running!"
    echo "  • PostgreSQL: localhost:6100"
    echo "  • MongoDB: localhost:27017"
    echo "  • Redis: localhost:6200"
}

# Execute database scripts manually
execute_scripts_manually() {
    print_step "Executing database scripts..."
    
    # Execute MongoDB scripts manually (always needed due to auth)
    print_status "Initializing MongoDB collections..."
    
    if [ -f "../devlife-db-scripts/mongo-init/01-init-collections.js" ]; then
        # Fix for Windows Git Bash path issues
        export MSYS_NO_PATHCONV=1
        
        # Try mounted file first
        if docker exec devlife-mongodb test -f /docker-entrypoint-initdb.d/01-init-collections.js 2>/dev/null; then
            print_status "Executing via mounted file..."
            docker exec devlife-mongodb mongosh devlife \
                --authenticationDatabase admin \
                -u devlife_user \
                -p devlife_password \
                --file /docker-entrypoint-initdb.d/01-init-collections.js 2>/dev/null
        else
            # Fallback: Copy and execute
            print_status "Copying script to container..."
            docker cp "../devlife-db-scripts/mongo-init/01-init-collections.js" devlife-mongodb:/tmp/init-collections.js
            
            print_status "Executing MongoDB script..."
            docker exec devlife-mongodb mongosh devlife \
                --authenticationDatabase admin \
                -u devlife_user \
                -p devlife_password \
                --file /tmp/init-collections.js 2>/dev/null
            
            # Cleanup
            docker exec devlife-mongodb rm /tmp/init-collections.js 2>/dev/null
        fi
        
        unset MSYS_NO_PATHCONV
        print_success "MongoDB initialization completed!"
    else
        print_error "MongoDB script not found: ../devlife-db-scripts/mongo-init/01-init-collections.js"
    fi
    
    # Check PostgreSQL scripts (usually auto-execute correctly)
    if ! docker exec devlife-postgres psql -U devlife_user -d devlife -c "SELECT 1 FROM users LIMIT 1;" &>/dev/null; then
        print_status "Executing PostgreSQL scripts manually..."
        
        if [ -f "../devlife-db-scripts/init/01-init-database.sql" ]; then
            docker exec -i devlife-postgres psql -U devlife_user -d devlife < ../devlife-db-scripts/init/01-init-database.sql
            print_success "PostgreSQL schema created"
        fi
        
        if [ -f "../devlife-db-scripts/init/02-sample-data.sql" ]; then
            docker exec -i devlife-postgres psql -U devlife_user -d devlife < ../devlife-db-scripts/init/02-sample-data.sql
            print_success "PostgreSQL sample data inserted"
        fi
    fi
    
    # Wait a moment for everything to settle
    sleep 3
}

# Test database connections and verify scripts
test_connections() {
    print_step "Testing database connections and verifying data..."
    
    # Test PostgreSQL
    if docker exec devlife-postgres pg_isready -U devlife_user -d devlife &>/dev/null; then
        print_success "PostgreSQL: ✅ Connected"
        
        # Check tables
        table_count=$(docker exec devlife-postgres psql -U devlife_user -d devlife -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
        if [ "$table_count" -gt 0 ]; then
            print_success "PostgreSQL Scripts: ✅ $table_count tables created"
            
            # Check sample data
            user_count=$(docker exec devlife-postgres psql -U devlife_user -d devlife -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | tr -d ' ')
            print_success "Sample Users: $user_count users inserted"
        else
            print_error "PostgreSQL Scripts: ❌ No tables found"
        fi
    else
        print_error "PostgreSQL: ❌ Connection failed"
    fi
    
    echo ""
    
    # Test MongoDB with authentication
    if docker exec devlife-mongodb mongosh --eval "db.runCommand('ping')" &>/dev/null 2>&1; then
        print_success "MongoDB: ✅ Connected"
        
        # Check collections with proper authentication
        collections=$(docker exec devlife-mongodb mongosh devlife \
            --authenticationDatabase admin \
            -u devlife_user \
            -p devlife_password \
            --eval "db.getCollectionNames().length" --quiet 2>/dev/null)
        
        if [ ! -z "$collections" ] && [ "$collections" -gt 0 ]; then
            print_success "MongoDB Scripts: ✅ $collections collections created"
            
            # Check specific collections
            snippets=$(docker exec devlife-mongodb mongosh devlife \
                --authenticationDatabase admin \
                -u devlife_user \
                -p devlife_password \
                --eval "db.code_snippets.countDocuments()" --quiet 2>/dev/null)
            
            profiles=$(docker exec devlife-mongodb mongosh devlife \
                --authenticationDatabase admin \
                -u devlife_user \
                -p devlife_password \
                --eval "db.dating_profiles.countDocuments()" --quiet 2>/dev/null)
            
            excuses=$(docker exec devlife-mongodb mongosh devlife \
                --authenticationDatabase admin \
                -u devlife_user \
                -p devlife_password \
                --eval "db.meeting_excuses.countDocuments()" --quiet 2>/dev/null)
            
            horoscopes=$(docker exec devlife-mongodb mongosh devlife \
                --authenticationDatabase admin \
                -u devlife_user \
                -p devlife_password \
                --eval "db.horoscopes.countDocuments()" --quiet 2>/dev/null)
            
            print_success "Static Data: $snippets snippets, $profiles profiles, $excuses excuses, $horoscopes horoscopes"
        else
            print_error "MongoDB Scripts: ❌ No collections found"
        fi
    else
        print_error "MongoDB: ❌ Connection failed"
    fi
    
    echo ""
    
    # Test Redis
    if docker exec devlife-redis redis-cli -a devlife_password ping &>/dev/null; then
        print_success "Redis: ✅ Connected and ready"
    else
        print_error "Redis: ❌ Connection failed"
    fi
}

# Show next steps
show_next_steps() {
    echo ""
    print_success "🎉 DevLife Portal infrastructure setup completed!"
    echo ""
    echo "📋 Next Steps:"
    echo "=============="
    echo "1. Backend (.NET 9):"
    echo "   cd ../devlife-backend"
    echo "   dotnet new web -o . --force"
    echo "   dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL"
    echo "   dotnet add package MongoDB.Driver"
    echo "   dotnet add package StackExchange.Redis"
    echo "   dotnet add package Microsoft.AspNetCore.SignalR"
    echo "   dotnet run"
    echo ""
    echo "2. Frontend (Angular):"
    echo "   cd ../devlife-frontend"
    echo "   ng new . --routing --style=scss --skip-git"
    echo "   npm install tailwindcss postcss autoprefixer socket.io-client"
    echo "   ng serve --port 4200"
    echo ""
    echo "3. Full Docker Environment:"
    echo "   docker-compose up --build"
    echo ""
    echo "🌐 Service URLs:"
    echo "================"
    echo "• Frontend: http://localhost:4200"
    echo "• Backend: http://localhost:5000"
    echo "• PostgreSQL: localhost:6100"
    echo "• MongoDB: localhost:27017"
    echo "• Redis: localhost:6200"
    echo ""
    echo "📊 Database Access:"
    echo "==================="
    echo "• PostgreSQL: docker exec -it devlife-postgres psql -U devlife_user -d devlife"
    echo "• MongoDB: docker exec -it devlife-mongodb mongosh devlife -u devlife_user -p devlife_password"
    echo "• Redis: docker exec -it devlife-redis redis-cli -a devlife_password"
    echo ""
    echo "🎮 Ready to implement 6 projects:"
    echo "=================================="
    echo "1. 🎰 Code Casino"
    echo "2. 🔥 Code Roasting"
    echo "3. 🏃 Bug Chase Game"
    echo "4. 🔍 Code Personality Analyzer"
    echo "5. 💑 Dev Dating Room"
    echo "6. 🏃 Meeting Escape Generator"
    echo ""
    echo "🔧 Useful Commands:"
    echo "==================="
    echo "• View logs: docker-compose logs -f [service_name]"
    echo "• Stop all: docker-compose down"
    echo "• Restart: docker-compose restart [service_name]"
    echo "• Reset everything: docker-compose down -v && ./setup-dev.sh"
}

# Main execution
main() {
    echo ""
    check_docker
    check_repositories
    cleanup_containers
    create_env_files
    start_services
    execute_scripts_manually
    test_connections
    show_next_steps
    echo ""
    print_success "🚀 Ready to start building DevLife Portal!"
}

# Handle script interruption
cleanup_on_exit() {
    echo ""
    print_warning "Setup interrupted. Run './setup-dev.sh' again to continue."
    exit 1
}

trap cleanup_on_exit INT

# Run main function
main