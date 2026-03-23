# GliderProxy Manager

<div align="center">

**Интерактивный bash-менеджер для [Glider](https://github.com/nadoo/glider) — быстрого HTTP/SOCKS5 прокси-сервера**

<div align="center">
  
![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![Linux](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)
![Glider](https://img.shields.io/badge/Glider-v0.16.4-00BFFF?style=for-the-badge&logo=probot&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)
![Requires](https://img.shields.io/badge/Requires-Root%20%2F%20Sudo-red?style=for-the-badge&logo=linux&logoColor=white)
![Stars](https://img.shields.io/github/stars/thekhabaroff/GliderProxy?style=for-the-badge)
![Last Commit](https://img.shields.io/github/last-commit/thekhabaroff/GliderProxy?style=for-the-badge)
![Issues](https://img.shields.io/github/issues/thekhabaroff/GliderProxy?style=for-the-badge) </div>

</div>

---

## Возможности

- **Установка** — скачивает Glider, создаёт конфиг и регистрирует systemd-службу
- **Управление пользователями** — добавление, изменение, удаление; навигация стрелками ↑↓
- **Два режима** — с авторизацией (логин + пароль) или открытый доступ
- **Обновление** — бинарника и самого скрипта в один клик
- **Спиннер** — анимированный прогресс `⠋ → ✓` для каждой операции
- **Валидация** — портов, логинов, паролей, занятости порта
- **Удаление** — полная очистка бинарника, конфига и службы

---

## Быстрый старт

```bash
sudo bash -c 'wget -q https://raw.githubusercontent.com/thekhabaroff/GliderProxy/main/glider.sh -O /usr/local/bin/glider-manager && chmod +x /usr/local/bin/glider-manager && mv /usr/local/bin/glider /usr/local/bin/glider-bin 2>/dev/null || true && ln -sf /usr/local/bin/glider-manager /usr/local/bin/glider && sed -i "s|ExecStart=/usr/local/bin/glider |ExecStart=/usr/local/bin/glider-bin |g" /etc/systemd/system/glider.service 2>/dev/null || true && systemctl daemon-reload 2>/dev/null && systemctl restart glider 2>/dev/null || true' && sudo glider
```

> Требуются права **root** (`sudo`)

---

## Требования

| Зависимость | Версия | Примечание |
|-------------|--------|------------|
| bash | ≥ 4.0 | предустановлен в большинстве дистрибутивов |
| systemd | любая | для управления службой |
| wget | любая | для скачивания бинарника |
| tar | любая | для распаковки архива |

---

## Установка — пример вывода

```
  Установка Glider
  ────────────────────────────────

  Логин: myuser
  Пароль: **

  ✓  Обновление пакетов...
  ✓  Установка зависимостей...
  ✓  Скачивание Glider v0.16.4...
  ✓  Распаковка архива...
  ✓  Копирование бинарника...
  ✓  Регистрация службы...
  ✓  Включение автозапуска...
  ✓  Запуск службы...

  ✓  Установка завершена

  IP      45.151.182.221
  Порт    55555
  Логин   myuser
  Пароль  mypassword

  HTTP    http://myuser:mypassword@45.151.182.221:55555
  SOCKS5  socks5://myuser:mypassword@45.151.182.221:55555
```

---

## Структура файлов

```
/usr/local/bin/glider-bin            — бинарный файл Glider
/usr/local/bin/glider-manager        — скрипт менеджера
/etc/glider/glider.conf              — конфигурация прокси
/etc/systemd/system/glider.service   — systemd-юнит
```

---

## Конфигурация

Файл `/etc/glider/glider.conf` создаётся автоматически. Пример:

```ini
verbose=False

listen=mixed://user:password@:55555

forward=direct://

check=http://www.msftconnecttest.com/connecttest.txt#expect=200
checkinterval=30
checktimeout=10

strategy=rr
```

---

## Управление службой вручную

```bash
systemctl status glider      # статус
systemctl restart glider     # перезапуск
systemctl stop glider        # остановка
journalctl -u glider -f      # логи в реальном времени
```

## ☕ Поддержать проект

Если скрипт сэкономил тебе время — можешь поддержать разработку криптовалютой:

<details>
<summary><b>🟠 BTC</b></summary>

```
1CAWPNFJMAWxCany1A317yqHoZz4mq9MTE
```

</details>

<details>
<summary><b>🔷 EVM</b></summary>

```
0xbdfa3a427e457a99d7254af04b44fe76c347bd10
```

</details>

<details>
<summary><b>💚 TRC</b></summary>

```
TFGa8KRdcyCv3gk6khGU8NQvR8ot5UtiP5
```

</details>

<details>
<summary><b>🟣 TON</b></summary>

```
UQCacF30U98zSCbzd1NM5qMjjdkTygJwMjgDURobdXTIDN4-
```

</details>

<details>
<summary><b>💜 SOL</b></summary>

```
ETdRsuSYgpijG4RFckEQUoLfQ4CctibcoshTKyk1sCoW
```

</details>

<details>
<summary><b>🔵 APT</b></summary>

```
0x82b02deef3c3d8d21a665c53d9ea2e046813b6a92085efbc241b8acf69dc3af5
```

</details>

> Каждый донат мотивирует развивать проект дальше 🙏

---

## 📄 Лицензия

[MIT](LICENSE) — используйте свободно, упоминание автора приветствуется.

---

<div align="center">⭐ Поставь звезду, если проект оказался полезным!</div>
