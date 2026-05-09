unit EventSystem;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Core.Contracts;

type
  TEventCallback = procedure(e: TWidgetEvent) of object;

  TEventEntry = record
    kind: TEventKind;
    callback: TEventCallback;
  end;

  PEventEntry = ^TEventEntry;
  TTimerEntry = record
    id: Integer;
    interval: Integer;
    lastTick: LongWord;
    callback: TEventCallback;
  end;

  PTimerEntry = ^TTimerEntry;

  TEventSystem = class
  private
    FQueue: array of TWidgetEvent;
    FHandlers: TFPList;
    FTimers: TFPList;

    function CallbacksEqual(a, b: TEventCallback): Boolean;
    procedure RemoveFirstQueuedEvent;
  public
    constructor Create;
    destructor Destroy; override;

    procedure PostEvent(e: TWidgetEvent);
    procedure RegisterHandler(kind: TEventKind; cb: TEventCallback);
    procedure UnregisterHandler(kind: TEventKind; cb: TEventCallback);
    procedure Dispatch; reintroduce;
    function PendingCount: Integer;

    procedure RegisterTimer(id: Integer; intervalMs: Integer; cb: TEventCallback);
    procedure UnregisterTimer(id: Integer);
    procedure Tick(nowMs: LongWord);
  end;

implementation

constructor TEventSystem.Create;
begin
  inherited Create;
  FQueue := nil;
  FHandlers := TFPList.Create;
  FTimers := TFPList.Create;
end;

destructor TEventSystem.Destroy;
var
  i: Integer;
begin
  for i := 0 to FHandlers.Count - 1 do
    Dispose(PEventEntry(FHandlers[i]));
  for i := 0 to FTimers.Count - 1 do
    Dispose(PTimerEntry(FTimers[i]));
  FHandlers.Free;
  FTimers.Free;
  SetLength(FQueue, 0);
  inherited Destroy;
end;
procedure TEventSystem.RegisterTimer(id: Integer; intervalMs: Integer; cb: TEventCallback);
var
  entry: PTimerEntry;
  i: Integer;
begin
  // remove if exists
  for i := FTimers.Count - 1 downto 0 do
    if PTimerEntry(FTimers[i])^.id = id then
    begin
      Dispose(PTimerEntry(FTimers[i]));
      FTimers.Delete(i);
    end;
  New(entry);
  entry^.id := id;
  entry^.interval := intervalMs;
  entry^.lastTick := 0;
  entry^.callback := cb;
  FTimers.Add(entry);
end;

procedure TEventSystem.UnregisterTimer(id: Integer);
var
  i: Integer;
begin
  for i := FTimers.Count - 1 downto 0 do
    if PTimerEntry(FTimers[i])^.id = id then
    begin
      Dispose(PTimerEntry(FTimers[i]));
      FTimers.Delete(i);
    end;
end;

procedure TEventSystem.Tick(nowMs: LongWord);
var
  i: Integer;
  entry: PTimerEntry;
  ev: TWidgetEvent;
begin
  for i := 0 to FTimers.Count - 1 do
  begin
    entry := PTimerEntry(FTimers[i]);
    if (entry^.lastTick = 0) or (nowMs - entry^.lastTick >= LongWord(entry^.interval)) then
    begin
      entry^.lastTick := nowMs;
      ev.kind := evTimer;
      ev.x := 0; ev.y := 0; ev.button := 0; ev.key := 0; ev.wheelDelta := 0;
      ev.dragSource := nil; ev.commandName := ''; ev.commandData := nil; ev.handled := False;
      entry^.callback(ev);
      PostEvent(ev);
    end;
  end;
end;

function TEventSystem.CallbacksEqual(a, b: TEventCallback): Boolean;
begin
  Result :=
    (TMethod(a).Code = TMethod(b).Code) and
    (TMethod(a).Data = TMethod(b).Data);
end;

procedure TEventSystem.RemoveFirstQueuedEvent;
var
  i: Integer;
begin
  for i := 1 to High(FQueue) do
    FQueue[i - 1] := FQueue[i];

  SetLength(FQueue, Length(FQueue) - 1);
end;

procedure TEventSystem.PostEvent(e: TWidgetEvent);
var
  index: Integer;
begin
  index := Length(FQueue);
  SetLength(FQueue, index + 1);
  FQueue[index] := e;
end;

procedure TEventSystem.RegisterHandler(kind: TEventKind; cb: TEventCallback);
var
  entry: PEventEntry;
begin
  if not Assigned(cb) then
    Exit;

  New(entry);
  entry^.kind := kind;
  entry^.callback := cb;
  FHandlers.Add(entry);
end;

procedure TEventSystem.UnregisterHandler(kind: TEventKind; cb: TEventCallback);
var
  i: Integer;
  entry: PEventEntry;
begin
  for i := FHandlers.Count - 1 downto 0 do
  begin
    entry := PEventEntry(FHandlers[i]);
    if (entry^.kind = kind) and CallbacksEqual(entry^.callback, cb) then
    begin
      FHandlers.Delete(i);
      Dispose(entry);
    end;
  end;
end;

procedure TEventSystem.Dispatch;
var
  e: TWidgetEvent;
  i: Integer;
  entry: PEventEntry;
begin
  while Length(FQueue) > 0 do
  begin
    e := FQueue[0];
    RemoveFirstQueuedEvent;

    for i := 0 to FHandlers.Count - 1 do
    begin
      entry := PEventEntry(FHandlers[i]);
      if entry^.kind = e.kind then
        entry^.callback(e);
    end;
  end;
end;

function TEventSystem.PendingCount: Integer;
begin
  Result := Length(FQueue);
end;

end.
