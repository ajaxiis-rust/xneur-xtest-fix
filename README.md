# xneur / gxneur 0.21.0 — патчи для современных X11-систем

Патчи к форку [xneur-devel](https://github.com/AndrewCrewKuznetsov/xneur-devel) 0.21.0
(база: коммит `5a964810103cf73783f8f8ebb2998be8a5b91eda`, 18.10.2024),
которые возвращают автоматическую смену раскладки EN ⇄ RU на актуальных
дистрибутивах.

Проверено на **Ubuntu 22.04.5 LTS, XFCE 4.16, сеанс X11** (Xubuntu).
Работает в обе стороны: `ghbdtn ` → `привет `, `руддщ ` → `hello `.

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

Файл `xneur-0.21.0-xtest.patch` (300 строк, только ветка `xneur/`):

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

| Приложение | Ввод | Результат |
|---|---|---|
| zenity (GTK3) | `ghbdtn ` | `привет ` |
| xterm | `ghbdtn ` | `привет` |
| xfce4-terminal (VTE) | `ghbdtn ` | `привет` |
| zenity (раскладка RU) | `руддщ ` | `hello ` |
| xfce4-terminal (раскладка RU) | `руддщ ` | `hello` |

Окружение: Ubuntu 22.04.5, XFCE 4.16, X11, XKB `us,ru`
(`grp:win_space_toggle`), gcc 11, gxneur на GTK2, xneur-devel 0.21.0.

## Сборка на Ubuntu 22.04

Пакетов `xneur`/`gxneur` в репозиториях jammy нет — только из исходников.

```bash
sudo apt install build-essential autoconf automake libtool pkg-config \
  intltool gettext libx11-dev libxi-dev libxtst-dev libpcre3-dev \
  libenchant-2-dev libnotify-dev libgtk2.0-dev libappindicator-dev \
  aspell-en aspell-ru hunspell-en-us hunspell-ru

git clone https://github.com/AndrewCrewKuznetsov/xneur-devel.git
cd xneur-devel

# Заголовки enchant-2 в Debian лежат плоско, а код ждёт <enchant/enchant.h>
mkdir -p /tmp/enchant-compat/enchant
for h in enchant.h enchant-provider.h enchant++.h; do
  ln -sf /usr/include/enchant-2/$h /tmp/enchant-compat/enchant/$h
done

cd xneur
./autogen.sh
./configure --prefix=/usr/local --with-sound=no --without-xosd \
  --without-keylogger CPPFLAGS="-I/tmp/enchant-compat"
touch INSTALL            # automake требует INSTALL, в репозитории его нет
make -j4
sudo make install && sudo ldconfig
cd ..

cd gxneur
./autogen.sh
touch README INSTALL TODO   # без них automake падает
./configure --prefix=/usr/local
make -j4
sudo make install && sudo ldconfig
```

Установка кладёт конфиг в `/usr/local/etc/xneur/xneurrc`; **`make install`
перезаписывает его шаблоном из `etc/xneurrc`** — применяйте в патче `xneurrc`
до сборки или повторяйте настройку после переустановки.

Автозапуск (XFCE): `~/.config/autostart/gxneur.desktop` с `Exec=gxneur`.

## Известные ограничения

- Горячая клавиша `Pause/Break` (принудительное исправление слова) в патче не
  тестировалась — на тестовой клавиатуре её нет.
- Проверена пара EN/RU; остальные языки конфигурируются штатно (словари в
  `share/xneur/languages`).
- Патч написан против master форка на 18.10.2024 — при обновлении базы
  возможны конфликты.

## Лицензия

GPL-2.0-or-later, как и сам xneur (см. `COPYING`).
Патч — производная работа; ссылки на upstream сохранены.

---

## English summary

Patch set for **xneur/gxneur 0.21.0** (xneur-devel fork) that restores
automatic EN ⇄ RU keyboard layout correction on modern X11 desktops.
Tested on Ubuntu 22.04.5 LTS, XFCE, X11: `ghbdtn ` → `привет `,
`руддщ ` → `hello `, including terminals (xterm, VTE).

Three fixes:
1. Text is injected with `XTestFakeKeyEvent` instead of `XSendEvent`
   (modern GTK3/VTE/xterm reject or drop synthetic SendEvent keys).
2. The word is deleted together with the already-delivered delimiter, which
   is re-sent after the corrected word (fixes the lost first letter and space).
3. XI2 echo of our own XTEST injection is filtered through a press-keycode
   queue, flushed on focus change (fixes self-correction loops).
