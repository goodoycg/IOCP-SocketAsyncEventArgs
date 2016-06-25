unit SQLSocket;

interface

uses
  IdTCPClient, BasisFunction, Windows, SysUtils, Classes, SyncObjs, DefineUnit,
  Types, BaseClientSocket, IdIOHandlerSocket, Messages;

type
  TSQLSocket = class(TThreadClientSocket)
  private
    {* 用户名 *}
    FUser, FPassword: string;
  protected
    {* 检测连接是否存在 *}
    function CheckActive: Boolean;
    {* 重连 *}
    function ReConnect: Boolean;
    {* 重连和登录 *}
    function ReConnectAndLogin: Boolean;
    {* 返回错误描述 *}
    function GetErrorCodeString(const AErrorCode: Cardinal): string; override;
  public
    constructor Create; override;
    destructor Destroy; override;
    {* 连接服务器 *}
    function Connect(const ASvr: string; APort: Integer): Boolean;
    {* 断开连接 *}
    procedure Disconnect;
    {* 登陆 *}
    function Login(const AUser, APassword: string): Boolean;
    {* 查询SQL语句 *}
    function SQLOpen(const ASQL: string; AStream: TStream): Boolean;
    {* 执行SQL语句 *}
    function SQLExec(const ASQL: string; var AEffectRow: Integer): Boolean;
    {* 开始事务 *}
    function BeginTrans: Boolean;
    {* 提交事务 *}
    function CommitTrans: Boolean;
    {* 回滚事务 *}
    function RollbackTrans: Boolean;
    property User: string read FUser write FUser;
    property Password: string read FPassword write FPassword;
  end;

implementation

{ TSQLSocket }

constructor TSQLSocket.Create;
begin
  inherited;
  FTimeOutMS := 60 * 1000; //超时设置为60S
end;

destructor TSQLSocket.Destroy;
begin
  inherited;
end;

function TSQLSocket.GetErrorCodeString(const AErrorCode: Cardinal): string;
begin
  case AErrorCode of
    CISQLOpenError: Result := 'SQL Open Error';
    CISQLExecError: Result := 'SQL Exec Error';
    CIHavedBeginTrans: Result := 'Haved Begin Trans';
    CIBeginTransError: Result := 'Begin Trans Error';
    CINotExistTrans: Result := 'No Begin Trans';
    CICommitTransError: Result := 'Commit Trans Error';
    CIRollbackTransError: Result := 'Rollback Trans Error';
  else
    Result := inherited GetErrorCodeString(AErrorCode);
  end;
end;

function TSQLSocket.CheckActive: Boolean;
var
  slRequest: TStringList;
begin
  slRequest := TStringList.Create;
  try
    try
      Result := ControlCommand(CSSQLCmd[scActive], nil, nil, '');
    except
      Result := False;
    end;
  finally
    slRequest.Free;
  end;
end;

function TSQLSocket.ReConnect: Boolean;
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

function TSQLSocket.ReConnectAndLogin: Boolean;
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

function TSQLSocket.Connect(const ASvr: string; APort: Integer): Boolean;
begin
  FHost := ASvr;
  FPort := APort;
  Result := inherited Connect(#1);
end;

procedure TSQLSocket.Disconnect;
begin
  inherited Disconnect;
end;

function TSQLSocket.Login(const AUser, APassword: string): Boolean;
var
  slRequest: TStringList;
begin
  Result := ReConnect;
  if not Result then Exit;
  slRequest := TStringList.Create;
  try
    slRequest.Add(Format(CSFmtString, [CSUserName, AUser]));
    slRequest.Add(Format(CSFmtString, [CSPassword, MD5String(APassword)]));
    Result := ControlCommand(CSSQLCmd[scLogin], slRequest, nil, '');
    if Result then
    begin
      FUser := AUser;
      FPassword := APassword;
    end;
  finally
    slRequest.Free;
  end;
end;

function TSQLSocket.SQLOpen(const ASQL: string; AStream: TStream): Boolean;
begin
  Result := ReConnectAndLogin;
  if not Result then Exit;
  Result := RequestDataThread(CSSQLCmd[scSQLOpen], nil, ASQL, AStream);
end;

function TSQLSocket.SQLExec(const ASQL: string; var AEffectRow: Integer): Boolean;
var
  slResponse: TStringList;
begin
  Result := ReConnectAndLogin;
  if not Result then Exit;
  slResponse := TStringList.Create;
  try
    Result := ControlCommandThread(CSSQLCmd[scSQLExec], nil, slResponse, ASQL);
    if Result then
      AEffectRow := StrToInt(slResponse.Values[CSEffectRow]);
  finally
    slResponse.Free;
  end;
end;

function TSQLSocket.BeginTrans: Boolean;
var
  slResponse: TStringList;
begin
  Result := ReConnectAndLogin;
  if not Result then Exit;
  slResponse := TStringList.Create;
  try
    Result := ControlCommandThread(CSSQLCmd[scBeginTrans], nil, slResponse, '');
  finally
    slResponse.Free;
  end;
end;

function TSQLSocket.CommitTrans: Boolean;
var
  slResponse: TStringList;
begin
  slResponse := TStringList.Create;
  try
    Result := ControlCommandThread(CSSQLCmd[scCommitTrans], nil, slResponse, '');
  finally
    slResponse.Free;
  end;
end;

function TSQLSocket.RollbackTrans: Boolean;
var
  slResponse: TStringList;
begin
  slResponse := TStringList.Create;
  try
    Result := ControlCommandThread(CSSQLCmd[scRollbackTrans], nil, slResponse, '');
  finally
    slResponse.Free;
  end;
end;

end.
