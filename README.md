# Model Pool — пул AI-подписок через CLIProxyAPI

Один локальный шлюз (`http://127.0.0.1:8317/v1`) объединяет все ваши подписки
(ChatGPT, Claude, Kimi) в единый OpenAI-совместимый эндпоинт с автоматической
балансировкой между аккаунтами.

## Что это даёт

- **Обход рейт-лимитов** — N аккаунтов = в N раз больше запросов. Шлюз сам
  переключается на следующий аккаунт при 429/исчерпании квоты.
- **Одна точка входа** — ваши инструменты (Codex CLI, Claude Code, Cursor,
  Hermes, любой OpenAI-клиент) ходят на один `base_url`, не зная сколько у вас
  подписок и какие.
- **Автоматический OAuth** — логинитесь в браузере один раз, шлюз сам обновляет
  токены. Никаких ручных API-ключей.
- **Session affinity** — один диалог не прыгает между аккаунтами (важно для
  prompt caching).

## Быстрый старт

### 1. Скачайте бинарник

```bash
# Linux x86_64
curl -sL https://github.com/router-for-me/CLIProxyAPI/releases/latest/download/cli-proxy-api-linux-amd64 -o cli-proxy-api
chmod +x cli-proxy-api

# macOS (Apple Silicon)
curl -sL https://github.com/router-for-me/CLIProxyAPI/releases/latest/download/cli-proxy-api-darwin-arm64 -o cli-proxy-api
chmod +x cli-proxy-api

# macOS (Intel)
curl -sL https://github.com/router-for-me/CLIProxyAPI/releases/latest/download/cli-proxy-api-darwin-amd64 -o cli-proxy-api
chmod +x cli-proxy-api
```

Или Docker:

```bash
docker compose up -d
```

### 2. Сгенерируйте клиентский ключ

```bash
openssl rand -hex 32
# Пример вывода: 0a4028c7e30f19f40576abed980e638460836a0096f8dac2a56653332199a764
```

### 3. Подставьте ключ в config.yaml

Откройте `config.yaml` и замените `ПОДСТАВЬТЕ_СВОЙ_КЛЮЧ_СЮДА` на сгенерированный ключ.

### 4. Запустите шлюз

```bash
./cli-proxy-api --config config.yaml
```

Шлюз поднимется на `127.0.0.1:8317`.

### 5. Добавьте подписки (OAuth-логин)

Каждую подписку нужно авторизовать один раз — шлюз откроет браузер для входа.

**ChatGPT Codex:**

```bash
./cli-proxy-api --config config.yaml -codex-device-login
```

**Claude:**

```bash
./cli-proxy-api --config config.yaml -claude-login
```

После логина в папке `auths/` появятся OAuth-токены. Шлюз будет автоматически
их обновлять. Повторите для каждой подписки (аккаунта).

### 6. Проверьте

```bash
curl http://127.0.0.1:8317/v1/models \
  -H "Authorization: Bearer ВАШ_КЛЮЧ"
```

Должен вернуть список доступных моделей от всех ваших подписок.

## Подключение инструментов

### Codex CLI

```bash
export CODEX_API_BASE_URL="http://127.0.0.1:8317/v1"
export CODEX_API_KEY="ваш_клиентский_ключ"
codex
```

### Claude Code

```bash
export ANTHROPIC_BASE_URL="http://127.0.0.1:8317/v1"
export ANTHROPIC_API_KEY="ваш_клиентский_ключ"
claude
```

### Любой OpenAI-совместимый клиент

```yaml
# Пример: Hermes config.yaml
model:
  provider: pool
  base_url: http://127.0.0.1:8317/v1

providers:
  pool:
    name: pool
    base_url: http://127.0.0.1:8317/v1
    api_key: ваш_клиентский_ключ
    api_mode: chat_completions
```

## Как это работает

```
Ваши инструменты                  Шлюз (127.0.0.1:8317)          Подписки
┌──────────────┐                 ┌─────────────────────┐      ┌──────────────┐
│ Codex CLI    │────req─────────▶│                     │─────▶│ ChatGPT Pro  │
│ Claude Code  │                 │  CLIProxyAPI        │      │ ChatGPT Plus │
│ Cursor       │                 │  round-robin        │─────▶│ Claude Max   │
│ Hermes       │                 │  + cooldown per 429 │      │ Kimi K3      │
└──────────────┘                 └─────────────────────┘      └──────────────┘
```

- **Round-robin** — запросы равномерно распределяются по аккаунтам.
- **Cooldown** — если подписка исчерпала квоту (429), она временно исключается
  из пула и запросы идут на остальные.
- **Session affinity** — запросы в рамках одного диалога идут на один и тот же
  аккаунт (сохраняет prompt cache).
- **OAuth auto-refresh** — токены обновляются автоматически, ручного
  вмешательства не требуется.

## Пул с Kimi (API-ключ)

Если у вас подписка, выдающая обычный API-ключ (например Kimi), добавьте в `config.yaml`:

```yaml
claude-api-key:
  - api-key: "sk-ваш_ключ_kimi"
    base-url: "https://api.moonshot.cn/coding"
    models:
      - name: "kimi-k3"
        alias: "kimi-k3"
```

## Обслуживание

- **Посмотреть остатки квот:** запросите usage endpoint шлюза или проверьте
  логи в `logs/`.
- **Добавить новый аккаунт:** ещё раз `-codex-device-login` / `-claude-login`.
- **Удалить аккаунт:** удалите соответствующий `.json` файл из `auths/` и
  перезапустите шлюз.
- **Обновить бинарник:** скачайте новый релиз с GitHub и перезапустите.

## Безопасность

- Шлюз слушает **только** `127.0.0.1` — недоступен из сети.
- `auths/` содержит OAuth-токены ваших подписок — **не коммитьте** эту папку.
- Клиентский ключ в `config.yaml` — **не публикуйте** его.

## Ссылки

- [CLIProxyAPI на GitHub](https://github.com/router-for-me/CLIProxyAPI) —
  исходники, issues, полная документация.
- [Релизы](https://github.com/router-for-me/CLIProxyAPI/releases) — бинарники
  под все платформы.