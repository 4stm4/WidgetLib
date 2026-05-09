# SDL2 Adapters

Этот проект поддерживает две версии SDL через паттерн Адаптер:

## Важно: FPU Exceptions

SDL2 может вызывать FPU исключения внутри своих функций. **Всегда маскируйте FPU исключения** в начале программы:

```pascal
uses SysUtils, Math;

begin
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, 
                    exOverflow, exUnderflow, exPrecision]);
  // ... SDL2 initialization
end.
```

## Структура адаптеров

| Компонент | SDL 1.2 | SDL 2.0 |
|-----------|---------|---------|
| Renderer | `SDLRenderer.pas` | `SDL2Renderer.pas` |
| Input Bridge | `SDLInputBridge.pas` | `SDL2InputBridge.pas` |
| Image Loader | `BMPLoader.pas` | `SDL2ImageLoader.pas` |
| Font Loader | `TTFLoader.pas` | `SDL2FontLoader.pas` |
| Widget API | `WidgetAPI.pas` | `WidgetAPI.SDL2.pas` |

## SDL2Renderer

`TSDL2Renderer` реализует интерфейс `IRenderer` для SDL 2.0:

```pascal
// Создание с автоматическим созданием окна
renderer := TSDL2Renderer.CreateWithWindow('Title', 800, 600);

// Или с существующими окном и рендерером
renderer := TSDL2Renderer.Create(window, sdl_renderer);
```

### Отличия от SDL 1.2:
- Использует `SDL_Renderer` вместо `SDL_Surface`
- Текстуры вместо поверхностей для изображений
- `SDL_RenderPresent` вместо `SDL_Flip`
- Аппаратное ускорение по умолчанию

## SDL2InputBridge

`TSDL2InputBridge` конвертирует SDL2 события:

- `SDL_MOUSEMOTION` → `evMouseMove`
- `SDL_MOUSEBUTTONDOWN/UP` → `evMouseDown/evMouseUp`
- `SDL_MOUSEWHEEL` → `evMouseWheel` (с реальным `wheelDelta`)
- `SDL_KEYDOWN/UP` → `evKeyDown/evKeyUp`
- `SDL_QUITEV` → `evCommand('app.quit')`

## SDL2ImageLoader

`TSDL2ImageLoader` загружает изображения в текстуры SDL2:

```pascal
loader := TSDL2ImageLoader.Create(renderer.GetRenderer);
image := loader.Load('image.bmp');
```

## SDL2FontLoader

`TSDL2FontLoader` загружает шрифты через SDL2_ttf:

```pascal
loader := TSDL2FontLoader.Create;
font := loader.Load('font.ttf', 16);
```

## WidgetAPI.SDL2

`TSDL2WidgetAPI` — высокоуровневый API для SDL2:

```pascal
api := TSDL2WidgetAPI.Create(renderer, resourceManager, skinManager);
api.LoadUI('demo.json');

// Главный цикл
while running do
begin
  api.ProcessInput;
  api.Update(dt);
  api.Render;
  SDL_Delay(1);
end;
```

## Фабрика (WidgetAPI.Factory)

Для упрощения переключения между версиями SDL:

```pascal
uses WidgetAPI.Factory;

var
  api: TObject;
  renderer: IRenderer;
  res: TResourceManager;
  skins: TSkinManager;
begin
  // Выбор версии SDL
  api := TWidgetAPIFactory.CreateAPI(
    svSDL2,           // или svSDL1 для SDL 1.2
    'My App',
    800, 600,
    renderer,
    res,
    skins
  );
  
  // Для SDL2:
  // TSDL2WidgetAPI(api).LoadUI('demo.json');
  
  // Для SDL1:
  // TWidgetAPI(api).LoadUI('demo.json');
end;
```

## Демо

- `Demo.lpr` — демо для SDL 1.2
- `Demo.SDL2.lpr` — демо для SDL 2.0

## Зависимости

### SDL 1.2:
- `SDL` (sdl.pas)
- `SDL_ttf` (sdl_ttf.pas)

### SDL 2.0:
- `SDL2` (sdl2.pas)
- `SDL2_ttf` (sdl2_ttf.pas)

## Преимущества SDL2

1. **Аппаратное ускорение** — использует GPU для рендеринга
2. **VSync** — вертикальная синхронизация для плавной отрисовки
3. **Лучшее управление окнами** — изменение размера, полноэкранный режим
4. **Современные форматы изображений** — PNG, JPG через SDL2_image
5. **Мультиоконность** — поддержка нескольких окон
6. **События мыши** — лучшая поддержка колеса мыши
