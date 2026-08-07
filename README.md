<p align="center"><img src="github-header-kitmikhailo.png" width="100%" alt="CyberPW Assistant"></p>
<h1 align="center">CyberPW Assistant</h1>
<p align="center">Неофіційний відкритий інструментарій для гравців CyberPW</p>
<p align="center">
<a href="https://github.com/vitalikjukivskiy/titul_helper-2.0/releases"><img src="https://img.shields.io/github/v/release/vitalikjukivskiy/titul_helper-2.0?include_prereleases&style=for-the-badge&label=Version" alt="Latest release"></a>
<a href="https://github.com/vitalikjukivskiy/titul_helper-2.0/releases"><img src="https://img.shields.io/github/downloads/vitalikjukivskiy/titul_helper-2.0/total?style=for-the-badge&logo=github&label=Downloads" alt="Downloads"></a>
</p>

> [!IMPORTANT]
> Це неофіційний фанатський проєкт. Перед використанням автоматизації перевіряйте правила сервера.

> [!WARNING]
> CyberPW Assistant 2.x має статус Beta. Окремі функції залежать від Windows, DPI, прав доступу та конкретної збірки `ElementClient`.

## Можливості

### TitulHelper

- база титулів, пошук, ланцюжки та прогрес;
- автоматичне введення координат мітки;
- синхронізація отриманих титулів без OCR;
- захист від введення координат у неправильне поле;
- повторна активація `ElementClient`, контроль відкриття поля координат і fail-safe;
- перевірка підтримуваної збірки клієнта перед читанням титулів.

### Вікторини

- **ВІКТОРИНА КХ** — українська база питань і відповідей;
- **ВІКТОРИНА ЧОН-ПОН** — українська база питань і відповідей;
- пошук і фільтри за рівнями;
- робота офлайн.

### MultiLauncher

- локальні профілі персонажів;
- запуск одного, вибраних або всіх клієнтів;
- статус персонажа та підтримувані характеристики;
- паролі зберігаються через Windows DPAPI.

### Macro Studio — Beta

- графічний конструктор клавіатури й миші;
- паузи, цикли, текст, умови та робота з кольором пікселя;
- окремі клавіші запуску й аварійної зупинки;
- локальні макроси в `macros/`.

### Інші модулі

- карта ресурсів;
- симулятор заточки;
- симулятор Скрині Тора;
- розморозка вікон `ElementClient`;
- світові та хроно-боси;
- календар івентів.

## Завантаження

1. Відкрийте [GitHub Releases](https://github.com/vitalikjukivskiy/titul_helper-2.0/releases).
2. Завантажте `CyberPW-Assistant-2.0-Beta-Portable.zip` з останнього релізу.
3. Повністю розпакуйте ZIP.
4. Запустіть `CyberPW Assistant 2 Beta.exe`.

Python, npm та сторонні бібліотеки для запуску не потрібні.

## Автоматичні оновлення

Assistant перевіряє нові `v2.*` релізи через GitHub Releases API. Перед встановленням користувач бачить версію та текст оновлення. ZIP перевіряється за SHA-256, після чого `CyberPW Updater.exe` оновлює програмні файли, зберігаючи локальні дані користувача.

## Розробка

Основна гілка — `main`. Нові зміни робляться в короткоживучих робочих гілках і потрапляють у `main` через Pull Request.

Перевірка збірки виконується одним workflow: `.github/workflows/validate.yml`.

Релізи виконує один універсальний workflow: `.github/workflows/release.yml`. Новий реліз створюється після зміни `VERSION`; номер версії стає Git-тегом `v<VERSION>`, а текст береться з `RELEASE_NOTES.md`.

Докладний процес: [RELEASING.md](RELEASING.md).

## Збірка

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-CSharp-2.0.ps1
```

## Історія змін

- [CHANGELOG.md](CHANGELOG.md) — історія основних змін;
- [RELEASE_NOTES.md](RELEASE_NOTES.md) — опис поточного релізу;
- [GitHub Releases](https://github.com/vitalikjukivskiy/titul_helper-2.0/releases) — теги, ZIP-файли та опубліковані версії.

## Посилання

- [Сайт CyberPW](https://cyberpw.fun/)
- [Форумна тема](https://forum.cyberpw.fun/index.php?threads/titulhelper-1-0.271/)
- [YouTube](https://www.youtube.com/@Vitalik_Juk)
- [Issues](https://github.com/vitalikjukivskiy/titul_helper-2.0/issues)

Створив [Кіт Михайло](https://github.com/vitalikjukivskiy) для гравців CyberPW. Автор не належить до адміністрації CyberPW.
