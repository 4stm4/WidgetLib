unit SDL2InputBridge;

{$mode objfpc}{$H+}

interface

uses
  SDL2,
  Core.Contracts,
  EventSystem;

type
  TSDL2InputBridge = class
  private
    FLastMouseDown: Boolean;
    FLastDownPos: TPoint;
    FDragActive: Boolean;
    FDragSource: IWidget;
    FDragStartPos: TPoint;
  const
    DRAG_THRESHOLD = 4;
  public
    constructor Create;
    procedure PollAndPost(es: TEventSystem);
  end;

implementation

constructor TSDL2InputBridge.Create;
begin
  inherited Create;
  FLastMouseDown := False;
  FDragActive := False;
  FDragSource := nil;
end;

procedure TSDL2InputBridge.PollAndPost(es: TEventSystem);
var
  event: TSDL_Event;
  wev: TWidgetEvent;
  dx, dy: Integer;
  button: Byte;
begin
  while SDL_PollEvent(@event) <> 0 do
  begin
    FillChar(wev, SizeOf(wev), 0);

    case event.type_ of
      SDL_MOUSEMOTION:
        begin
          wev.kind := evMouseMove;
          wev.x := event.motion.x;
          wev.y := event.motion.y;
          wev.button := 0;
          es.PostEvent(wev);

          // Drag detection
          if FLastMouseDown then
          begin
            dx := event.motion.x - FLastDownPos.x;
            dy := event.motion.y - FLastDownPos.y;

            if not FDragActive and ((Abs(dx) > DRAG_THRESHOLD) or (Abs(dy) > DRAG_THRESHOLD)) then
            begin
              FDragActive := True;
              FDragStartPos.x := event.motion.x;
              FDragStartPos.y := event.motion.y;
              wev.kind := evDragStart;
              wev.dragSource := FDragSource;
              es.PostEvent(wev);
            end
            else if FDragActive then
            begin
              wev.kind := evDragMove;
              wev.dragSource := FDragSource;
              es.PostEvent(wev);
            end;
          end;
        end;

      SDL_MOUSEBUTTONDOWN:
        begin
          // SDL2 button numbering: 1=left, 2=middle, 3=right, 4=back, 5=forward
          button := event.button.button;

          wev.kind := evMouseDown;
          wev.x := event.button.x;
          wev.y := event.button.y;
          wev.button := button;
          es.PostEvent(wev);

          FLastMouseDown := True;
          FLastDownPos.x := event.button.x;
          FLastDownPos.y := event.button.y;
          FDragSource := nil; // Can be determined via hit-test
        end;

      SDL_MOUSEBUTTONUP:
        begin
          button := event.button.button;

          wev.kind := evMouseUp;
          wev.x := event.button.x;
          wev.y := event.button.y;
          wev.button := button;
          es.PostEvent(wev);

          if FDragActive then
          begin
            wev.kind := evDragEnd;
            wev.dragSource := FDragSource;
            es.PostEvent(wev);
            FDragActive := False;
          end;

          FLastMouseDown := False;
        end;

      SDL_MOUSEWHEEL:
        begin
          wev.kind := evMouseWheel;
          wev.x := 0;
          wev.y := 0;
          // SDL2: wheel.y is the amount scrolled (positive = away from user)
          wev.wheelDelta := event.wheel.y;
          wev.button := 0;
          es.PostEvent(wev);
        end;

      SDL_KEYDOWN:
        begin
          wev.kind := evKeyDown;
          wev.key := event.key.keysym.sym;
          wev.button := 0;
          es.PostEvent(wev);
        end;

      SDL_KEYUP:
        begin
          wev.kind := evKeyUp;
          wev.key := event.key.keysym.sym;
          wev.button := 0;
          es.PostEvent(wev);
        end;

      SDL_QUITEV:
        begin
          // Post a command event for app quit
          wev.kind := evCommand;
          wev.commandName := 'app.quit';
          wev.handled := False;
          es.PostEvent(wev);
        end;

      SDL_WINDOWEVENT:
        begin
          // Handle window events (resize, expose, etc.)
          case event.window.event of
            SDL_WINDOWEVENT_RESIZED,
            SDL_WINDOWEVENT_SIZE_CHANGED:
              begin
                // Could post a resize event if needed
                // For now, just ignore
              end;
          end;
        end;
    end;
  end;
end;

end.
