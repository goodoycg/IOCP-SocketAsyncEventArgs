unit MainForm;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ComCtrls,
  Logger, ImgList, StdCtrls, ToolWin;

type
  TFmMain = class(TForm)
    ilToolBar: TImageList;
    tlb1: TToolBar;
    btnConfig: TToolButton;
    btn2: TToolButton;
    btnStart: TToolButton;
    btnStop: TToolButton;
    btn1: TToolButton;
    btnClearLog: TToolButton;
    btn3: TToolButton;
    btnAbout: TToolButton;
    redtLog: TRichEdit;
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure btnClearLogClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnConfigClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    procedure WMLOG(var AMsg: TMessage); message WM_LOG;
  public
    { Public declarations }
  end;

var
  FmMain: TFmMain;

implementation

uses DispatchCenter, ConfigForm, OptionSet;

{$R *.dfm}

procedure TFmMain.btnStartClick(Sender: TObject);
begin
  if DMDispatchCenter.Active then Exit;
  if DMDispatchCenter.Start then
  begin
    btnStart.Enabled := False;
    btnStop.Enabled := True;
  end
  else
  begin
    btnStart.Enabled := True;
    btnStop.Enabled := False;
  end;
end;

procedure TFmMain.btnStopClick(Sender: TObject);
begin
  if not DMDispatchCenter.Active then Exit;
  if DMDispatchCenter.Stop then
  begin
    btnStart.Enabled := True;
    btnStop.Enabled := False;
  end
  else
  begin
    btnStart.Enabled := False;
    btnStop.Enabled := True;
  end;
end;

procedure TFmMain.btnClearLogClick(Sender: TObject);
begin
  redtLog.Lines.Clear;
end;

procedure TFmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if DMDispatchCenter.Active then
    btnStopClick(btnStop);
end;

procedure TFmMain.btnConfigClick(Sender: TObject);
begin
  if not Assigned(FmConfig) then
    FmConfig := TFmConfig.Create(Application);
  FmConfig.SetCanEdit(not DMDispatchCenter.Active);
  FmConfig.ShowModal;
end;

procedure TFmMain.FormCreate(Sender: TObject);
var
  LogDesktopHandler: TLogDesktopHandler;
begin
  LogDesktopHandler := TLogDesktopHandler.Create(GLogger, Handle);
  GLogger.LogHandlerMgr.Add(LogDesktopHandler);

  LogDesktopHandler := TLogDesktopHandler.Create(GDebugLogger, Handle);
  GDebugLogger.LogHandlerMgr.Add(LogDesktopHandler);
end;

procedure TFmMain.WMLOG(var AMsg: TMessage);
var
  LogType: TLogType; 
  sLog: string;
  Color: TColor;

  function GetColor: TColor;
  begin
    if (LogType >= Low(TLogType)) and (LogType <= High(TLogType)) then
      Result := CDefaultColor[LogType]
    else
      Result := clBlack;
  end;
begin
  if redtLog.Lines.Count > 5120 then
    redtLog.Lines.Clear;
  LogType := TLogType(AMsg.WParam);
  sLog := PChar(AMsg.LParam);
  Color := GetColor;
  redtLog.SelAttributes.Color := Color;
  redtLog.SelStart := -1;//定位到最后；
  SendMessage(redtLog.Handle, EM_REPLACESEL, 0, LongInt(PChar(Format('%s'#13#10, [sLog]))));
  SendMessage(redtLog.Handle, WM_VSCROLL, SB_BOTTOM, 0);//把滚动条定位到文本最底；
end;

end.
