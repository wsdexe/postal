# Диагностика проблемы с публикацией пакетов

## Что проверить

### 1. Проверьте логи последнего workflow run

1. Откройте Actions на GitHub: https://github.com/wsdexe/postal/actions
2. Найдите последний workflow run "CI"
3. Откройте job "Build Latest Package"
4. Проверьте следующие шаги:

#### Шаг "Login to GitHub Container Registry"
Должен показать успешный логин:
```
Login Succeeded
```

#### Шаг "Debug metadata"
Должен показать теги, например:
```
Tags: ghcr.io/wsdexe/postal:latest
      ghcr.io/wsdexe/postal:main-1758b25
      ghcr.io/wsdexe/postal:main
```

#### Шаг "Build and push Docker image"
**САМЫЙ ВАЖНЫЙ** - ищите строки с "pushing":
```
#14 pushing manifest for ghcr.io/wsdexe/postal:latest
#14 done
```

Если видите ошибки типа `denied`, `unauthorized`, `permission_denied` - значит проблема в токене.

### 2. Проверьте напрямую существование пакета

Откройте в браузере:
```
https://github.com/wsdexe/postal/pkgs/container/postal
```

или

```
https://github.com/orgs/wsdexe/packages/container/postal
```

или

```
https://github.com/users/wsdexe/packages/container/postal
```

Если пакет существует, но не отображается в разделе Packages репозитория - значит он не связан с репозиторием.

### 3. Проверьте права токена CR_PAT

1. GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Найдите токен, который используется как CR_PAT
3. Проверьте:
   - ✅ Токен не истек
   - ✅ Есть scope: `write:packages`
   - ✅ Есть scope: `read:packages`
   - ✅ Токен принадлежит пользователю `wsdexe` (владельцу репозитория)

### 4. Попробуйте вручную pull образ

Если workflow показывает успешную публикацию, попробуйте:

```bash
# Для публичного пакета
docker pull ghcr.io/wsdexe/postal:latest

# Для приватного пакета (сначала логин)
echo $YOUR_TOKEN | docker login ghcr.io -u wsdexe --password-stdin
docker pull ghcr.io/wsdexe/postal:latest
```

## Возможные проблемы и решения

### Проблема 1: Токен CR_PAT не имеет прав

**Решение**: Создайте новый PAT с правами `write:packages` и обновите секрет CR_PAT

### Проблема 2: Пакет приватный и не отображается

**Решение**: После публикации перейдите в настройки пакета и:
1. Измените видимость на Public (если нужно)
2. Свяжите пакет с репозиторием wsdexe/postal

### Проблема 3: Workflow не запускается

**Решение**: Workflow запускается только при push в main. Убедитесь, что PR смержен в main.

### Проблема 4: Нет прав на публикацию в namespace wsdexe

**Решение**: Убедитесь, что токен принадлежит пользователю wsdexe или организации wsdexe

## Что я уже исправил

1. ✅ Изменен `github.actor` на `github.repository_owner` для правильной аутентификации
2. ✅ Добавлен `docker/metadata-action` для генерации правильных тегов и labels
3. ✅ Добавлены отладочные шаги для диагностики
4. ✅ Настроен `permissions: packages: write` в workflow

## Следующие шаги

Пожалуйста, проверьте логи последнего workflow run (особенно шаг "Build and push Docker image") и сообщите:

1. Прошел ли успешно docker push?
2. Есть ли ошибки в логах?
3. Показывает ли он "pushing manifest" и "done"?

Это поможет определить точную причину проблемы.
