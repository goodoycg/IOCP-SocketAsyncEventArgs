unit ControlSocket;

interface

uses
  IdTCPClient, BasisFunction, Windows, SysUtils, Classes, SyncObjs, DefineUnit,
  Types, BaseClientSocket, IdIOHandlerSocket, Messages;

type
  TOnClients = procedure(AItems: TStrings) of object;
  TControlThread = class;
  TControlScoket = class(TBaseClientSocket)
  private
    {* 用户名 *}
    FUser, FPassword: string;
    {* 控制线程 *}
    FControlThread: TControlThread;
    {* 任务收到通知事件 *}
    FOnClients: TOnClients;
  protected
    {* 检测连接是否存在 *}
    function CheckActive: Boolean;
    {* 重连 *}
    function ReConnect: Boolean;
    {* 重连和登录 *}
    function ReConnectAndLogin: Boolean;
  public
    constructor Create; override;
    destructor Destroy; override;
    {* 连接服务器 *}
    function Connect(const ASvr: string; APort: Integer): Boolean;
    {* 断开连接 *}
    procedure Disconnect;
    {* 登陆 *}
    function Login(const AUser, APassword: string): Boolean;
    {* 获取客户端列表 *}
    function GetClients(AItems: TStrings): Boolean;
    {* 启动 *}
    procedure Start;
    {* 停止 *}
    procedure Stop;
    property User: string read FUser;
    property OnClients: TOnClients read FOnClients write FOnClients;
  end;

  TControlThread = class(TThread)
  private
    FControlScoket: TControlScoket;
    {* 任务列表存储 *}
    FClients: TStringList;
    {* 触发任务收到通知事件 *}
    procedure DoClients;
  protected
    procedure Execute; override;
  end;

implementation

uses IdTCPConnection, DataMgrCtr, ClientDefineUnit, Logger;

{ TStatImportScoket }

constructor TControlScoket.Create;
begin
  inherited;
  FTimeOutMS := 60 * 1000; //超时设置为60S
end;

destructor TControlScoket.Destroy;
begin
  inherited;
end;

function TControlScoket.Connect(const ASvr: string;
  APort: Integer): Boolean;
begin
  FHost := ASvr;
  FPort := APort;
  Result := inherited Connect(#8);
end;

procedure TControlScoket.Disconnect;
begin
  inherited Disconnect;
end;

function TControlScoket.Login(const AUser, APassword: string): Boolean;
var
  slRequest: TStringList;
begin
  Result := ReConnect;
  if not Result then Exit;
  slRequest := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSUserName, AUser]));
    slRequest.Add(Format(CSFmtString, [CSPassword, MD5String(APassword)]));
    Result := ControlCommand(CSControlCmd[ccLogin], slRequest, nil, '');
    if Result then
    begin
      FUser := AUser;
      FPassword := APassword;
    end;
  finally
    slRequest.Free;
  end;
end;

function TControlScoket.CheckActive: Boolean;
var
  slRequest: TStringList;
begin
  slRequest := TStringList.Create;
  try
    try
      Result := ControlCommand(CSControlCmd[ccActive], nil, nil, '');
    except
      Result := False;
    end;
  finally
    slRequest.Free;
  end;
end;

function TControlScoket.ReConnect: Boolean;
begin
  FTimeOutMS := CI_ReadTimeOut;
  if FClient.Connected and (not CheckActive) then
    Disconnect; //断开连接重新连
  if not FClient.Connected then
  begin
    Result := Connect(FHost, FPort);
  end
  else
    Result := True;
end;

function TControlScoket.ReConnectAndLogin: Boolean;
begin
  FTimeOutMS := CI_ReadTimeOut;
  if FClient.Connected and (not CheckActive) then
    Disconnect; //断开连接重新连
  if not FClient.Connected then
  begin 
    Result := Connect(FHost, FPort);
    if Result then
      Result := Login(FUser, FPassword);
  end
  else
    Result := True;
end;

function TControlScoket.GetClients(AItems: TStrings): Boolean;
var
  slResponse: TStringList;
  i: Integer;
begin
  Result := ReConnectAndLogin;
  if Result then
  begin
    slResponse := TStringList.Create;
    try
      Result := ControlCommand(CSControlCmd[ccGetClients], nil, slResponse, '');
      if Result then
      begin
        for i := 0 to slResponse.Count - 1 do
        begin
          if SameText(slResponse.Names[i], 'Item') then
            AItems.Add(slResponse.ValueFromIndex[i]); 
        end;
      end;
    finally
      slResponse.Free;
    end;
  end;
end;

procedure TControlScoket.Start;
begin
  FControlThread := TControlThread.Create(True);
  FControlThread.FreeOnTerminate := False;
  FControlThread.FControlScoket := Self;
  FControlThread.Resume;
end;

procedure TControlScoket.Stop;
begin
  Disconnect;
  FControlThread.Terminate;
  FControlThread.WaitFor;
  FControlThread.Free;
end;

{ TStatImportThread }

procedure TControlThread.DoClients;
begin
  if Assigned(FControlScoket.OnClients) then
    FControlScoket.OnClients(FClients);
end;

procedure TControlThread.Execute;
var
  i: Integer;
begin
  inherited;
  FClients := TStringList.Create;
  try
    while (not Terminated) and (FControlScoket.Connected) do
    begin
      try
        FClients.Clear;
        if FControlScoket.GetClients(FClients) then
          Synchronize(DoClients);
        for i := 0 to 10 * 1000 div 10 do //10S刷一次
        begin
          if Terminated then Break;
          Sleep(10);
        end;
      except
        on E: Exception do
        begin
          WriteLogMsg(ltError, 'Get Clients Error, Message: ' + E.Message);
          Break;
        end;
      end;
    end;
    PostMessage(GDataMgrCtr.NotifyHandle, WM_Disconnect, 0, 0);
  finally
    FClients.Free;
  end;
end;

end.
