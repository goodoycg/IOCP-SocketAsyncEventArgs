unit ThroughputForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ModalForm, StdCtrls, ComCtrls, ExtCtrls, ThroughputSocket, ActiveX,
  DateUtils, Math, Menus;

const
  WM_ConnectThreadTerminated = WM_USER + 9000;
  WM_CyclePacketThreadTerminated = WM_USER + 9001;
type
  TConnectThread = class;
  TCyclePacketThread = class;
  TFmThroughputForm = class(TFmModal)
    grpConnectionCount: TGroupBox;
    lblConnectionCount: TLabel;
    cbbConnectionCount: TComboBox;
    btnConnect: TButton;
    btnDisconnect: TButton;
    grpCyclePacket: TGroupBox;
    lvCyclePacket: TListView;
    pnlCyclePacket: TPanel;
    lblThreadCount: TLabel;
    cbbThreadCount: TComboBox;
    btnStart: TButton;
    btnStop: TButton;
    lblCount: TLabel;
    tmrConnectCounter: TTimer;
    tmrCyclePacketCounter: TTimer;
    cbbPacketSize: TComboBox;
    cbbCycleCount: TComboBox;
    procedure btnConnectClick(Sender: TObject);
    procedure tmrConnectCounterTimer(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnStartClick(Sender: TObject);
    procedure tmrCyclePacketCounterTimer(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
  private
    FConnectThreads: array of TConnectThread;
    FConnectThreadCount: Integer;
    FCyclePacketThreads: array of TCyclePacketThread;
    FCyclePacketThreadCount: Integer;
  protected
    procedure ConnectThreadTerminated(var Msg: TMessage); message WM_ConnectThreadTerminated;
    procedure CyclePacketThreadTerminated(var Msg: TMessage); message WM_CyclePacketThreadTerminated;
    function GetPacketSize: Integer;
    procedure ShowCyclePacketSpeed;
  public
    { Public declarations }
    class function ShowForm(const AHandle: THandle): Boolean;
  end;

  TConnectThread = class(TThread)
  private
    FThroughputSockets: array of TThroughputScoket;
    FSocketCount: Integer;
    FConnectedCount: Integer;
    FNotifyHandle: THandle;
  protected
    procedure Execute; override;
  public
    property SocketCount: Integer read FSocketCount write FSocketCount;
    property ConnectedCount: Integer read FConnectedCount;
    property NotifyHandle: THandle read FNotifyHandle write FNotifyHandle;
  end;

  TCyclePacketThread = class(TThread)
  private
    FThroughputSocket: TThroughputScoket;
    FCycleCount, FTotalCount: Integer;
    FNotifyHandle: THandle;
    FBufferSize: Integer;
    FCycleTimeMS: Cardinal;
    FCompleted: Boolean;
    FLocalIP, FRemoteIP: string;
  protected
    procedure Execute; override;
  public
    property CycleCount: Integer read FCycleCount;
    property TotalCount: Integer read FTotalCount write FTotalCount;
    property NotifyHandle: THandle read FNotifyHandle write FNotifyHandle;
    property ThroughputSocket: TThroughputScoket read FThroughputSocket;
    property BufferSize: Integer read FBufferSize write FBufferSize;
    property CycleTimeMS: Cardinal read FCycleTimeMS;
    property Completed: Boolean read FCompleted;
  end;

implementation

uses DataMgrCtr, Logger, BasisFunction;

{$R *.dfm}

{ TConnectThread }

procedure TConnectThread.Execute;
var
  i: Integer;
begin
  inherited;
  CoInitialize(nil);
  try
    try
      SetLength(FThroughputSockets, FSocketCount);
      FConnectedCount := 0;
      for i := Low(FThroughputSockets) to High(FThroughputSockets) do
      begin
        if Terminated then Break;
        try
          FThroughputSockets[i] := TThroughputScoket.Create;
          FThroughputSockets[i].Connect(GDataMgrCtr.Host, GDataMgrCtr.Port);
        except
          on E: Exception do
          begin
            WriteLogMsg(ltError, 'Connect Server Error, Message: ' + E.Message);
          end;
        end;
        FConnectedCount := FConnectedCount + 1;
      end;
    finally
      PostMessage(FNotifyHandle, WM_ConnectThreadTerminated, 0, 0);
    end;
  except
    on E: Exception do
    begin
      WriteLogMsg(ltError, 'Throughput Connect Thread Error, Message: ' + E.Message);
    end;
  end;
  CoUninitialize;
end;

{ TCyclePacketThread }

procedure TCyclePacketThread.Execute;
var
  BeginDT: TDateTime;
begin
  inherited;
  CoInitialize(nil);
  try
    FThroughputSocket := TThroughputScoket.Create;
    try
      FThroughputSocket.BufferSize := FBufferSize;
      FThroughputSocket.Connect(GDataMgrCtr.Host, GDataMgrCtr.Port);
      FLocalIP := FThroughputSocket.Client.Socket.Binding.IP + ':'
        + IntToStr(FThroughputSocket.Client.Socket.Binding.Port);
      FRemoteIP := FThroughputSocket.Client.Socket.Binding.PeerIP + ':'
        + IntToStr(FThroughputSocket.Client.Socket.Binding.PeerPort);
      FCompleted := False;
      BeginDT := Now;
      while not Terminated do
      begin
        if not FThroughputSocket.CyclePacket then
          raise Exception.Create(FThroughputSocket.LastError);
        FCycleCount := FThroughputSocket.Count;
        if FCycleCount >= FTotalCount then Break;
      end;
      FCycleTimeMS := Max(MilliSecondsBetween(Now, BeginDT), 0);
      FCompleted := True;
    finally
      FThroughputSocket.Free;
      FThroughputSocket := nil;
      PostMessage(FNotifyHandle, WM_CyclePacketThreadTerminated, 0, 0);
    end;
  except
    on E: Exception do
    begin
      WriteLogMsg(ltError, 'Throughput Cycle Packet Thread Error, Message: ' + E.Message);
    end;
  end;
  CoUninitialize;
end;

{ TFmThroughputForm }

class function TFmThroughputForm.ShowForm(const AHandle: THandle): Boolean;
var
  FmThroughputForm: TFmThroughputForm;
begin
  FmThroughputForm := TFmThroughputForm.Create(Application, AHandle);
  try
    if FmThroughputForm.ShowModal = mrOk then
      Result := True
    else
      Result := False;
  finally
    FmThroughputForm.Free;
  end;
end;

procedure TFmThroughputForm.FormCreate(Sender: TObject);
begin
  inherited;
  tmrConnectCounter.Enabled := False;
  tmrCyclePacketCounter.Enabled := False;
  btnConnect.Enabled := True;
  btnDisconnect.Enabled := False;
  btnStart.Enabled := True;
  btnStop.Enabled := False;
end;

procedure TFmThroughputForm.btnConnectClick(Sender: TObject);
var
  iTotalCount, iThreadCount, i, iSocketCount: Integer;
begin
  inherited;
  iTotalCount := StrToInt(cbbConnectionCount.Text);
  iThreadCount := StrToInt(cbbThreadCount.Text);
  SetLength(FConnectThreads, iThreadCount);
  iSocketCount := iTotalCount div iThreadCount;
  tmrConnectCounter.Enabled := False;
  for i := 0 to iThreadCount - 1 do
  begin
    FConnectThreads[i] := TConnectThread.Create(True);
    FConnectThreads[i].SocketCount := iSocketCount;
    FConnectThreads[i].NotifyHandle := Handle;
    FConnectThreads[i].FreeOnTerminate := False;
    FConnectThreads[i].Resume;
  end;
  FConnectThreadCount := iThreadCount;
  btnConnect.Enabled := False;
  btnDisconnect.Enabled := True;
  tmrConnectCounter.Enabled := True;
end;

procedure TFmThroughputForm.tmrConnectCounterTimer(Sender: TObject);
var
  i, iCount: Integer;
begin
  inherited;
  iCount := 0;
  for i := Low(FConnectThreads) to High(FConnectThreads) do
  begin
    iCount := iCount + FConnectThreads[i].ConnectedCount;
  end;
  lblCount.Caption := IntToStr(iCount);
end;

procedure TFmThroughputForm.ConnectThreadTerminated(var Msg: TMessage);
var
  i: Integer;
begin
  FConnectThreadCount := FConnectThreadCount - 1;
  if FConnectThreadCount <= 0 then
  begin
    tmrConnectCounter.Enabled := False;
    tmrConnectCounterTimer(nil);
    for i := Low(FConnectThreads) to High(FConnectThreads) do
    begin
      FConnectThreads[i].Terminate;
      FConnectThreads[i].WaitFor;
      FConnectThreads[i].Free;
      FConnectThreads[i] := nil;
    end;
    SetLength(FConnectThreads, 0);
    btnConnect.Enabled := True;
    btnDisconnect.Enabled := False;
  end;
end;

procedure TFmThroughputForm.btnDisconnectClick(Sender: TObject);
var
  i: Integer;
begin
  inherited;
  for i := Low(FConnectThreads) to High(FConnectThreads) do
  begin
    FConnectThreads[i].Terminate;
  end;
end;

procedure TFmThroughputForm.FormCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  inherited;
  if btnDisconnect.Enabled then
  begin
    btnDisconnectClick(Sender);
    Application.ProcessMessages;
  end;
  if btnStop.Enabled then
  begin
    btnStopClick(Sender);
    Application.ProcessMessages;
  end;
  Application.ProcessMessages;
end;

procedure TFmThroughputForm.btnStartClick(Sender: TObject);
var
  iThreadCount, i, iTotalCount: Integer;
begin
  inherited;
  iTotalCount := StrToInt(cbbCycleCount.Text);
  tmrCyclePacketCounter.Enabled := False;
  lvCyclePacket.Items.Clear;
  iThreadCount := StrToInt(cbbThreadCount.Text);
  SetLength(FCyclePacketThreads, iThreadCount);
  for i := 0 to iThreadCount - 1 do
  begin
    FCyclePacketThreads[i] := TCyclePacketThread.Create(True);
    FCyclePacketThreads[i].TotalCount := iTotalCount;
    FCyclePacketThreads[i].BufferSize := GetPacketSize;
    FCyclePacketThreads[i].NotifyHandle := Handle;
    FCyclePacketThreads[i].FreeOnTerminate := False;
    FCyclePacketThreads[i].Resume;
  end;
  FCyclePacketThreadCount := iThreadCount;
  btnStart.Enabled := False;
  btnStop.Enabled := True;
  tmrCyclePacketCounter.Enabled := True;
end;

procedure TFmThroughputForm.tmrCyclePacketCounterTimer(Sender: TObject);
var
  i: Integer;
  ListItem: TListItem;
begin
  inherited;
  if lvCyclePacket.Items.Count = 0 then
  begin
    for i := Low(FCyclePacketThreads) to High(FCyclePacketThreads) do
    begin
      ListItem := lvCyclePacket.Items.Add;
      ListItem.Caption := IntToStr(i + 1);
      ListItem.SubItems.Add(IntToStr(FCyclePacketThreads[i].ThreadID));
      ListItem.SubItems.Add(FCyclePacketThreads[i].FLocalIP);
      ListItem.SubItems.Add(FCyclePacketThreads[i].FRemoteIP);
      ListItem.SubItems.Add('');
      ListItem.SubItems.Add('');
      ListItem.Data := FCyclePacketThreads[i];
    end;
  end
  else
  begin
    for i := 0 to lvCyclePacket.Items.Count - 1 do
    begin
      ListItem := lvCyclePacket.Items[i];
      ListItem.SubItems[3] := IntToStr(TCyclePacketThread(ListItem.Data).CycleCount);
      ListItem.SubItems[4] := BoolToStr(TCyclePacketThread(ListItem.Data).Completed, True);
    end;
  end;
end;

procedure TFmThroughputForm.CyclePacketThreadTerminated(var Msg: TMessage);
var
  i: Integer;
begin
  FCyclePacketThreadCount := FCyclePacketThreadCount - 1;
  if FCyclePacketThreadCount <= 0 then
  begin
    tmrCyclePacketCounter.Enabled := False;
    tmrCyclePacketCounterTimer(nil);
    ShowCyclePacketSpeed;
    for i := Low(FCyclePacketThreads) to High(FCyclePacketThreads) do
    begin
      FCyclePacketThreads[i].Terminate;
      FCyclePacketThreads[i].WaitFor;
      FCyclePacketThreads[i].Free;
      FCyclePacketThreads[i] := nil;
    end;
    SetLength(FCyclePacketThreads, 0);
    btnStart.Enabled := True;
    btnStop.Enabled := False;
  end;
end;

procedure TFmThroughputForm.btnStopClick(Sender: TObject);
var
  i: Integer;
begin
  inherited;
  for i := Low(FCyclePacketThreads) to High(FCyclePacketThreads) do
  begin
    FCyclePacketThreads[i].Terminate;
  end;
end;

function TFmThroughputForm.GetPacketSize: Integer;
begin
  case cbbPacketSize.ItemIndex of
    0: Result := 16;
    1: Result := 32;
    2: Result := 64;
    3: Result := 128;
    4: Result := 256;
    5: Result := 512;
    6: Result := 1 * 1024;
    7: Result := 2 * 1024;
    8: Result := 4 * 1024;
    9: Result := 8 * 1024;
    10: Result := 16 * 1024;
    11: Result := 32 * 1024;
    12: Result := 64 * 1024;
    13: Result := 128 * 1024;
    14: Result := 256 * 1024;
    15: Result := 512 * 1024;
    16: Result := 1 * 1024 * 1024;
    17: Result := 2 * 1024 * 1024;
    18: Result := 4 * 1024 * 1024;
    19: Result := 8 * 1024 * 1024;
  else
    Result := 64 * 1024; 
  end;
end;

procedure TFmThroughputForm.ShowCyclePacketSpeed;
var
  i: Integer;
  CycleTimeMS: Cardinal;
  CycleSize, tmpSize: Int64;
  CyclePacketThread: TCyclePacketThread;
begin
  CycleTimeMS := 0;
  CycleSize := 0;
  for i := 0 to lvCyclePacket.Items.Count - 1 do
  begin
    CyclePacketThread := lvCyclePacket.Items[i].Data;
    CycleTimeMS := CyclePacketThread.CycleTimeMS + CycleTimeMS;
    tmpSize := CyclePacketThread.BufferSize;
    tmpSize := tmpSize * CyclePacketThread.CycleCount;
    CycleSize := CycleSize + tmpSize;
  end;
  if CycleTimeMS > 0 then
    InfoBox(IntToStr(CycleSize) + '  ' + IntToStr(CycleTimeMS) + '  ' +  GetSpeedDisplay(CycleSize / CycleTimeMS * 1000));
end;

end.
