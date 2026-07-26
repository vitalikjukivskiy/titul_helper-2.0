<p align="center">
  <img src="github-header-kitmikhailo.png" width="100%" alt="CyberPW Assistant — інструментарій гравця">
</p>

<h1 align="center">CyberPW Assistant</h1>

<p align="center">
  Неофіційний відкритий інструментарій для гравців CyberPW<br>
  <strong>0.90 Design Preview · Windows 7/10/11 · Portable · PowerShell 5.1</strong>
</p>

<p align="center">
  <a href="https://github.com/vitalikjukivskiy/titul_helper/releases"><img src="https://img.shields.io/github/downloads/vitalikjukivskiy/titul_helper/total?style=for-the-badge&logo=github&label=Downloads&color=0f9d7a" alt="Завантаження релізів"></a>
  <a href="https://github.com/vitalikjukivskiy/titul_helper/releases/latest"><img src="https://img.shields.io/github/v/release/vitalikjukivskiy/titul_helper?include_prereleases&style=for-the-badge&label=Release&color=d4af37" alt="Остання версія"></a>
</p>

<p align="center">
  <a href="https://cyberpw.fun/">Сайт CyberPW</a> ·
  <a href="https://forum.cyberpw.fun/">Форум</a> ·
  <a href="https://cabinet.cyberpw.fun/">Кабінет</a> ·
  <a href="https://cabinet.cyberpw.fun/register.php?ref=4550">Реєстрація з бонусом</a> ·
  <a href="https://www.youtube.com/@Vitalik_Juk">YouTube</a> ·
  <a href="https://send.monobank.ua/jar/93N5FBB3zX">Підтримати проєкт</a>
</p>

> [!IMPORTANT]
> Це неофіційний фанатський проєкт. Перед використанням макросів перевірте правила сервера. Проєкт не містить обходу античита, прихованого драйвера або читання пам’яті гри.

## Що входить

### TitulHelper

- база 259 точок запуску титулів у 37 ланцюжках;
- пошук, прогрес, калібрування та автоматичне встановлення міток;
- OCR-сканування отриманих титулів із прокручуванням списку;
- підтримка кількох моніторів.

### MultiLauncher

- профілі персонажів, запуск одного, вибраних або всіх клієнтів;
- 10 класів Perfect World 1.4.6 з окремими ілюстраціями;
- облікові дані шифруються Windows для поточного користувача;
- BAT-ярлики не містять логінів і паролів.

### Macro Studio — Alpha

- графічний конструктор без необхідності писати PowerShell;
- екранна клавіатура, клавіші миші, затискання, паузи, текст і цикли;
- очікування кольору пікселя з координатами, допуском і тайм-аутом;
- virtual-key рушій для цифр, F-клавіш, Shift/Ctrl/Alt і стрілок;
- аварійна зупинка `F12` із відпусканням затиснутих клавіш;
- макроси зберігаються локально в `macros/*.json` і не потрапляють до Git.

### Карта територіальних війн

- 51 інтерактивна територія з точними полігонами;
- назва, рівень, нагорода, власник, атакуючий, захисник і час бою;
- локальний стан у `territories.json` не потрапляє до Git;
- актуальні власники та бої поки не синхронізуються з сервером автоматично.

### Інші модулі

- симулятор Скрині Тора зі статистикою випадінь;
- розморозка вибраних вікон `ElementClient`;
- 16 світових і 8 хроно-босів із координатами та розкладом;
- календар івентів у головному лаунчері.

## Дизайн 0.90

- спільна дизайн-система для всіх модулів;
- округлені кнопки, картки, панелі, списки й таблиці;
- DPI-масштабування та подвійна буферизація;
- системні округлені кути на Windows 11;
- безпечний fallback для Windows 7 і Windows 10;
- світла й темна теми зі збереженням вибору.

## Швидкий запуск

1. Відкрийте [Releases](https://github.com/vitalikjukivskiy/titul_helper/releases).
2. Завантажте `Cyber.pw-Asistant-Portable.zip`.
3. Повністю розпакуйте архів у звичайну папку.
4. Запустіть `Запустити.bat`.
5. Для OCR за потреби запустіть `Встановити OCR.bat` від адміністратора.

Python, npm та сторонні бібліотеки не потрібні.

## Сумісність

| Система | Статус | Примітки |
|---|---:|---|
| Windows 11 | ✅ | Повна підтримка, системні округлені кути |
| Windows 10 | ✅ | Повна підтримка |
| Windows 7 SP1 | ✅ | Потрібні .NET Framework 4.8 та Windows Management Framework 5.1; системний OCR недоступний |

## Безпека й приватність

- код не читає пам’ять `ElementClient` і не змінює файли гри;
- паролі MultiLauncher не зберігаються відкритим текстом;
- `state.json`, `characters.json`, `territories.json`, `launcher-theme.json`, `macros/` і OCR-звіти виключені з Git;
- Macro Studio активує лише вказаний процес і має аварійну клавішу `F12`;
- перед використанням автоматизації користувач самостійно перевіряє правила сервера.

## Збірка з вихідного коду

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Portable.ps1
```

Результат:

- `dist/Cyber.pw-Asistant/`;
- `dist/Cyber.pw-Asistant-Portable.zip`;
- `dist/SHA256.txt`.

## Посилання

- [Сайт CyberPW](https://cyberpw.fun/)
- [Форум CyberPW](https://forum.cyberpw.fun/)
- [Особистий кабінет](https://cabinet.cyberpw.fun/)
- [Реєстрація з бонусом](https://cabinet.cyberpw.fun/register.php?ref=4550)
- [YouTube автора](https://www.youtube.com/@Vitalik_Juk)
- [Релізи Assistant](https://github.com/vitalikjukivskiy/titul_helper/releases)
- [GitHub автора](https://github.com/vitalikjukivskiy)
- [Підтримати проєкт](https://send.monobank.ua/jar/93N5FBB3zX)

## Автор

Створив [**Кіт Михайло**](https://github.com/vitalikjukivskiy) для гравців CyberPW, клан **DarkSide**.

Автор не належить до адміністрації CyberPW. Назви, іконки та графічні матеріали гри належать їхнім правовласникам.