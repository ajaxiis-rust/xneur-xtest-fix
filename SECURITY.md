# Безопасность

## Что проверяется автоматически

| Проверка | Где смотреть | Что значит |
|---|---|---|
| `build-and-scan` | вкладка Actions, бейдж в README | пакет собирается из этого коммита, `lintian` не находит ошибок, ClamAV не находит вирусов в `.deb` и в его распакованном содержимом |
| `codeql` | Security → Code scanning | статический анализ C-кода (переполнения буферов, разыменование, утечки) |
| `scorecard` | Security → Code scanning, бейдж | гигиена репозитория по методике OpenSSF |
| Dependabot | Security → Dependabot | обновления версий GitHub Actions |
| Secret scanning, push protection | Settings → Code security | блокировка коммитов с ключами и токенами |
| Provenance | `gh attestation verify` | артефакт собран workflow из этого репозитория |

## Как проверить скачанный файл

```bash
sha256sum xneur-xtest_0.21.0-xtest2_amd64.deb
# сверьте с SHA256SUMS из релиза

gh attestation verify xneur-xtest_0.21.0-xtest2_amd64.deb \
  --repo ajaxiis-rust/xneur-xtest-fix
```

## Что показывает CodeQL

Анализируются только файлы демона (`src/xneur/lib`, `src/xneur/src`,
`src/xneur/plugins`) после наложения патча. Первый прогон находит 22
предупреждения, все — в неизменённом коде upstream:

- `cpp/path-injection` и `cpp/world-writable-file-creation` — работа с путями
  из `$HOME` и правами на файлы конфигурации;
- `cpp/potentially-dangerous-function` — `strcpy`/`system` в разборе ввода;
- `cpp/incorrectly-checked-scanf`, `cpp/integer-multiplication-cast-to-long`.

Наш патч (`event.c`, `program.c`) новых предупреждений не добавляет. Список
открыт целиком в Security → Code scanning, чтобы его можно было проверить
самостоятельно.

## Сообщить о проблеме

Откройте приватный отчёт: вкладка **Security** → **Report a vulnerability**.
Публичный issue тоже годится, если в отчёте нет эксплойта.
