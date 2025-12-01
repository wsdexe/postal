# Postal Management API v2

Полноценный REST API для управления всеми аспектами Postal. Позволяет автоматизировать:
- Управление организациями
- Управление серверами
- Управление пользователями
- Управление доменами
- Управление учетными данными (credentials)
- Управление маршрутами
- Управление вебхуками
- Управление эндпоинтами
- Системные операции

## Содержание

1. [Установка и настройка](#установка-и-настройка)
2. [Аутентификация](#аутентификация)
3. [Формат ответов](#формат-ответов)
4. [API Endpoints](#api-endpoints)
   - [Система](#система)
   - [Пользователи](#пользователи)
   - [Организации](#организации)
   - [Серверы](#серверы)
   - [Домены](#домены)
   - [Учетные данные](#учетные-данные)
   - [Маршруты](#маршруты)
   - [Вебхуки](#вебхуки)
   - [Эндпоинты](#эндпоинты)
5. [Примеры использования](#примеры-использования)
6. [Автоматизация установки](#автоматизация-установки)

---

## Установка и настройка

### Предварительные требования

- Docker и Docker Compose
- Git
- Доменное имя с настроенным DNS

### Быстрая установка

#### 1. Подготовка директорий

```bash
sudo mkdir -p /opt/postal/{config,mariadb,caddy-data}
```

#### 2. Создание конфигурации MariaDB

```bash
cat > /opt/postal/mariadb/my.cnf << 'EOF'
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
max_allowed_packet = 256M
innodb_log_file_size = 256M
innodb_buffer_pool_size = 1G
EOF
```

#### 3. Запуск MariaDB

```bash
docker run -d \
   --name postal-mariadb \
   -p 127.0.0.1:3306:3306 \
   --restart always \
   -e MARIADB_DATABASE=postal \
   -e MARIADB_ROOT_PASSWORD=your_secure_password \
   -v /opt/postal/mariadb/my.cnf:/etc/mysql/conf.d/my.cnf \
   -v /opt/postal/mariadb/data:/var/lib/mysql \
   mariadb
```

#### 4. Клонирование репозитория

```bash
git clone https://github.com/wsdexe/postal-install /opt/postal/install
sudo ln -s /opt/postal/install/bin/postal /usr/bin/postal
```

#### 5. Инициализация Postal

```bash
# Создание конфигурационных файлов
postal bootstrap web.example.com

# Редактирование конфигурации (опционально)
nano /opt/postal/config/postal.yml

# Добавление API ключа для Management API (опционально)
# В файл /opt/postal/config/postal.yml добавьте:
# management_api_key: your_secure_api_key
# Или установите переменную окружения MANAGEMENT_API_KEY

# Инициализация базы данных
postal initialize

# Создание администратора
postal make-user

# Запуск Postal
postal start
```

#### 6. Запуск Caddy (веб-сервер)

```bash
docker run -d \
   --name postal-caddy \
   --restart always \
   --network host \
   -v /opt/postal/config/Caddyfile:/etc/caddy/Caddyfile \
   -v /opt/postal/caddy-data:/data \
   caddy
```

### Настройка Management API

Management API доступен на `/api/v2/` и требует аутентификации.

#### Способы аутентификации:

1. **Переменная окружения** (рекомендуется для автоматизации):
   ```bash
   export MANAGEMENT_API_KEY="your_secure_api_key_here"
   ```

2. **UUID администратора**: Используйте UUID любого администратора как API ключ

---

## Аутентификация

Все запросы к Management API должны содержать заголовок:

```
X-Management-API-Key: <your_api_key>
```

### Пример с curl:

```bash
curl -H "X-Management-API-Key: your_api_key" \
     https://postal.example.com/api/v2/system/info
```

---

## Формат ответов

### Успешный ответ

```json
{
  "status": "success",
  "time": 0.123,
  "data": {
    // данные ответа
  }
}
```

### Ошибка

```json
{
  "status": "error",
  "time": 0.001,
  "error": {
    "code": "ErrorCode",
    "message": "Описание ошибки",
    "errors": {}  // детали валидации (опционально)
  }
}
```

---

## API Endpoints

### Система

#### GET /api/v2/system/info
Информация о системе.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/system/info
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "version": "3.0.0",
    "ruby_version": "3.2.0",
    "rails_version": "7.0.8",
    "database_connected": true,
    "time": "2024-01-15T12:00:00Z"
  }
}
```

#### GET /api/v2/system/health
Проверка здоровья системы.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/system/health
```

#### GET /api/v2/system/stats
Статистика системы.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/system/stats
```

#### GET /api/v2/system/ip_pools
Список IP пулов.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/system/ip_pools
```

#### POST /api/v2/system/ip_pools
Создание IP пула.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"name": "Primary Pool", "default": true}' \
     https://postal.example.com/api/v2/system/ip_pools
```

#### POST /api/v2/system/ip_pools/:id/ip_addresses
Добавление IP адреса в пул.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"ipv4": "192.168.1.100", "hostname": "mail.example.com", "priority": 100}' \
     https://postal.example.com/api/v2/system/ip_pools/1/ip_addresses
```

---

### Пользователи

#### GET /api/v2/users
Список всех пользователей.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/users
```

Параметры:
- `query` - поиск по email, имени
- `admin` - фильтр по админам (true/false)

#### GET /api/v2/users/:uuid
Получение пользователя.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/users/abc123-def456
```

#### POST /api/v2/users
Создание пользователя.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "first_name": "John",
       "last_name": "Doe",
       "email_address": "john@example.com",
       "password": "SecurePassword123",
       "email_verified": true
     }' \
     https://postal.example.com/api/v2/users
```

#### PATCH /api/v2/users/:uuid
Обновление пользователя.

```bash
curl -X PATCH \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"first_name": "Jane"}' \
     https://postal.example.com/api/v2/users/abc123-def456
```

#### DELETE /api/v2/users/:uuid
Удаление пользователя.

```bash
curl -X DELETE \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/users/abc123-def456
```

#### POST /api/v2/users/:uuid/make_admin
Назначение администратором.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/users/abc123-def456/make_admin
```

#### POST /api/v2/users/:uuid/revoke_admin
Снятие прав администратора.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/users/abc123-def456/revoke_admin
```

---

### Организации

#### GET /api/v2/organizations
Список организаций.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations
```

Параметры:
- `query` - поиск по названию или permalink

#### GET /api/v2/organizations/:permalink
Получение организации.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org
```

#### POST /api/v2/organizations
Создание организации.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "My Organization",
       "permalink": "my-org",
       "time_zone": "Europe/Moscow",
       "owner_email": "admin@example.com"
     }' \
     https://postal.example.com/api/v2/organizations
```

#### PATCH /api/v2/organizations/:permalink
Обновление организации.

```bash
curl -X PATCH \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"name": "Updated Name"}' \
     https://postal.example.com/api/v2/organizations/my-org
```

#### DELETE /api/v2/organizations/:permalink
Удаление организации.

```bash
curl -X DELETE \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org
```

#### POST /api/v2/organizations/:permalink/suspend
Приостановка организации.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"reason": "Payment overdue"}' \
     https://postal.example.com/api/v2/organizations/my-org/suspend
```

#### POST /api/v2/organizations/:permalink/unsuspend
Возобновление организации.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/unsuspend
```

---

### Пользователи организации

#### GET /api/v2/organizations/:permalink/users
Список пользователей организации.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/users
```

#### POST /api/v2/organizations/:permalink/users
Добавление пользователя в организацию.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "user_email": "user@example.com",
       "admin": true,
       "all_servers": true
     }' \
     https://postal.example.com/api/v2/organizations/my-org/users
```

#### DELETE /api/v2/organizations/:permalink/users/:user_uuid
Удаление пользователя из организации.

```bash
curl -X DELETE \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/users/abc123
```

#### POST /api/v2/organizations/:permalink/transfer_ownership
Передача владения организацией.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"user_email": "newowner@example.com"}' \
     https://postal.example.com/api/v2/organizations/my-org/transfer_ownership
```

---

### Серверы

#### GET /api/v2/servers
Список всех серверов (глобально).

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/servers
```

#### GET /api/v2/organizations/:permalink/servers
Список серверов организации.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers
```

#### GET /api/v2/organizations/:permalink/servers/:server_permalink
Получение сервера.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server
```

#### POST /api/v2/organizations/:permalink/servers
Создание сервера.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Mail Server",
       "permalink": "mail-server",
       "mode": "Live",
       "send_limit": 10000,
       "message_retention_days": 60,
       "raw_message_retention_days": 30
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers
```

#### PATCH /api/v2/organizations/:permalink/servers/:server_permalink
Обновление сервера.

```bash
curl -X PATCH \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"send_limit": 20000}' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server
```

#### DELETE /api/v2/organizations/:permalink/servers/:server_permalink
Удаление сервера.

```bash
curl -X DELETE \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server
```

#### POST /api/v2/organizations/:permalink/servers/:server_permalink/suspend
Приостановка сервера.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"reason": "Abuse detected"}' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/suspend
```

#### POST /api/v2/organizations/:permalink/servers/:server_permalink/unsuspend
Возобновление сервера.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/unsuspend
```

#### GET /api/v2/organizations/:permalink/servers/:server_permalink/stats
Статистика сервера.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/stats
```

Ответ:
```json
{
  "status": "success",
  "data": {
    "server": {
      "id": 1,
      "uuid": "abc123",
      "name": "Mail Server"
    },
    "statistics": {
      "message_rate": 1.5,
      "held_messages": 0,
      "throughput": {
        "incoming": 100,
        "outgoing": 500,
        "outgoing_usage": 5.0
      },
      "bounce_rate": 2.5,
      "domain_stats": {
        "total": 5,
        "unverified": 1,
        "bad_dns": 0
      },
      "send_volume": 500,
      "send_limit": 10000,
      "send_limit_approaching": false,
      "send_limit_exceeded": false,
      "queue_size": 10
    }
  }
}
```

---

### Домены

Домены могут принадлежать организации или серверу.

#### Домены организации

```bash
# Список
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/domains

# Создание
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "example.com",
       "verification_method": "DNS",
       "outgoing": true,
       "incoming": true
     }' \
     https://postal.example.com/api/v2/organizations/my-org/domains
```

#### Домены сервера

```bash
# Список
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/domains

# Создание
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "mail.example.com",
       "verification_method": "DNS",
       "outgoing": true,
       "incoming": true,
       "use_for_any": false
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/domains
```

#### POST /api/v2/.../domains/:uuid/verify
Верификация домена.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/domains/abc123/verify
```

#### POST /api/v2/.../domains/:uuid/check_dns
Проверка DNS записей.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/domains/abc123/check_dns
```

Ответ содержит информацию о требуемых DNS записях:
```json
{
  "status": "success",
  "data": {
    "domain": { ... },
    "dns_status": {
      "spf": {
        "status": "OK",
        "expected_record": "v=spf1 a mx include:spf.postal.example.com ~all"
      },
      "dkim": {
        "status": "Missing",
        "record_name": "postal-abc123._domainkey",
        "expected_record": "v=DKIM1; t=s; h=sha256; p=..."
      },
      "mx": {
        "status": "OK"
      },
      "return_path": {
        "status": "OK",
        "domain": "rp.mail.example.com"
      }
    }
  }
}
```

---

### Учетные данные (Credentials)

#### GET /api/v2/organizations/:org/servers/:server/credentials
Список учетных данных.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/credentials
```

#### POST /api/v2/organizations/:org/servers/:server/credentials
Создание учетных данных.

```bash
# API ключ
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "My API Key",
       "type": "API",
       "hold": false
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/credentials

# SMTP ключ
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "SMTP Credential",
       "type": "SMTP"
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/credentials

# IP-based SMTP
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Office IP",
       "type": "SMTP-IP",
       "key": "192.168.1.100"
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/credentials
```

---

### Маршруты

#### GET /api/v2/organizations/:org/servers/:server/routes
Список маршрутов.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/routes
```

#### POST /api/v2/organizations/:org/servers/:server/routes
Создание маршрута.

```bash
# Маршрут на HTTP endpoint
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "*",
       "domain_id": 1,
       "spam_mode": "Mark",
       "endpoint": "HTTPEndpoint#abc123-def456"
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/routes

# Маршрут с отклонением
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "spam",
       "domain_id": 1,
       "spam_mode": "Fail",
       "endpoint": "Reject"
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/routes
```

Доступные режимы endpoint:
- `HTTPEndpoint#<uuid>` - HTTP эндпоинт
- `SMTPEndpoint#<uuid>` - SMTP эндпоинт
- `AddressEndpoint#<uuid>` - Email адрес
- `Accept` - Принять
- `Hold` - Задержать
- `Bounce` - Отклонить с bounce
- `Reject` - Отклонить

---

### Вебхуки

#### GET /api/v2/organizations/:org/servers/:server/webhooks
Список вебхуков.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/webhooks
```

#### POST /api/v2/organizations/:org/servers/:server/webhooks
Создание вебхука.

```bash
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Delivery Notifications",
       "url": "https://myapp.com/webhooks/postal",
       "enabled": true,
       "sign": true,
       "all_events": true
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/webhooks
```

---

### Эндпоинты

#### GET /api/v2/organizations/:org/servers/:server/endpoints
Список всех эндпоинтов.

```bash
curl -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/endpoints
```

#### HTTP Эндпоинты

```bash
# Создание
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "My App",
       "url": "https://myapp.com/incoming",
       "encoding": "BodyAsJSON",
       "format": "RawMessage",
       "include_attachments": true,
       "strip_replies": false,
       "timeout": 30
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/endpoints/http

# Обновление
curl -X PATCH \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"timeout": 60}' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/endpoints/http/abc123

# Удаление
curl -X DELETE \
     -H "X-Management-API-Key: $API_KEY" \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/endpoints/http/abc123
```

#### SMTP Эндпоинты

```bash
# Создание
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "Backup Server",
       "hostname": "backup-smtp.example.com",
       "port": 25,
       "ssl_mode": "Auto"
     }' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/endpoints/smtp
```

#### Address Эндпоинты

```bash
# Создание
curl -X POST \
     -H "X-Management-API-Key: $API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"address": "forward@example.com"}' \
     https://postal.example.com/api/v2/organizations/my-org/servers/mail-server/endpoints/address
```

---

## Примеры использования

### Полная автоматизация создания организации с сервером

```bash
#!/bin/bash
API_KEY="your_management_api_key"
BASE_URL="https://postal.example.com/api/v2"

# 1. Создание пользователя (если не существует)
USER_RESPONSE=$(curl -s -X POST \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Customer",
    "last_name": "Name",
    "email_address": "customer@example.com",
    "password": "SecurePass123",
    "email_verified": true
  }' \
  "$BASE_URL/users")

echo "User created: $USER_RESPONSE"

# 2. Создание организации
ORG_RESPONSE=$(curl -s -X POST \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Customer Organization",
    "permalink": "customer-org",
    "time_zone": "Europe/Moscow",
    "owner_email": "customer@example.com"
  }' \
  "$BASE_URL/organizations")

echo "Organization created: $ORG_RESPONSE"

# 3. Создание сервера
SERVER_RESPONSE=$(curl -s -X POST \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Main Mail Server",
    "permalink": "main-server",
    "mode": "Live",
    "send_limit": 10000,
    "message_retention_days": 60
  }' \
  "$BASE_URL/organizations/customer-org/servers")

echo "Server created: $SERVER_RESPONSE"

# 4. Создание домена
DOMAIN_RESPONSE=$(curl -s -X POST \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "customer-domain.com",
    "verification_method": "DNS",
    "outgoing": true,
    "incoming": true
  }' \
  "$BASE_URL/organizations/customer-org/servers/main-server/domains")

echo "Domain created: $DOMAIN_RESPONSE"
DOMAIN_UUID=$(echo $DOMAIN_RESPONSE | jq -r '.data.domain.uuid')

# 5. Получение DNS записей для верификации
DNS_RESPONSE=$(curl -s -X POST \
  -H "X-Management-API-Key: $API_KEY" \
  "$BASE_URL/organizations/customer-org/servers/main-server/domains/$DOMAIN_UUID/check_dns")

echo "DNS Records needed:"
echo $DNS_RESPONSE | jq '.data.dns_status'

# 6. Создание API credential
CRED_RESPONSE=$(curl -s -X POST \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "API Key",
    "type": "API"
  }' \
  "$BASE_URL/organizations/customer-org/servers/main-server/credentials")

echo "Credential created: $CRED_RESPONSE"
API_CREDENTIAL=$(echo $CRED_RESPONSE | jq -r '.data.credential.key')

# 7. Создание SMTP credential
SMTP_CRED_RESPONSE=$(curl -s -X POST \
  -H "X-Management-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "SMTP Key",
    "type": "SMTP"
  }' \
  "$BASE_URL/organizations/customer-org/servers/main-server/credentials")

echo "SMTP Credential created: $SMTP_CRED_RESPONSE"
SMTP_CREDENTIAL=$(echo $SMTP_CRED_RESPONSE | jq -r '.data.credential.key')

echo ""
echo "=== Setup Complete ==="
echo "API Key: $API_CREDENTIAL"
echo "SMTP Key: $SMTP_CREDENTIAL"
echo "Configure your DNS records and then verify the domain."
```

### Скрипт обновления Postal

```bash
#!/bin/bash

# Остановка Postal
postal stop

# Очистка Docker
docker system prune -a -f

# Запуск Postal (автоматически скачает новый образ)
postal start

echo "Postal updated successfully"
```

### Python клиент

```python
import requests

class PostalManagementAPI:
    def __init__(self, base_url, api_key):
        self.base_url = base_url.rstrip('/')
        self.headers = {
            'X-Management-API-Key': api_key,
            'Content-Type': 'application/json'
        }

    def _request(self, method, endpoint, data=None):
        url = f"{self.base_url}{endpoint}"
        response = requests.request(method, url, headers=self.headers, json=data)
        return response.json()

    # System
    def get_info(self):
        return self._request('GET', '/api/v2/system/info')

    def get_health(self):
        return self._request('GET', '/api/v2/system/health')

    def get_stats(self):
        return self._request('GET', '/api/v2/system/stats')

    # Organizations
    def list_organizations(self):
        return self._request('GET', '/api/v2/organizations')

    def create_organization(self, name, permalink, owner_email, time_zone='UTC'):
        return self._request('POST', '/api/v2/organizations', {
            'name': name,
            'permalink': permalink,
            'owner_email': owner_email,
            'time_zone': time_zone
        })

    def get_organization(self, permalink):
        return self._request('GET', f'/api/v2/organizations/{permalink}')

    def delete_organization(self, permalink):
        return self._request('DELETE', f'/api/v2/organizations/{permalink}')

    # Servers
    def list_servers(self, org_permalink):
        return self._request('GET', f'/api/v2/organizations/{org_permalink}/servers')

    def create_server(self, org_permalink, name, permalink, mode='Live', **kwargs):
        data = {'name': name, 'permalink': permalink, 'mode': mode}
        data.update(kwargs)
        return self._request('POST', f'/api/v2/organizations/{org_permalink}/servers', data)

    def get_server_stats(self, org_permalink, server_permalink):
        return self._request('GET',
            f'/api/v2/organizations/{org_permalink}/servers/{server_permalink}/stats')

    # Domains
    def create_domain(self, org_permalink, server_permalink, name, **kwargs):
        data = {'name': name, 'verification_method': 'DNS'}
        data.update(kwargs)
        return self._request('POST',
            f'/api/v2/organizations/{org_permalink}/servers/{server_permalink}/domains', data)

    def verify_domain(self, org_permalink, server_permalink, domain_uuid):
        return self._request('POST',
            f'/api/v2/organizations/{org_permalink}/servers/{server_permalink}/domains/{domain_uuid}/verify')

    def check_domain_dns(self, org_permalink, server_permalink, domain_uuid):
        return self._request('POST',
            f'/api/v2/organizations/{org_permalink}/servers/{server_permalink}/domains/{domain_uuid}/check_dns')

    # Credentials
    def create_credential(self, org_permalink, server_permalink, name, cred_type='API', **kwargs):
        data = {'name': name, 'type': cred_type}
        data.update(kwargs)
        return self._request('POST',
            f'/api/v2/organizations/{org_permalink}/servers/{server_permalink}/credentials', data)

    # Users
    def create_user(self, first_name, last_name, email, password, admin=False):
        return self._request('POST', '/api/v2/users', {
            'first_name': first_name,
            'last_name': last_name,
            'email_address': email,
            'password': password,
            'email_verified': True
        })


# Пример использования
if __name__ == '__main__':
    api = PostalManagementAPI('https://postal.example.com', 'your_api_key')

    # Получение информации о системе
    print(api.get_info())

    # Создание организации и сервера
    user = api.create_user('John', 'Doe', 'john@example.com', 'SecurePass123')
    org = api.create_organization('Test Org', 'test-org', 'john@example.com')
    server = api.create_server('test-org', 'Mail Server', 'mail', send_limit=10000)
    domain = api.create_domain('test-org', 'mail', 'example.com')

    # Получение DNS записей
    dns_info = api.check_domain_dns('test-org', 'mail', domain['data']['domain']['uuid'])
    print(dns_info)
```

---

## Автоматизация установки

### Docker Compose для полной установки

```yaml
# /opt/postal/docker-compose.yml
version: '3.8'

services:
  mariadb:
    image: mariadb:latest
    container_name: postal-mariadb
    restart: always
    environment:
      MARIADB_DATABASE: postal
      MARIADB_ROOT_PASSWORD: ${DB_PASSWORD}
    volumes:
      - ./mariadb/data:/var/lib/mysql
      - ./mariadb/my.cnf:/etc/mysql/conf.d/my.cnf
    networks:
      - postal

  postal-web:
    image: ghcr.io/postalserver/postal:latest
    container_name: postal-web
    restart: always
    command: postal web-server
    depends_on:
      - mariadb
    environment:
      MANAGEMENT_API_KEY: ${MANAGEMENT_API_KEY}
    volumes:
      - ./config:/config
    networks:
      - postal

  postal-smtp:
    image: ghcr.io/postalserver/postal:latest
    container_name: postal-smtp
    restart: always
    command: postal smtp-server
    depends_on:
      - mariadb
    ports:
      - "25:25"
    volumes:
      - ./config:/config
    networks:
      - postal

  postal-worker:
    image: ghcr.io/postalserver/postal:latest
    container_name: postal-worker
    restart: always
    command: postal worker
    depends_on:
      - mariadb
    volumes:
      - ./config:/config
    networks:
      - postal

  caddy:
    image: caddy:latest
    container_name: postal-caddy
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/Caddyfile:/etc/caddy/Caddyfile
      - ./caddy-data:/data
    networks:
      - postal

networks:
  postal:
    driver: bridge
```

### Ansible playbook

```yaml
# postal-setup.yml
---
- name: Setup Postal Mail Server
  hosts: mail_servers
  become: yes
  vars:
    postal_domain: "mail.example.com"
    db_password: "secure_password"
    management_api_key: "your_secure_api_key"

  tasks:
    - name: Create directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      loop:
        - /opt/postal/config
        - /opt/postal/mariadb
        - /opt/postal/caddy-data

    - name: Copy MariaDB config
      copy:
        content: |
          [mysqld]
          character-set-server = utf8mb4
          collation-server = utf8mb4_unicode_ci
          max_allowed_packet = 256M
        dest: /opt/postal/mariadb/my.cnf

    - name: Start MariaDB
      docker_container:
        name: postal-mariadb
        image: mariadb:latest
        restart_policy: always
        env:
          MARIADB_DATABASE: postal
          MARIADB_ROOT_PASSWORD: "{{ db_password }}"
        volumes:
          - /opt/postal/mariadb/my.cnf:/etc/mysql/conf.d/my.cnf
        published_ports:
          - "127.0.0.1:3306:3306"

    - name: Clone Postal install repo
      git:
        repo: https://github.com/wsdexe/postal-install
        dest: /opt/postal/install

    - name: Create postal symlink
      file:
        src: /opt/postal/install/bin/postal
        dest: /usr/bin/postal
        state: link

    - name: Bootstrap Postal
      command: postal bootstrap {{ postal_domain }}
      args:
        creates: /opt/postal/config/postal.yml

    - name: Initialize Postal
      command: postal initialize

    - name: Start Postal
      command: postal start

    - name: Start Caddy
      docker_container:
        name: postal-caddy
        image: caddy:latest
        restart_policy: always
        network_mode: host
        volumes:
          - /opt/postal/config/Caddyfile:/etc/caddy/Caddyfile
          - /opt/postal/caddy-data:/data
```

---

## Коды ошибок

| Код | Описание |
|-----|----------|
| `AuthenticationRequired` | Отсутствует заголовок X-Management-API-Key |
| `InvalidAPIKey` | Неверный API ключ |
| `RecordNotFound` | Ресурс не найден |
| `ValidationError` | Ошибка валидации данных |
| `AlreadyMember` | Пользователь уже в организации |
| `NotAMember` | Пользователь не в организации |
| `CannotRemoveOwner` | Нельзя удалить владельца |
| `CannotDeleteLastAdmin` | Нельзя удалить последнего админа |
| `CannotRevokeLastAdmin` | Нельзя снять права у последнего админа |
| `VerificationFailed` | DNS верификация не пройдена |
| `UnsupportedVerificationMethod` | Неподдерживаемый метод верификации |

---

## Заметки по безопасности

1. **Защита API ключа**: Храните MANAGEMENT_API_KEY в безопасном месте
2. **HTTPS**: Всегда используйте HTTPS для доступа к API
3. **IP ограничения**: Рекомендуется ограничить доступ к API по IP
4. **Логирование**: Все API запросы логируются
5. **Rate limiting**: Рекомендуется настроить rate limiting на уровне веб-сервера
