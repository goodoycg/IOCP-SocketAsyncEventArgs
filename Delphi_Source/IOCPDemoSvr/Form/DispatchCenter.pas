unit DispatchCenter;

interface

uses
  SysUtils, Classes, IOCPSocket, Windows, DateUtils, ActiveX, BaseSocket;

type
  {* Socket超时线程和事务检测线程 *}
  TTimeOutThread = class(TThread)
  private
    FIcpSvr: TIocpServer;
  protected
    procedure Execute; override;
    property IcpSvr: TIocpServer read FIcpSvr write FIcpSvr;
  end;

  TDMDispatchCenter = class(TDataModule)
    IcpSvr: TIocpServer;
    procedure IcpSvrError(const AName, AError: String);
    procedure IcpSvrConnect(const ASocket: Cardinal;
      var AAllowConnect: Boolean; var SocketHandle: TSocketHandle);
    procedure IcpSvrDisconnect(const ASocketHandle: TSocketHandle);
  private
    FActive: Boolean;
    {* 超时检测线程 *}
    FTimeOutThread: TTimeOutThread;
  public
    {* 启动服务 *}
    function Start: Boolean;
    {* 停止服务 *}
    function Stop: Boolean;
    property Active: Boolean read FActive;
  end;

var
  DMDispatchCenter: TDMDispatchCenter;

implementation

uses OptionSet, Logger, DefineUnit, DBConnect, SQLSocket, LogSocket,
  ControlSocket, UploadSocket, DownloadSocket, RemoteStreamSocket;

{$R *.dfm}

{ TdmProtocol }

function TDMDispatchCenter.Start: Boolean;

  procedure SetLogFilter;
  var
    i: Integer;
    LogHandler: TLogHandler;
  begin
    for i := 0 to GLogger.LogHandlerMgr.Count - 1 do
    begin
      LogHandler := GLogger.LogHandlerMgr.Items[i];
      if LogHandler is TLogFileHandler then
        LogHandler.LogFilter := GIniOptions.LogFile
      else if LogHandler is TLogDesktopHandler then
        LogHandler.LogFilter := GIniOptions.LogDesktop
      else if LogHandler is TLogSocketHandler then
        LogHandler.LogFilter := GIniOptions.LogSocket;
    end;
  end;
begin
  CoInitialize(nil); //服务状态下初始COM
  try
    if not DirectoryExists(GIniOptions.FileDirestory) then
      ForceDirectories(GIniOptions.FileDirestory);
    {if GIniOptions.DBConnectDB then
    begin
      GDBConnect.SetConConfig(GIniOptions.DBServer, GIniOptions.DBName, GIniOptions.DBLoginName,
        GIniOptions.DBPassword, GIniOptions.DBAuthentication, GIniOptions.DBPort);
      GDBConnect.TestConnect;
    end;}
    SetLogFilter;
    IcpSvr.MaxWorkThrCount := GIniOptions.MaxWorkThreadCount;
    IcpSvr.MinWorkThrCount := GIniOptions.MinWorkThreadCount;
    IcpSvr.MaxCheckThrCount := GIniOptions.MaxListenThreadCount;
    IcpSvr.MinCheckThrCount := GIniOptions.MinListenThreadCount;
    IcpSvr.Port := GIniOptions.SocketPort;
    IcpSvr.Active := True;
    FActive := True;
    WriteLogMsg(ltInfo, 'Open Port: ' + IntToStr(IcpSvr.Port) + ' Success');
    WriteLogMsg(ltInfo, 'Open Server Success');
    FTimeOutThread := TTimeOutThread.Create(True);
    FTimeOutThread.FreeOnTerminate := False;
    FTimeOutThread.IcpSvr := IcpSvr;
    FTimeOutThread.Resume;
    Result := True;
  except
    on E: Exception do
    begin
      WriteLogMsg(ltError, 'Start Server Error: ' + E.Message);
      Result := False;
    end;
  end;
end;

function TDMDispatchCenter.Stop: Boolean;
begin
  try
    FTimeOutThread.Terminate;
    FTimeOutThread.WaitFor;
    FTimeOutThread.Free;
    IcpSvr.Active := False;
    FActive := False;
    WriteLogMsg(ltInfo, 'Stop Server Success');
    Result := True;
  except
    on E: Exception do
    begin
      WriteLogMsg(ltError, 'Stop Server Error: ' + E.Message);
      Result := False;
    end;
  end;
end;

procedure TDMDispatchCenter.IcpSvrError(const AName, AError: String);
begin
  WriteDebugLogMsg(ltError, AName + ';' + AError);
end;

procedure TDMDispatchCenter.IcpSvrConnect(const ASocket: Cardinal;
  var AAllowConnect: Boolean; var SocketHandle: TSocketHandle);
var
  BaseSocket: TBaseSocket;
  chFlag: Char;

  function GetSocket(const AEnable: Boolean; BaseSocketClass: TBaseSocketClass): TBaseSocket;
  begin
    if AEnable then
      Result := BaseSocketClass.Create(IcpSvr, ASocket)
    else
      Result := nil;
  end;
begin
  if (GIniOptions.MaxSocketCount > 0) and (IcpSvr.SocketHandles.Count >= GIniOptions.MaxSocketCount) then
  begin
    AAllowConnect := False;
    Exit;
  end;
  if IcpSvr.ReadChar(ASocket, chFlag, 6*1000) then //必须在6S内收到标志
  begin
    case TSocketFlag(Byte(chFlag)) of
      //sfSQL: BaseSocket := GetSocket(GIniOptions.SQLProtocol, TSQLSocket);
      sfUpload: BaseSocket := GetSocket(GIniOptions.UploadProtocol, TUploadSocket);
      sfDownload: BaseSocket := GetSocket(GIniOptions.DownloadProtocol, TDownloadSocket);
      sfRemoteStream: BaseSocket := GetSocket(GIniOptions.RemoteStreamProtocol, TRemoteStreamSocket);
      sfControl: BaseSocket := GetSocket(GIniOptions.ControlProtocol, TControlSocket);
      sfLog: BaseSocket := GetSocket(GIniOptions.LogProtocol, TLogSocket);
    else
      BaseSocket := nil;;
    end;
    if BaseSocket <> nil then
    begin
      SocketHandle := BaseSocket;
      WriteLogMsg(ltDebug, Format('Client Connect, Local Address: %s:%d; Remote Address: %s:%d',
        [SocketHandle.LocalAddress, SocketHandle.LocalPort, SocketHandle.RemoteAddress, SocketHandle.RemotePort]));
      WriteLogMsg(ltDebug, Format('Client Count: %d', [IcpSvr.SocketHandles.Count + 1]));
      AAllowConnect := True;
    end
    else
      AAllowConnect := False;
  end
  else
    AAllowConnect := False;
end;

procedure TDMDispatchCenter.IcpSvrDisconnect(const ASocketHandle: TSocketHandle);
begin
  WriteLogMsg(ltDebug, Format('Client Disconnect, Local Address: %s:%d; Remote Address: %s:%d',
    [ASocketHandle.LocalAddress, ASocketHandle.LocalPort, ASocketHandle.RemoteAddress, ASocketHandle.RemotePort]));
end;

{ TTimeOutThread }

procedure TTimeOutThread.Execute;
var
  i, iMinutesInv: Integer;
  SQLSocket: TSQLSocket;
  BaseSocket: TBaseSocket;
begin
  inherited;
  while not Terminated do
  begin
    try
      FIcpSvr.CheckDisconnectedClient;
      FIcpSvr.SocketHandles.Lock;
      try
        for i := FIcpSvr.SocketHandles.Count - 1 downto 0 do
        begin
          if FIcpSvr.SocketHandles[i].SocketHandle is TSQLSocket then
          begin
            SQLSocket := FIcpSvr.SocketHandles[i].SocketHandle as TSQLSocket;
            iMinutesInv := MinutesBetween(Now, SQLSocket.ActiveTime);
            if SQLSocket.BeginTrans then //事务超时
            begin
              if iMinutesInv >= GIniOptions.TransTimeOut then
              begin
                SQLSocket.Disconnect;
              end;
            end
            else //Socket超时
            begin
              if iMinutesInv >= GIniOptions.SocketTimeOut then
              begin
                SQLSocket.Disconnect;
              end;
            end;
          end
          else
          begin
            BaseSocket := FIcpSvr.SocketHandles[i].SocketHandle as TBaseSocket;
            if not (BaseSocket is TLogSocket) then //日志协议不检测超时
            begin
              iMinutesInv := MinutesBetween(Now, BaseSocket.ActiveTime);
              if iMinutesInv >= GIniOptions.SocketTimeOut then //超时
              begin
                BaseSocket.Disconnect;
              end;
            end;
          end;
        end;
      finally
        FIcpSvr.SocketHandles.UnLock;
      end;
    except
      on E: Exception do
      begin
        WriteLogMsg(ltError, 'TTimeOutThread.Execute: ' + E.Message);
      end;
    end;
    i := 0;
    while (i < 60 * 10) and (not Terminated) do
    begin
      Inc(i);
      Sleep(100);
    end;
  end;
end;

end.
