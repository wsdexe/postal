# Настройка публикации в GitHub Packages

## Проблема
При попытке публикации Docker образа в GitHub Container Registry возникает ошибка:
```
failed to push ghcr.io/wsdexe/postal:main: denied: permission_denied: write_package
```

## Решение

### Вариант 1: Настройка Workflow Permissions (Рекомендуется)

1. Откройте настройки репозитория на GitHub
2. Перейдите в **Settings** → **Actions** → **General**
3. Найдите секцию **Workflow permissions**
4. Выберите **"Read and write permissions"**
5. Убедитесь, что включена опция **"Allow GitHub Actions to create and approve pull requests"**
6. Нажмите **Save**

После этого:
- Перезапустите failed workflow run через GitHub UI
- Или сделайте новый push в main ветку

### Вариант 2: Personal Access Token (Альтернатива)

Если вариант 1 не работает или вы хотите использовать отдельный токен:

1. Создайте Personal Access Token (classic):
   - Перейдите в **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
   - Нажмите **Generate new token (classic)**
   - Выберите scopes:
     - `write:packages` - для публикации пакетов
     - `read:packages` - для чтения пакетов
     - `delete:packages` - (опционально) для удаления старых версий
   - Скопируйте созданный токен

2. Добавьте токен как секрет в репозиторий:
   - Откройте **Settings** → **Secrets and variables** → **Actions**
   - Нажмите **New repository secret**
   - Name: `GHCR_TOKEN`
   - Value: вставьте скопированный токен
   - Нажмите **Add secret**

3. Обновите `.github/workflows/ci.yml` (строка 27):
   ```yaml
   - uses: docker/login-action@v3
     with:
       registry: ${{ env.REGISTRY }}
       username: ${{ github.actor }}
       password: ${{ secrets.GHCR_TOKEN }}  # Изменено с GITHUB_TOKEN
   ```

## Проверка

После настройки:

1. Проверьте, что workflow успешно выполнился
2. Откройте страницу репозитория на GitHub
3. Перейдите в раздел **Packages** (справа на главной странице репозитория)
4. Вы должны увидеть опубликованный пакет `postal`

## Использование опубликованного образа

После успешной публикации:

```bash
# Публичный репозиторий (если пакет публичный)
docker pull ghcr.io/wsdexe/postal:latest

# Приватный репозиторий (требуется аутентификация)
echo $GHCR_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
docker pull ghcr.io/wsdexe/postal:latest
```

## Доступные теги

После публикации будут доступны следующие теги:
- `latest` - последняя версия из main ветки
- `main` - последняя версия из main ветки
- `main-<sha>` - версия с конкретным хешем коммита

Пример:
```bash
docker pull ghcr.io/wsdexe/postal:latest
docker pull ghcr.io/wsdexe/postal:main
docker pull ghcr.io/wsdexe/postal:main-b698c7
```
