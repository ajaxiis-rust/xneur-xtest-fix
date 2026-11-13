# xneur / gxneur 0.21.0 — патчи и готовая сборка для современных X11-систем

[![build-and-scan](https://github.com/ajaxiis-rust/xneur-xtest-fix/actions/workflows/ci.yml/badge.svg)](https://github.com/ajaxiis-rust/xneur-xtest-fix/actions/workflows/ci.yml)
[![CodeQL](https://github.com/ajaxiis-rust/xneur-xtest-fix/actions/workflows/codeql.yml/badge.svg)](https://github.com/ajaxiis-rust/xneur-xtest-fix/actions/workflows/codeql.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/ajaxiis-rust/xneur-xtest-fix/badge)](https://securityscorecards.dev/viewer/?uri=github.com/ajaxiis-rust/xneur-xtest-fix)
[![ClamAV](https://img.shields.io/badge/ClamAV-проверено-1f9e3d)](https://github.com/ajaxiis-rust/xneur-xtest-fix/actions/workflows/ci.yml)

Патчи к форку [xneur-devel](https://github.com/AndrewCrewKuznetsov/xneur-devel) 0.21.0
(база: коммит `5a964810103cf73783f8f8ebb2998be8a5b91eda`, 18.10.2024),
которые возвращают автоматическую смену раскладки EN ⇄ RU на актуальных
дистрибутивах. Плюс скрипт, который собирает из этого один `.deb`.

Проверено на **Ubuntu 22.04.5 LTS, XFCE 4.16, сеанс X11** (Xubuntu).
Работает в обе стороны: `ghbdtn ` → `привет `, `руддщ ` → `hello `.

## Быстрая установка (один файл)

Версия пакета: **0.21.0-xtest2**, архитектура **amd64**, собрано и проверено
на Ubuntu 22.04 (jammy). Пакет собирается автоматически в GitHub Actions из
этого репозитория: сборка, `lintian`, ClamAV и provenance на каждый тег.

```bash
wget https://github.com/ajaxiis-rust/xneur-xtest-fix/releases/latest/download/xneur-xtest_0.21.0-xtest2_amd64.deb
sudo apt install ./xneur-xtest_0.21.0-xtest2_amd64.deb
```

`apt install ./файл.deb` сам подтянет зависимости. После установки:

- gXNeur добавлен в автозапуск (`/etc/xdg/autostart/gxneur.desktop`) — появится
  после следующего входа в сеанс;
- запустить сразу: `gxneur &` или меню → Настройки → gXNeur;
- значок в трее, настройки — в меню значка.

Удалить: `sudo apt remove xneur-xtest` (конфиг `/etc/xneur/xneurrc` останется,
`apt purge` удалит и его).

Что внутри пакета: `xneur`, `gxneur`, `libxneur`/`libxnconfig`, плагины,
словари и звуки, man-страницы, `.desktop`-файлы, автозапуск.

## Проверки перед скачиванием

Результаты лежат на вкладке [Actions](https://github.com/ajaxiis-rust/xneur-xtest-fix/actions)
и в Security, до установки пакета.

| Проверка | Где | Что подтверждает |
|---|---|---|
| сборка из тега | `build-and-scan` | `.deb` собирается из этого коммита на чистом ubuntu-22.04 |
| lintian | `build-and-scan` | ошибок в метаданных пакета нет |
| вирусы | `build-and-scan` | ClamAV проверил `.deb` и его распакованное содержимое, заражённых файлов нет |
| уязвимости в коде | `codeql` | статический анализ C: переполнения, разыменования, утечки — в Security → Code scanning |
| гигиена репозитория | `scorecard` | методика OpenSSF, балл виден в бейдже |
| версии Actions | Dependabot | обновления приходят отдельными PR |
| подлинность артефакта | provenance | `gh attestation verify` сверяет файл со сборкой в этом репозитории |

Проверить скачанное самому:

```bash
sha256sum xneur-xtest_0.21.0-xtest2_amd64.deb      # сверьте с SHA256SUMS из релиза
gh attestation verify xneur-xtest_0.21.0-xtest2_amd64.deb \
  --repo ajaxiis-rust/xneur-xtest-fix
```

Чего эти проверки не делают: GitHub не сканирует deb-архивы сам — вирусы ищет
workflow через ClamAV, а он знает только известные сигнатуры. Аудит кода
покрывает наш C-код, а не библиотеки из дистрибутива (их патчит Ubuntu).

## Почему без патча не работает

Собранный из исходников xneur 0.21.0 на jammy ведёт себя так:

1. **Исправление теряет первую букву и пробел.** Ввод `ghbdtn ` даёт
   `gпривет` со съеденным разделителем: коррекция удаляет `len` символов,
   хотя курсор стоит уже *после* пробела, и не возвращает разделитель.
2. **В терминалах коррекция не появляется вовсе.** Текст вставляется через
   `XSendEvent` — синтетические нажатия отвергают VTE (`xfce4-terminal`,
   `gnome-terminal`) и `xterm` (у него `allowSendEvents` выключен по
   умолчанию), а GTK3 теряет часть событий с одинаковым временем.
3. **Свои же инъекции попадают в буфер как пользовательский ввод**, если
   перейти на XTEST без фильтра: XI2-события от XTEST неотличимы от нажатий
   с клавиатуры, и xneur начинает «исправлять» собственный вывод (гонки,
   ложные срабатывания, авто-дополнение не к месту).
4. Старые умолчания конфига заточены под Punto-подобное поведение
   пользователя, а не под автоматическую коррекцию.

## Что меняет патч

Файл `xneur-0.21.0-xtest.patch` (только ветка `xneur/`):

### `lib/main/event.c`
- `event_send_xkey()` переписан на `XTestFakeKeyEvent()`: нажатие и отпускание
  через XTEST, поддержка `Shift` для заглавных букв, пауза `SendDelay` после
  каждого события. Такие события принимают все приложения — как с настоящей
  клавиатуры.
- Очередь собственных инъекций (только press-коды): `event_is_own_injection()`,
  `event_flush_own_queue()`. Эхо XTEST-нажатий приходит демону через XI2 и
  отфильтровывается.
- Убран устаревший путь `XSendEvent` (включая трюк `CompatibilityWithCompletion`,
  который вставлял `|` перед коррекцией).

### `lib/main/program.c`
- В обработчике `XI_KeyPress` события собственной инъекции пропускаются
  (`event_is_own_injection`), `KeyRelease` обрабатывается как раньше.
- `program_update()` сбрасывает очередь эха при смене фокуса: нажатия,
  набранные в новом окне, не могут совпасть с протухшими записями.
- `CHANGE_WORD_TO_LAYOUT_*`: слово удаляется вместе с уже доставленным
  разделителем (пробел, запятая и т. д. из `delimeters`), после исправленного
  слова разделитель отправляется заново через XTEST.

### `etc/xneurrc` (умолчания под автокоррекцию)
```
EducationMode No            # не «учиться», а исправлять
CheckOnProcess No           # исправлять по концу слова, а не на лету
TroubleshootSwitch No       # не глушить автопереключение после смены раскладки
SendDelay 30                # мс между синтетическими событиями
CompatibilityWithCompletion No
Autocompletion No           # без автодополнения слов
CorrectIncidentalCaps No
CorrectTwoCapitalLetter No
CorrectCapitalLetterAfterDot No
CorrectDashWithEmDash No
LogLevel Log                # Trace писал каждую клавишу в журнал
```

## Проверенная матрица

Клавиши подавались физическими кодами через XTEST (как с настоящей
клавиатуры), в одном окне подряд, без ручного переключения раскладки.
Строка `ghbdtn rullo terminal`, где второе слово набиралось уже в русской
раскладке:

| Приложение | Результат |
|---|---|
| zenity (GTK3) | `привет hello terminal` |
| xterm | `привет hello terminal` |
| xfce4-terminal (VTE) | `привет hello terminal` |

То есть: `ghbdtn ` → `привет ` (раскладка переключилась на RU),
`руддщ ` → `hello ` (переключилась обратно на EN), а настоящее английское
слово `terminal` осталось без изменений. Отдельно проверено, что после
коррекции раскладка остаётся переключённой (XkbLockGroup на группу RU
держится, пока фокус в том же окне).

Окружение: Ubuntu 22.04.5, XFCE 4.16, X11, XKB `us,ru`
(`grp:win_space_toggle`), gcc 11, gxneur на GTK2, xneur-devel 0.21.0.

## Сборка .deb из исходников

```bash
sudo apt install build-essential autoconf automake libtool pkg-config \
  intltool gettext libx11-dev libxi-dev libxtst-dev libpcre3-dev \
  libenchant-2-dev libnotify-dev libgtk2.0-dev libappindicator-dev patchelf

git clone https://github.com/ajaxiis-rust/xneur-xtest-fix.git
cd xneur-xtest-fix
./packaging/build-deb.sh       # -> dist/xneur-xtest_0.21.0-xtest2_amd64.deb
```

Скрипт клонирует upstream на зафиксированный коммит, накладывает патч, собирает
`xneur` и `gxneur` с `--prefix=/usr --sysconfdir=/etc`, укладывает всё в один
архив и ставит метаданные из `packaging/debian/`. Правки метаданных — control,
conffiles, postinst/prerm, shlibs, triggers, автозапуск.

### Сборка вручную (без пакета)

```bash
git clone https://github.com/AndrewCrewKuznetsov/xneur-devel.git
cd xneur-devel
git apply ../xneur-0.21.0-xtest.patch

# Заголовки enchant-2 в Debian лежат плоско, а код ждёт <enchant/enchant.h>
mkdir -p /tmp/enchant-compat
ln -sfn /usr/include/enchant-2 /tmp/enchant-compat/enchant

cd xneur
touch INSTALL            # automake требует INSTALL, в репозитории его нет
./autogen.sh --prefix=/usr/local --with-sound=no --without-xosd \
  --without-keylogger CPPFLAGS="-I/tmp/enchant-compat"
make -j4 && sudo make install && sudo ldconfig
cd ..

cd gxneur
touch README INSTALL TODO   # без них automake падает
./autogen.sh --prefix=/usr/local
make -j4 && sudo make install && sudo ldconfig
```

`make install` кладёт конфиг в `$sysconfdir/xneur/xneurrc` и **перезаписывает
его шаблоном из `etc/xneurrc`** — свои правки держите в `~/.xneur/xneurrc`
(он читается первым) или повторяйте настройку из GUI.

## Какой конфиг читается

Порядок поиска в коде (`lib/config/xnconfig_files.c`):

1. `~/.xneur/xneurrc` — пользовательский, перекрывает всё;
2. `/etc/xneur/xneurrc` — из этого пакета (conffile, правки переживают
   обновление);
3. `/usr/share/xneur`.

Если коррекция «не слушается», проверьте, нет ли у вас старого
`~/.xneur/xneurrc` с `EducationMode Yes`.

## Известные ограничения

- `Pause/Break` (принудительное исправление слова) и остальные горячие клавиши
  в патче не тестировались — на тестовой клавиатуре этой клавиши нет.
- Проверена пара EN/RU; остальные языки конфигурируются штатно (словари в
  `share/xneur/languages`).
- `.deb` собран под amd64/jammy. На других архитектурах и выпусках
  пересоберите `packaging/build-deb.sh` — код X11 не привязан к версии
  дистрибутива.
- Патч написан против master форка на 18.10.2024 — при обновлении базы
  возможны конфликты.
- gxneur — на GTK2, поэтому в дистрибутивах без `libgtk2.0-0` потребуется
  собрать его отдельно.

## Лицензия

GPL-2.0-or-later, как и сам xneur (см. `COPYING`).
Патч и пакет — производная работа; ссылки на upstream сохранены.

---

## English summary

Patched build of **xneur/gxneur 0.21.0** (xneur-devel fork) that restores
automatic EN ⇄ RU keyboard layout correction on modern X11 desktops, plus a
script that produces a single installable `.deb`.

Install: download
`xneur-xtest_0.21.0-xtest2_amd64.deb` from the latest release and run
`sudo apt install ./xneur-xtest_0.21.0-xtest2_amd64.deb`.

Three fixes:
1. Text is injected with `XTestFakeKeyEvent` instead of `XSendEvent`
   (modern GTK3/VTE/xterm reject or drop synthetic SendEvent keys).
2. The word is deleted together with the already-delivered delimiter, which
   is re-sent after the corrected word (fixes the lost first letter and space).
3. XI2 echo of our own XTEST injection is filtered through a press-keycode
   queue, flushed on focus change (fixes self-correction loops).

Verified on Ubuntu 22.04.5 LTS, XFCE, X11 with physical keycodes in one line:
`ghbdtn rullo terminal` → `привет hello terminal` in zenity, xterm and
xfce4-terminal.
