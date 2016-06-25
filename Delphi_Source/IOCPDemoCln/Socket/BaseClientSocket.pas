unit BaseClientSocket;

interface

uses
  IdTCPClient, Windows, SysUtils, Classes, DefineUnit, Types, Forms, Controls,
  SyncObjs, ZLibEx;

const
  CI_ReadTimeOut = 60 * 1000; //默认超时
type  
  {* 基础协议对象 *}
  TBaseClientSocket = class(TObject)
  protected
    {* 连接对象 *}
    FClient: TIdTCPClient;
    {* 服务器和端口 *}
    FHost: string;
    FPort: Integer;
    {* 错误信息 *}
    FLastError: string;
    {* 超时毫秒 *}
    FTimeOutMS: Cardinal;
    {* 错误码 *}
    FLastErrorCode: Cardinal;
    {* 接收缓冲 *}
    FRecvBuf: TByteDynArray;
    {* 连接 *}
    function Connect(const AFlag: Char): Boolean;
    {* 断开连接 *}
    procedure Disconnect;
    {* 返回错误描述 *}
    function GetErrorCodeString(const AErrorCode: Cardinal): string; virtual;
    {* 发送命令等待返回 *}
    function ControlCommand(const ACommand: string; ARequest, AResponse: TStrings): Boolean; overload;
    function ControlCommand(const ACommand: string; ARequest, AResponse: TStrings;
      const AData: string): Boolean; overload;
    function ControlCommand(const ACommand: string; ARequest, AResponse: TStrings;
      const AData: array of Byte): Boolean; overload;
    function ControlCommand(const ACommand: string; ARequest: TStrings; var ACount: Integer): Boolean; overload;
    function ControlCommand(const ACommand: string; ARequest, AResponse: TStrings;
      const ABuffer; const ACount: Integer): Boolean; overload;
    {* 分析命令返回中的Item项 *}
    procedure ParseItem(AResponse, AOut: TStrings);
    {* 返回是否在连接状态 *}
    function GetConnected: Boolean;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    {* 发送数据给服务器 *}
    function SendCommand(const ACommand: string; ARequest: TStrings; const AData: string): Boolean; overload;
    function SendCommand(const ACommand: string; ARequest: TStrings; const ABuffer; const ACount: Integer): Boolean; overload;
    {* 单纯接收命令 *}
    function RecvCommand(AResponse: TStrings): Boolean;
    {* 接收数据并放在RecvBuff中 *}
    function RecvData(var ALen: Integer): Boolean;
    property Client: TIdTCPClient read FClient;
    property Host: string read FHost write FHost;
    property Port: Integer read FPort write FPort;
    property LastError: string read FLastError write FLastError;
    property LastErrorCode: Cardinal read FLastErrorCode;
    property TimeOutMS: Cardinal read FTimeOutMS write FTimeOutMS;
    property Connected: Boolean read GetConnected;
    property RecvBuf: TByteDynArray read FRecvBuf;
  end;

  TCommandThread = class;
  TRecvThread = class;
  {* 进度更新函数 *}
  TNotifyProgress = procedure(const ATotalByte, ARecvByte: Int64) of object;
  {* 速度更新函数 *}
  TNotifySpeed = procedure(const ATotalByte: Int64; const ATotalTimeMS: Int64) of object;
  {* 把SOCKET用线程进行封装 *}
  TThreadClientSocket = class(TBaseClientSocket)
  private
    {* 下载通知事件 *}
    FNotifyEvent: TSimpleEvent;
    {* 命令是否执行成功 *}
    FCommandSuccess: Boolean;

    {* 总大小和已下载大小 *}
    FTotalByte, FRecvByte: Int64;
    {* 下载时间 *}
    FTotalTimeMS: Int64;
    {* 进度更新事件 *}
    FOnProgress: TNotifyProgress;
    {* 速度更新事件 *}
    FOnSpeed: TNotifySpeed;
    {* 执行线程，每个执行任务负责创建和销毁 *}
    FCommandThread: TCommandThread;
    FRecvThread: TRecvThread;
    {* 下载成功 *}
    procedure DoSuccessDownload;
    {* 下载失败 *}
    procedure DoFailedDownload;
    {* 下载进度更新 *}
    procedure UpdateProgress;
    {* 下载速度 *}
    procedure UpdateSpeed;
  protected
    {* 线程执行命令 *}
    function ControlCommandThread(const ACommand: string; ARequest, AResponse: TStrings;
      const AData: string): Boolean;
    {* 线程请求数据 *}
    function RequestDataThread(const ACommand: string; ARequest: TStrings;
      const AData: string; AStream: TStream): Boolean;
  public
    constructor Create; override;
    destructor Destroy; override;
    property OnProgress: TNotifyProgress read FOnProgress write FOnProgress;
    property OnSpeed: TNotifySpeed read FOnSpeed write FOnSpeed;
  end;

  {* 执行线程 *}
  TCommandThread = class(TThread)
  private
    {* 请求字符串 *}
    FRequest, FResponse: TStringList;
    {* 命令 *}
    FCommand, FData: string;
    {* 协议对象 *}
    FClientSocket: TThreadClientSocket;
  protected
    procedure Execute; override;
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
  end;

  {* 接收线程 *}
  TRecvThread = class(TThread)
  private
    {* 请求字符串 *}
    FRequest, FResponse: TStringList;
    {* 命令 *}
    FCommand, FData: string;
    {* 协议对象 *}
    FClientSocket: TThreadClientSocket;
    {* 接收数据存放流 *}
    FDestStream: TStream;
  protected
    procedure Execute; override;
  public
    constructor Create(CreateSuspended: Boolean);
    destructor Destroy; override;
  end;

implementation

uses DateUtils, BasisFunction;

{ TBaseClientSocket }

constructor TBaseClientSocket.Create;
begin
  FClient := TIdTCPClient.Create(nil);
  FTimeOutMS := CI_ReadTimeOut;
  FLastErrorCode := MaxInt;
end;

destructor TBaseClientSocket.Destroy;
begin
  FClient.Free;
  inherited;
end;

function TBaseClientSocket.Connect(const AFlag: Char): Boolean;
begin
  FClient.Host := FHost;
  FClient.Port := FPort;
  try
    if FClient.Connected then
      FClient.Disconnect;
    FClient.CheckForDisconnect(False);
    FClient.Connect(60 * 1000);
    FClient.Write(AFlag);
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := False;
    end;
  end;
end;

procedure TBaseClientSocket.Disconnect;
begin
  FClient.Disconnect;
  FClient.Free;
  FClient := TIdTCPClient.Create(nil);
end;

function TBaseClientSocket.GetErrorCodeString(
  const AErrorCode: Cardinal): string;
begin
  FLastErrorCode := AErrorCode;
  case AErrorCode of
    $00000001: Result := 'Unknow Command';
    $00000002: Result := 'Packet Length Error';
    $00000003: Result := 'Packet Format Error';
    $00000004: Result := 'Unknow Error';
    $00000005: Result := 'Command Key Lost';
    $00000006: Result := 'Command Parameter Error';
    $00000007: Result := 'User or Password error';
  else
    Result := '0x' + IntToHex(AErrorCode, 8);
  end;
end;

function TBaseClientSocket.SendCommand(const ACommand: string;
  ARequest: TStrings; const AData: string): Boolean;
var
  slBuff: TStringList;
  dwPacketLen, dwCommandLen: Cardinal;
  sBuff: string;
  utf8Command, utf8Data: UTF8String;
begin
  slBuff := TStringList.Create;
  try
    FClient.ReadTimeout := FTimeOutMS;
    FClient.MaxLineLength := 1024 * 1024 * 1024;

    FClient.OpenWriteBuffer(-1); //-1表示外面手动刷新发送
    try
      slBuff.Add('[' + CSRequest + ']');
      slBuff.Add(CSCommand + CSEqualSign + ACommand);
      if Assigned(ARequest) then
        slBuff.AddStrings(ARequest);
      sBuff := slBuff.Text;
      utf8Command := AnsiToUtf8(sBuff); //把ANSI转为UTF-8
      if not IsEmptyStr(AData) then
        utf8Data := AnsiToUtf8(AData); //把ANSI转为UTF-8
      dwPacketLen := SizeOf(Cardinal) + Length(utf8Command) + Length(utf8Data); //总长度
      dwCommandLen := Length(utf8Command); //命令长度
      FClient.WriteCardinal(dwPacketLen, False); //发送整个包长度
      FClient.WriteCardinal(dwCommandLen, False); //发送命令长度
      FClient.WriteBuffer(PUTF8String(utf8Command)^, dwCommandLen, False); //发送命令内容
      if not IsEmptyStr(AData) then
        FClient.WriteBuffer(PUTF8String(utf8Data)^, Length(utf8Data), False); //发送数据
      FClient.CloseWriteBuffer; //发送当前全部数据
      Result := True;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := False;
        //FClient.CancelWriteBuffer;
      end;
    end;
  finally
    slBuff.Free;
  end;
end;

function TBaseClientSocket.SendCommand(const ACommand: string;
  ARequest: TStrings; const ABuffer; const ACount: Integer): Boolean;
var
  slBuff: TStringList;
  dwPacketLen, dwCommandLen: Cardinal;
  sBuff: string;
  utf8Command: UTF8String;
begin
  slBuff := TStringList.Create;
  try
    FClient.ReadTimeout := FTimeOutMS;
    FClient.MaxLineLength := 1024 * 1024 * 1024;

    FClient.OpenWriteBuffer(-1); //-1表示外面手动刷新发送
    try
      slBuff.Add('[' + CSRequest + ']');
      slBuff.Add(CSCommand + CSEqualSign + ACommand);
      if Assigned(ARequest) then
        slBuff.AddStrings(ARequest);
      sBuff := slBuff.Text;
      utf8Command := AnsiToUtf8(sBuff); //把ANSI转为UTF-8
      dwPacketLen := SizeOf(Cardinal) + Length(utf8Command) + ACount; //总长度
      dwCommandLen := Length(utf8Command); //命令长度
      FClient.WriteCardinal(dwPacketLen, False); //发送整个包长度
      FClient.WriteCardinal(dwCommandLen, False); //发送命令长度
      FClient.WriteBuffer(PUTF8String(utf8Command)^, dwCommandLen, False); //发送命令内容
      FClient.WriteBuffer(ABuffer, ACount, False); //发送数据
      FClient.CloseWriteBuffer; //发送当前全部数据
      Result := True;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := False;
        //FClient.CancelWriteBuffer;
      end;
    end;
  finally
    slBuff.Free;
  end;
end;

function TBaseClientSocket.RecvCommand(AResponse: TStrings): Boolean;
var
  dwPacketLen, dwCommandLen, dwCode: Cardinal;
  utf8Buff: UTF8String;
  slBuff: TStringList;
begin
  slBuff := TStringList.Create;
  try
    try
      FClient.ReadTimeout := CI_ReadTimeOut;
      FClient.MaxLineLength := 1024 * 1024 * 1024;
      dwPacketLen := FClient.ReadCardinal(False); //读取整个包长度
      dwCommandLen := FClient.ReadCardinal(False); //读取命令长度
      SetLength(utf8Buff, dwPacketLen - SizeOf(Cardinal));
      FClient.ReadBuffer(PUTF8String(utf8Buff)^, dwPacketLen - SizeOf(Cardinal));
      slBuff.Text := Utf8ToAnsi(Copy(utf8Buff, 0, dwCommandLen));
      dwCode := Cardinal(StrToInt(slBuff.Values[CSCode]));
      Result := dwCode = 0;
      if not Result then
        FLastError := GetErrorCodeString(dwCode) + ': ' + slBuff.Values[CSMessage];
      if Assigned(AResponse) then
        AResponse.Text := slBuff.Text;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := False;
      end;
    end;
  finally
    slBuff.Free;
  end;
end;

function TBaseClientSocket.RecvData(var ALen: Integer): Boolean;
var
  dwPacketLen, dwCommandLen, dwCode: Cardinal;
  TmpBuffer: array of Byte;
  utf8Command: UTF8String;
  slBuff: TStringList;
begin
  slBuff := TStringList.Create;
  try
    try
      FClient.ReadTimeout := CI_ReadTimeOut;
      FClient.MaxLineLength := 1024 * 1024 * 1024;
      dwPacketLen := FClient.ReadCardinal(False); //读取整个包长度
      dwCommandLen := FClient.ReadCardinal(False); //读取命令长度
      SetLength(TmpBuffer, dwPacketLen - SizeOf(Cardinal));
      FClient.ReadBuffer(TmpBuffer[0], dwPacketLen - SizeOf(Cardinal));
      if dwPacketLen > SizeOf(Cardinal) then
      begin
        SetLength(utf8Command, dwCommandLen);
        CopyMemory(PUTF8String(utf8Command), @TmpBuffer[0], dwCommandLen);
        slBuff.Clear;
        slBuff.Text := Utf8ToAnsi(utf8Command); //转换为ANSI
        dwCode := Cardinal(StrToInt(slBuff.Values[CSCode]));
        Result := dwCode = 0;
        if not Result then
        begin
          FLastError := GetErrorCodeString(dwCode) + ': ' + slBuff.Values[CSMessage];
          Result := False;
          Exit;
        end;

        ALen := dwPacketLen - (dwCommandLen + SizeOf(Cardinal));
        if ALen > Length(FRecvBuf) then
          SetLength(FRecvBuf, ALen);
        CopyMemory(@FRecvBuf[0], @TmpBuffer[dwCommandLen], ALen);
        Result := True;
      end
      else
        Result := False;
    except
      on E: Exception do
      begin
        Result := False;
        FLastError := E.Message;
      end;
    end;
  finally
    slBuff.Free;
  end;
end;

function TBaseClientSocket.ControlCommand(const ACommand: string; ARequest,
  AResponse: TStrings): Boolean;
begin
  Result := SendCommand(ACommand, ARequest, '');
  if Result then
    Result := RecvCommand(AResponse);
end;

function TBaseClientSocket.ControlCommand(const ACommand: string;
  ARequest, AResponse: TStrings; const AData: string): Boolean;
begin
  Result := SendCommand(ACommand, ARequest, AData);
  if Result then
    Result := RecvCommand(AResponse);
end;

function TBaseClientSocket.ControlCommand(const ACommand: string; ARequest,
  AResponse: TStrings; const AData: array of Byte): Boolean;
begin
  Result := SendCommand(ACommand, ARequest, AData[0], Length(AData));
  if Result then
    Result := RecvCommand(AResponse);
end;

function TBaseClientSocket.ControlCommand(const ACommand: string; ARequest: TStrings; var ACount: Integer): Boolean;
begin
  Result := SendCommand(ACommand, ARequest, '');
  if Result then
    Result := RecvData(ACount);
end;

function TBaseClientSocket.ControlCommand(const ACommand: string; ARequest,
  AResponse: TStrings; const ABuffer; const ACount: Integer): Boolean;
begin
  Result := SendCommand(ACommand, ARequest, ABuffer, ACount);
  if Result then
    Result := RecvCommand(AResponse);
end;

procedure TBaseClientSocket.ParseItem(AResponse, AOut: TStrings);
var
  i: Integer;
begin
  for i := 0 to AResponse.Count - 1 do
  begin
    if SameText(AResponse.Names[i], CSItem) then
    begin
      AOut.Add(AResponse.ValueFromIndex[i]);
    end;
  end;
end;

function TBaseClientSocket.GetConnected: Boolean;
begin
  Result := FClient.Connected;
end;

{ TThreadClientSocket }

constructor TThreadClientSocket.Create;
begin
  inherited;
  FNotifyEvent := TSimpleEvent.Create;
end;

destructor TThreadClientSocket.Destroy;
begin
  FNotifyEvent.Free;
  inherited;
end;

procedure TThreadClientSocket.DoFailedDownload;
begin
  FCommandSuccess := False;
end;

procedure TThreadClientSocket.DoSuccessDownload;
begin
  FCommandSuccess := True;
end;

procedure TThreadClientSocket.UpdateProgress;
begin
  if Assigned(FOnProgress) then
    FOnProgress(FTotalByte, FRecvByte);
end;

procedure TThreadClientSocket.UpdateSpeed;
begin
  if Assigned(FOnSpeed) then
    FOnSpeed(FRecvByte, FTotalTimeMS);
end;

function TThreadClientSocket.ControlCommandThread(const ACommand: string;
  ARequest, AResponse: TStrings; const AData: string): Boolean;
begin
  FCommandThread := TCommandThread.Create(True);
  try
    FNotifyEvent.ResetEvent;
    if Assigned(ARequest) then
      FCommandThread.FRequest.Text := ARequest.Text;
    FCommandThread.FCommand := ACommand;
    FCommandThread.FData := AData;
    FCommandThread.FClientSocket := Self;
    FCommandThread.FreeOnTerminate := False;
    FCommandThread.Resume;
    while FNotifyEvent.WaitFor(100) = wrTimeout do
    begin
      Application.ProcessMessages;
    end;
    if FCommandSuccess then //数据下载完成
    begin
      Result := True;
      if Assigned(AResponse) then
        AResponse.Text := FCommandThread.FResponse.Text;
    end
    else
    begin
      Result := False;
    end;
  finally
    FreeAndNil(FCommandThread);
  end;
end;

function TThreadClientSocket.RequestDataThread(const ACommand: string;
  ARequest: TStrings; const AData: string; AStream: TStream): Boolean;
begin
  FRecvThread := TRecvThread.Create(True);
  try
    FNotifyEvent.ResetEvent;
    if Assigned(ARequest) then
      FRecvThread.FRequest.Text := ARequest.Text;
    FRecvThread.FCommand := ACommand;
    FRecvThread.FData := AData;
    FRecvThread.FDestStream := AStream;
    FRecvThread.FClientSocket := Self;
    FRecvThread.FreeOnTerminate := False;
    FRecvThread.Resume;
    while FNotifyEvent.WaitFor(100) = wrTimeout do
    begin
      Application.ProcessMessages;
    end;
    if FCommandSuccess then //数据下载完成
    begin
      AStream.Position := 0;
      Result := True;
    end
    else
    begin
      Result := False;         
    end;
  finally
    FreeAndNil(FRecvThread);
  end;
end;

{ TCommandThread }

constructor TCommandThread.Create(CreateSuspended: Boolean);
begin
  FRequest := TStringList.Create;
  FResponse := TStringList.Create;
  inherited Create(CreateSuspended);
end;

destructor TCommandThread.Destroy;
begin
  FRequest.Free;
  FResponse.Free;
  inherited;
end;

procedure TCommandThread.Execute;
begin
  inherited;
  try
    if FClientSocket.ControlCommand(FCommand, FRequest, FResponse, FData) then //获取数据成功
      Synchronize(FClientSocket.DoSuccessDownload)
    else
      Synchronize(FClientSocket.DoFailedDownload);
  finally
    FClientSocket.FNotifyEvent.SetEvent; //通知主线程，执行完成
  end;
end;

{ TRecvThread }

constructor TRecvThread.Create(CreateSuspended: Boolean);
begin
  FRequest := TStringList.Create;
  FResponse := TStringList.Create;
  inherited Create(CreateSuspended);
end;

destructor TRecvThread.Destroy;
begin
  FRequest.Free;
  FResponse.Free;
  inherited;
end;

procedure TRecvThread.Execute;
var
  iFileSize, iRecvSize, iTimeLength: Int64;
  iLen: Integer;
  StartTime: TDateTime;
begin
  inherited;
  try
    try
      if FClientSocket.ControlCommand(FCommand, FRequest, FResponse, FData) then //获取数据成功
      begin
        if FClientSocket.RecvCommand(FResponse) then
        begin
          StartTime := Now;
          iFileSize := StrToInt64(FResponse.Values[CSFileSize]);
          iRecvSize := 0;
          FClientSocket.FTotalByte := iFileSize;
          FClientSocket.FRecvByte := iRecvSize;
          Synchronize(FClientSocket.UpdateProgress);
          while (iRecvSize < iFileSize) and (not Terminated) do
          begin
            if FClientSocket.RecvData(iLen) then
              FDestStream.Write(FClientSocket.FRecvBuf[0], iLen)
            else
              raise Exception.Create(FClientSocket.LastError);
            iRecvSize := iRecvSize + iLen;
            iTimeLength := MilliSecondsBetween(Now, StartTime);
            if iTimeLength > 0 then //更新速度
            begin
              FClientSocket.FTotalByte := iRecvSize;
              FClientSocket.FTotalTimeMS := iTimeLength;
              Synchronize(FClientSocket.UpdateSpeed);
            end;
            FClientSocket.FTotalByte := iFileSize;
            FClientSocket.FRecvByte := iRecvSize;
            Synchronize(FClientSocket.UpdateProgress);
          end;
          Synchronize(FClientSocket.DoSuccessDownload); //下载成功
        end
        else
          Synchronize(FClientSocket.DoFailedDownload);
      end
      else
        Synchronize(FClientSocket.DoFailedDownload);
    except
      on E: Exception do
      begin
        FClientSocket.FLastError := E.Message;
        Synchronize(FClientSocket.DoFailedDownload);
      end;
    end;
  finally
    FClientSocket.FNotifyEvent.SetEvent; //通知主线程，执行完成
  end;
end;

end.

