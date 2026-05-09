# WidgetLib

Портативная библиотека виджетов на Free Pascal с поддержкой SDL2.

## Особенности

- **Портативная архитектура** - абстракция рендерера позволяет поддерживать разные графические бэкенды
- **Система скинов** - поддержка цветовых и текстурных скинов для стилизации виджетов
- **Загрузка из JSON** - UI описывается в JSON файлах
- **Событийная модель** - обработка событий (hover, click, command)

## Виджеты

- `TLabel` - текстовая метка с выравниванием
- `TButton` - кнопка с поддержкой скинов и команд
- `TImage` - изображение с поддержкой растяжения
- `TBaseWidget` - базовый контейнер (Panel)

## Скины

Встроенные скины в стиле Doom:
- `doom_brown` - коричневый металлик
- `doom_gray` - серый сталь
- `doom_red` - адский красный
- `doom_green` - техно-зелёный
- `doom_blue` - техно-синий

## Требования

- Free Pascal Compiler 3.2+
- SDL2
- SDL2_image
- SDL2_ttf

### macOS
```bash
brew install sdl2 sdl2_image sdl2_ttf fpc
```

### Linux (Ubuntu/Debian)
```bash
sudo apt install fpc libsdl2-dev libsdl2-image-dev libsdl2-ttf-dev
```

## Сборка демо

```bash
cd demo
fpc -Fu../src/core -Fu../src/widgets -Fu../src/services -Fu../src/adapters/sdl2 -Fl/usr/local/lib -oDemo.SDL2 Demo.SDL2.lpr
```

### Запуск демо

```bash
./Demo.SDL2
```

## Добавление в свой проект

1. Скопируйте папку `src/` в ваш проект

2. Добавьте пути к модулям в опции компилятора:
```bash
-Fusrc/core -Fusrc/widgets -Fusrc/services -Fusrc/adapters/sdl2
```

3. В uses вашего проекта добавьте:
```pascal
uses
  Core.Contracts,      // Интерфейсы
  WidgetSystem,        // Система виджетов
  BasicWidgets,        // Label, Button, Image
  SkinSystem,          // Скины
  ResourceManager,     // Ресурсы
  SDL2Renderer,        // SDL2 рендерер
  WidgetAPI.SDL2;      // API для SDL2
```

4. Создайте рендерер и API:
```pascal
var
  renderer: TSDL2Renderer;
  res: TResourceManager;
  api: TSDL2WidgetAPI;
begin
  renderer := TSDL2Renderer.CreateWithWindow('My App', 800, 600);
  res := TResourceManager.Create(
    TSDL2ImageLoader.Create(renderer.GetRenderer),
    TSDL2FontLoader.Create
  );
  api := TSDL2WidgetAPI.Create(renderer, res, GlobalSkinManager, False);
  
  api.LoadUI('myui.json');  // Загрузка UI из JSON
  
  // Главный цикл
  while running do
  begin
    api.ProcessInput;
    api.Update(dt);
    api.Render;
  end;
end;
```

## Пример UI (demo.json)

```json
{
  "type": "Panel",
  "id": "root",
  "bounds": { "x": 0, "y": 0, "w": 800, "h": 600 },
  "children": [
    {
      "type": "Button",
      "id": "btnQuit",
      "bounds": { "x": 340, "y": 300, "w": 120, "h": 50 },
      "skin": "doom_red",
      "caption": "QUIT",
      "command": "app.quit",
      "font": "/System/Library/Fonts/Helvetica.ttc",
      "fontSize": 20
    }
  ]
}
```

## Лицензия

MIT License (см. LICENSE файл)
