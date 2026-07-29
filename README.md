<p align="center"><img src="github-header-kitmikhailo.png" width="100%" alt="CyberPW Assistant — інструментарій гравця"></p>
<h1 align="center">CyberPW Assistant</h1>
<p align="center">Неофіційний відкритий інструментарій для гравців CyberPW<br><strong>1.07 Beta · Windows 7/10/11 x64 · Portable · PowerShell 5.1</strong></p>
<p align="center"><a href="https://github.com/vitalikjukivskiy/titul_helper/releases"><img src="https://img.shields.io/github/downloads/vitalikjukivskiy/titul_helper/total?style=for-the-badge&logo=github&label=Downloads&color=0f9d7a" alt="Завантаження"></a> <a href="https://github.com/vitalikjukivskiy/titul_helper/releases/tag/v1.0.0"><img src="https://img.shields.io/github/v/release/vitalikjukivskiy/titul_helper?style=for-the-badge&label=Release&color=d4af37" alt="Версія 1.07 Beta"></a></p>
<p align="center"><a href="https://cyberpw.fun/">Сайт</a> · <a href="https://forum.cyberpw.fun/index.php?threads/titulhelper-1-0.271/">Тема на форумі</a> · <a href="https://cabinet.cyberpw.fun/">Кабінет</a> · <a href="https://cabinet.cyberpw.fun/register.php?ref=4550">Реєстрація з бонусом</a> · <a href="https://www.youtube.com/@Vitalik_Juk">YouTube</a> · <a href="https://send.monobank.ua/jar/93N5FBB3zX">Підтримати</a></p>

> [!IMPORTANT]
> Це неофіційний фанатський проєкт. Перед використанням макросів перевірте правила сервера. Синхронізація TitulHelper лише читає ID отриманих титулів із підтримуваної збірки клієнта та нічого в грі не змінює.

## Що входить

### TitulHelper

- база 260 точок запуску титулів у 37 ланцюжках;
- пошук, прогрес, відкриття списку титулів і введення координат мітки;
- синхронізація отриманих титулів одним натисканням без OCR;
- перевірка SHA256 клієнта: невідома збірка безпечно відхиляється;
- уточнення ланцюжка для титулів з однаковою назвою.

### MultiLauncher

- профілі персонажів, запуск одного, вибраних або всіх клієнтів;
- 10 класів Perfect World 1.4.6 з ілюстраціями;
- паролі шифруються Windows для поточного користувача;
- BAT-ярлики не містять логінів і паролів.

### Macro Studio (клікер) — Beta

> [!WARNING]
> Клікер перебуває у статусі **Beta**. Спочатку перевірте сценарій у безпечному вікні та переконайтеся, що призначена клавіша аварійної зупинки працює.

- графічний конструктор клавіатури й миші без написання коду;
- паузи, текст, цикли та очікування кольору пікселя;
- кнопка запуску й власна клавіша (`F10`, `F6`, `G`, `5` тощо) для кожного макросу;
- макроси зберігаються локально в `macros/*.json`.

### Карта територіальних війн (ГВГ) — Beta

> [!WARNING]
> Розділ ГВГ перебуває у статусі **Beta**: власники та бої вводяться локально й поки не синхронізуються із сервером.

- 51 інтерактивна територія з точними полігонами;
- власник, атакуючий, захисник, час бою, рівень і нагорода;
- локальний стан не потрапляє до Git.

### Інші модулі

- симулятор Скрині Тора;
- розморозка вибраних вікон `ElementClient`;
- 16 світових і 8 хроно-босів;
- календар івентів у лаунчері;
- літній темний дизайн, округлений інтерфейс і DPI-масштабування.

## Швидкий запуск

1. Відкрийте [реліз 1.07 Beta](https://github.com/vitalikjukivskiy/titul_helper/releases/tag/v1.0.0).
2. Завантажте `Cyber.pw-Asistant-Portable.zip`.
3. Повністю розпакуйте архів.
4. Запустіть `Запустити.bat`.
5. Для синхронізації увійдіть на персонажа й натисніть **СИНХРОНІЗУВАТИ** у TitulHelper.

Python, npm та сторонні бібліотеки не потрібні.

## Сумісність

| Система | Статус | Примітки |
|---|---:|---|
| Windows 11 x64 | ✅ | Повна підтримка, системні округлені кути |
| Windows 10 x64 | ✅ | Повна підтримка |
| Windows 7 SP1 x64 | ✅ | Потрібні .NET Framework 4.8 і Windows Management Framework 5.1 |

Синхронізація титулів підтримує перевірену збірку `ElementClient.exe` із SHA256 `ADF8444231C9B86BAB64359FA3E4980D4E9BF2A759E3314180771CEE30ED3D49`. Інші збірки не читаються до додавання окремого перевіреного профілю.

## Безпека й приватність

- TitulHelper виконує тільки читання ID титулів; запис у процес відсутній;
- програма не змінює файли гри та не встановлює драйвери;
- паролі MultiLauncher не зберігаються відкритим текстом;
- користувацькі `state.json`, `characters.json`, `territories.json`, `launcher-theme.json` і `macros/` виключені з Git;
- Для кожного макросу окремо зберігаються власні клавіші старту та аварійної зупинки.
- Додано умови кольору `IF`, `IF NOT`, вкладені блоки й надійне захоплення пікселя.

## Збірка

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Portable.ps1
```

Архів і контрольна сума з’являться у `dist/`.

## Посилання

- [Релізи](https://github.com/vitalikjukivskiy/titul_helper/releases)
- [Форумний гайд 1.07 Beta](FORUM-GUIDE-1.0.md)
- [Відеогайд](https://youtu.be/--JevuwyL7s)
- [GitHub автора](https://github.com/vitalikjukivskiy)
- [Повідомити про помилку](https://github.com/vitalikjukivskiy/titul_helper/issues)

Створив [**Кіт Михайло**](https://github.com/vitalikjukivskiy) для гравців CyberPW, клан **DarkSide**. Автор не належить до адміністрації CyberPW.
