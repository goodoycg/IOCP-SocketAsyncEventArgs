unit DBConnect;

interface

uses
  Windows, SysUtils, Classes, ADODB, DB, ADOConPool, ActiveX, SyncObjs, ComObj,
  DefineUnit;

type
  TDBConnection = class
  private
    FServer: string;
    FDBAuthentication: TDBAuthentication;
    FPort: Integer;
    FDBName: string;
    FUserName: string;
    FPassword: string;
    FADOConnectPool: TADOConPool;
    FLock: TCriticalSection;
  public
    constructor Create(const AServer, ADBName, AUserName, APassword: string;
      ADBAuthentication: TDBAuthentication; APort: Integer); overload;
    destructor Destroy; override;
    procedure GetADOConnection(var AValue: TADOConnection);
    procedure ReleaseADOConnetion(var AValue: TADOConnection);
    procedure SetConConfig(const AServer, ADBName, AUsername, APassword: string;
      ADBAuthentication: TDBAuthentication; APort: Integer);
    {* 查询SQl语句 *}
    procedure SQLOpen(var AQry: TADOQuery; const ASql: string);
    {* 执行SQL语句 *}
    function SQLExce(var AQry: TADOQuery; const ASql: string): Integer;
    {* 测试数据库连接，如果连接失败返回失败信息 *}
    function TestConnect: Boolean;
    {* 连接到数据库 *}
    procedure ConnectToDB(var AValue: TADOConnection);
    {* 获取数据库Name *}
    procedure GetAllDBName(ANames: TStrings);
    {* 获取数据库Server *}
    procedure GetServerList(ANames: TStrings);
  end;

var
  {* 全局数据库连接对象，程序启动创建，其余的单元公用，避免这个对象传来传去 *}
  GDBConnect: TDBConnection;    

implementation

{ TDBConnection }

constructor TDBConnection.Create(const AServer, ADBName, AUserName,
  APassword: string; ADBAuthentication: TDBAuthentication; APort: Integer);
begin
  inherited Create;
  CoInitialize(nil);
  FServer := AServer;
  FDBAuthentication := ADBAuthentication;
  FDBName := ADBName;
  FUserName := AUserName;
  FPassword := APassword;
  FPort := APort;
  FLock := TCriticalSection.Create;
  FADOConnectPool := TADOConPool.Create;
  if FDBAuthentication = daWindows then
  begin
    if FPort > 0 then
    begin
      FADOConnectPool.ConnectionString := Format('Provider=SQLOLEDB.1;Integrated '
        + 'Security=SSPI;Persist Security Info=True;Initial Catalog=%s;Data Source=%s,%d',
        [FDBName, FServer, FPort]);
    end
    else
    begin
      FADOConnectPool.ConnectionString := Format('Provider=SQLOLEDB.1;Integrated '
        + 'Security=SSPI;Persist Security Info=True;Initial Catalog=%s;Data Source=%s',
        [FDBName, FServer]);
    end;
  end
  else
  begin
    if FPort > 0 then
    begin
      FADOConnectPool.ConnectionString := Format('Provider=SQLOLEDB.1;Password=%s;'
        + 'Persist Security Info=True;User ID=%s;Initial Catalog=%s;Data Source=%s,%d',
        [FPassword, FUserName, FDBName, FServer, FPort]);
    end
    else
    begin
      FADOConnectPool.ConnectionString := Format('Provider=SQLOLEDB.1;Password=%s;'
        + 'Auto Translate=True;Persist Security Info=True;User ID=%s;Initial Catalog=%s;'
        + 'Data Source=%s', [FPassword, FUserName, FDBName, FServer]);
    end;
  end;
end;

procedure TDBConnection.ConnectToDB(var AValue: TADOConnection);
begin
  try
    GetADOConnection(AValue);
    if Assigned(AValue) then
    begin
      AValue.ConnectionString := FADOConnectPool.ConnectionString;
      AValue.ConnectionTimeout:= 3;
      AValue.Open;
    end;
  except
    on E: Exception do
    begin
      ReleaseADOConnetion(AValue);
      raise E.Create(Format('Connect Database Server Error, Server: %s, Port: %d, ClassName: %s, Message: %s',
        [FServer,FPort,E.ClassName,E.Message]));
    end;
  end;
end;

destructor TDBConnection.Destroy;
begin
  FADOConnectPool.Free;
  FLock.Free;
  CoUninitialize;
  inherited;
end;

procedure TDBConnection.GetADOConnection(var AValue: TADOConnection);
begin
  AValue := nil;
  try
    FADOConnectPool.GetConnection(AValue);
  except
    on E: Exception do
    begin
      raise E.Create(Format('Connect Database Server Error, Server: %s, Port: %d, ClassName: %s, Message: %s',
        [FServer, FPort, E.ClassName, E.Message]));
    end;
  end;
end;

procedure TDBConnection.ReleaseADOConnetion(var AValue: TADOConnection);
begin
  FLock.Enter;
  try
    if Assigned(AValue) then
    begin
      AValue.Connected := False;
      FADOConnectPool.ReleaseConnection(AValue);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TDBConnection.SetConConfig(const AServer, ADBName, AUsername,
  APassword: string; ADBAuthentication: TDBAuthentication; APort: Integer);
begin
  FServer := AServer;
  FDBAuthentication := ADBAuthentication;
  FDBName := ADBName;
  FUserName := AUserName;
  FPassword := APassword;
  FPort := APort;
  if FDBAuthentication = daWindows then
  begin
    if FPort > 0 then
    begin
      FADOConnectPool.ConnectionString := Format('Provider=SQLOLEDB.1;Integrated '
        + 'Security=SSPI;Persist Security Info=True;Initial Catalog=%s;Data Source=%s,%d',
        [FDBName, FServer, FPort]);
    end
    else
    begin
      FADOConnectPool.ConnectionString := Format('Provider=SQLOLEDB.1;Integrated '
        + 'Security=SSPI;Persist Security Info=True;Initial Catalog=%s;Data Source=%s',
        [FDBName, FServer]);
    end;
  end
  else
  begin
    if FPort > 0 then
    begin
      FADOConnectPool.ConnectionString := Format('Provider=SQLOLEDB.1;Password=%s;'
        + 'Persist Security Info=True;User ID=%s;Initial Catalog=%s;Data Source=%s,%d',
        [FPassword, FUserName, FDBName, FServer, FPort]);
    end
    else
    begin
      FADOConnectPool.ConnectionString := Format('Provider=SQLOLEDB.1;Password=%s;'
        + 'Auto Translate=True;Persist Security Info=True;User ID=%s;Initial Catalog=%s;'
        + 'Data Source=%s', [FPassword, FUserName, FDBName, FServer]);
    end;
  end;
end;

function TDBConnection.SQLExce(var AQry: TADOQuery; const ASql: string): Integer;
begin
  AQry.Close;
  AQry.SQL.Text := ASql;
  Result := AQry.ExecSQL;
end;

procedure TDBConnection.SQLOpen(var AQry: TADOQuery; const ASql: string);
begin
  AQry.Close;
  AQry.SQL.Text := ASql;
  AQry.Open;
end;

function TDBConnection.TestConnect: Boolean;
var
  AdoCon: TADOConnection;
begin
  AdoCon := TADOConnection.Create(nil);
  try
    AdoCon.ConnectionString := FADOConnectPool.ConnectionString;
    AdoCon.Connected := True;
    Result := True;
  finally
    AdoCon.Free;
  end;
end;

procedure TDBConnection.GetAllDBName(ANames: TStrings);
var
  adoCon: TADOConnection;
  adoReset: TADODataSet;
begin
  GetADOConnection(adoCon);
  adoReset := TADODataSet.Create(nil);
  ANames.BeginUpdate;
  try
    adoReset.Connection := adoCon;
    adoReset.CommandText := 'use master;Select name From sysdatabases';
    adoReset.CommandType := cmdText;
    adoReset.Open;

    ANames.Clear;
    while not adoReset.Eof do
    begin
      ANames.Add(adoReset.FieldByName('name').AsString);
      adoReset.Next;
    end;
  finally
    ANames.EndUpdate;
    ReleaseADOConnetion(adoCon);
    adoReset.Close;
    FreeAndNil(adoReset);
  end;
end;

procedure TDBConnection.GetServerList(ANames: TStrings);
var
  SQLServer: Variant;
  ServerList: Variant;
  i, iCount: Integer;
begin
  ANames.Clear;
  SQLServer := CreateOleObject('SQLDMO.Application');
  ServerList := SQLServer.ListAvailableSQLServers;
  try
    iCount := ServerList.Count;
    for i := 1 to iCount do
    begin
      ANames.Add(ServerList.Item(i));
    end;
  finally
    VarClear(SQLServer);
    VarClear(ServerList);
  end;
end;

end.
