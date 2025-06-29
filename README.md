# DevLife Portal - Infrastructure

Infrastructure orchestration for the DevLife Portal project. This repository contains Docker Compose configuration and setup scripts to run the complete development environment.

## 📁 Expected Project Structure

This infrastructure repository expects the following sibling repositories:

```
YourOrganization/
├── devlife-infrastructure/          # ← This repository
│   ├── docker-compose.yml          # ← Docker orchestration
│   ├── setup-dev.sh                # ← Development setup script
│   └── README.md                   # ← This file
├── devlife-backend/                # ← .NET 9 API repository
├── devlife-frontend/               # ← Angular application repository
└── devlife-db-scripts/             # ← Database scripts repository
```

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- Git

### 1. Clone All Repositories
```bash
# Clone all repositories to the same parent directory
git clone https://github.com/YourOrganization/devlife-infrastructure.git
git clone https://github.com/YourOrganization/devlife-backend.git
git clone https://github.com/YourOrganization/devlife-frontend.git
git clone https://github.com/YourOrganization/devlife-db-scripts.git
```

### 2. Run Setup
```bash
cd devlife-infrastructure
chmod +x setup-dev.sh
./setup-dev.sh
```

## 🗄️ Services & Ports

| Service | Port | Description |
|---------|------|-------------|
| PostgreSQL | 6100 | Main database (users, scores, game data) |
| MongoDB | 27017 | Static content (profiles, code snippets) |
| Redis | 6200 | Caching and session management |
| Backend API | 5000 | .NET 9 Web API |
| Frontend | 4200 | Angular application |

## 🐳 Docker Commands

### Basic Operations
```bash
# Start all services
docker-compose up -d

# Start only databases
docker-compose up -d postgres mongodb redis

# Build and start
docker-compose up --build

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

### Database Access
```bash
# PostgreSQL
docker exec -it devlife-postgres psql -U devlife_user -d devlife

# MongoDB
docker exec -it devlife-mongodb mongosh devlife

# Redis
docker exec -it devlife-redis redis-cli -a devlife_password
```

## ⚙️ Configuration

### Database Credentials
- **Username**: `devlife_user`
- **Password**: `devlife_password`
- **Database**: `devlife`

### Connection Strings
```bash
# For local development (outside Docker)
PostgreSQL: postgresql://devlife_user:devlife_password@localhost:6100/devlife
MongoDB: mongodb://devlife_user:devlife_password@localhost:27017/devlife
Redis: redis://devlife_user:devlife_password@localhost:6200

# For Docker containers (internal network) 
PostgreSQL: postgresql://devlife_user:devlife_password@postgres:5432/devlife
MongoDB: mongodb://devlife_user:devlife_password@mongodb:27017/devlife
Redis: redis://devlife_user:devlife_password@redis:6379
```

## 🔧 Development Workflow

### Option 1: Local Development (Recommended)
```bash
# 1. Start databases only
cd devlife-infrastructure
docker-compose up -d postgres mongodb redis

# 2. Run backend locally
cd ../devlife-backend
dotnet run

# 3. Run frontend locally  
cd ../devlife-frontend
ng serve --port 4200
```

### Option 2: Full Docker Environment
```bash
# Start everything in Docker
cd devlife-infrastructure
docker-compose up --build
```

## 🎮 DevLife Portal Features

This infrastructure supports 6 interactive projects:

1. **🎰 Code Casino** - Bet on which code snippet works correctly
2. **🔥 Code Roasting** - Submit code for humorous AI feedback
3. **🏃 Bug Chase Game** - Endless runner with WebSocket multiplayer
4. **🔍 Code Personality Analyzer** - GitHub repository analysis
5. **💑 Dev Dating Room** - Tinder-like matching for developers
6. **🏃 Meeting Escape Generator** - Creative excuses to avoid meetings

## 🔍 Troubleshooting

### Common Issues

**Databases not starting:**
```bash
# Check Docker logs
docker-compose logs postgres
docker-compose logs mongodb
docker-compose logs redis
```

**Port conflicts:**
```bash
# Check what's using the ports
sudo lsof -i :6100  # PostgreSQL
sudo lsof -i :6200  # Redis
sudo lsof -i :27017 # MongoDB
```

**Permission issues:**
```bash
# Make setup script executable
chmod +x setup-dev.sh
```

### Reset Environment
```bash
# Complete reset
docker-compose down -v
docker system prune -f
./setup-dev.sh
```

## 📊 Health Checks

```bash
# Check service status
docker ps --filter name=devlife

# Test database connections
docker exec devlife-postgres pg_isready -U devlife_user
docker exec devlife-mongodb mongosh --eval "db.runCommand('ping')"
docker exec devlife-redis redis-cli -a devlife_password ping
```

## 🌐 Access URLs

- **Frontend**: http://localhost:4200
- **Backend API**: http://localhost:5000
- **PostgreSQL**: localhost:6100
- **MongoDB**: localhost:27017  
- **Redis**: localhost:6200

---

**DevLife Portal Infrastructure** - Orchestrating the developer lifestyle simulator! 🎯