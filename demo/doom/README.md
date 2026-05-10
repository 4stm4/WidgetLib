# DOOM WidgetLib Demo

Полноценный Doom-стайл HUD и простая игровая сцена, построенные на библиотеке WidgetLib.

## Особенности

- **Doom-стайл HUD** - лицо Doomguy, счётчики патронов, ARM-панель
- **Игровая сцена** - перспективный коридор, враги, частицы крови
- **Система скинов** - коричнево-металлическая палитра Doom
- **Событийная модель** - обработка столкновений, урон, смерть

## Управление

- **SPACE / LCtrl** - стрельба
- **1-7** - переключение оружия
- **ESC** - пауза
- **Закрыть окно** - выход

## Враги

| Тип | HP | Скорость | Очки | Описание |
|-----|----|----------| -----|----------|
| Imp | 2 | Быстрый | 100 | Коричневый, рога |
| Demon | 4 | Средний | 250 | Тёмно-красный, зубы |
| Cacodemon | 6 | Медленный | 500 | Летает выше, один глаз |
| Baron | 12 | Очень медленный | 1000 | Босс, длинные рога |

## Сборка

```bash
cd demo/doom
fpc -Fu../../src/core -Fu../../src/widgets -Fu../../src/services -Fu../../src/adapters/sdl2 \
    -Fl/usr/local/lib -oDemo.Doom Demo.Doom.lpr
```

### macOS
```bash
brew install sdl2 sdl2_image sdl2_ttf fpc
```

### Linux (Ubuntu/Debian)
```bash
sudo apt install fpc libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev
```

## Запуск

```bash
./Demo.Doom
```

## Структура проекта

```
demo/doom/
├── Demo.Doom.lpr          # Точка входа
├── DoomGame.pas           # Игровой контроллер
├── DoomHUD.pas            # HUD-виджеты (лицо, счётчики)
├── DoomScene.pas          # Игровая сцена (враги, пули, частицы)
├── DoomEnemy.pas          # Логика врагов
├── DoomSkins.pas          # Doom-скины
├── assets/
│   ├── fonts/
│   │   └── DoomFont.ttf   # Шрифт (любой моноширинный)
│   ├── skins/
│   │   └── hud_skin.json  # Скины HUD
│   └── ui/
│       └── hud.json       # JSON-описание HUD
└── README.md
```

## Архитектура

### TDoomHUD (DoomHUD.pas)
- `TDoomFaceWidget` - лицо Doomguy, меняется от здоровья
- `TAmmoCounterWidget` - счётчики BULL/SHEL/RCKT/CELL
- `TDoomHUD` - контейнер всего HUD

### TDoomScene (DoomScene.pas)
- Управляет врагами, пулями, частицами
- Рендерит перспективный коридор
- Обрабатывает столкновения

### TDoomGame (DoomGame.pas)
- Главный контроллер
- Обрабатывает ввод
- Координирует Scene и HUD

## Требования

- Free Pascal Compiler 3.2+
- SDL2 + SDL2_image + SDL2_ttf
- Библиотека WidgetLib (в ../../src/)

## Примечания

- Шрифт: если нет `assets/fonts/DoomFont.ttf`, используется системный (Helvetica на macOS, FreeMono на Linux)
- Все виджеты наследуются от `TBaseWidget` (WidgetLib)
- Вся отрисовка через `IRenderer` (никакого SDL напрямую)
