unit ADOConPool;

interface

uses
  Windows, Messages, SysUtils, Classes, ADODB, SyncObjs, ActiveX, DateUtils;

type
  TADOConRec = record
    AdoCon: TADOConnection;
    Idle: Boolean;
    ReleaseDT: TDateTime;
  end;
  PADOConRec = ^TADOConRec;

  TMonitorThread = class;
  TADOConPool = class
  private
    {* 连接队列 *}
    FADOConList: TList;
    {* 获取的索引 *}
    FCurrIndex: Integer;
    {* 线程锁 *}
    FLock: TCriticalSection;
    {* 连接字符串 *}
    FConnectionString: string;
    {* 监视对象 *}
    FMonitorThread: TMonitorThread;
    procedure Connect(AdoCon: TADOConnection);
    {* 检测连接是否存在，并重连 *}
    procedure CheckReConnect(AdoCon: TADOConnection);
    {* 清除列表 *}
    procedure Clear;
    {* 释放长时间没有使用的连接 *}
    procedure FreeIdleConnection;
    {* 设置连接串 *}
    procedure SetConnectionString(const AValue: string);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    {* 获取一个连接 *}
    procedure GetConnection(var AdoCon: TADOConnection);
    procedure ReleaseConnection(var AdoCon: TADOConnection);

    property ConnectionString: string read FConnectionString write SetConnectionString;
  end;

  TMonitorThread = class(TThread)
  private
    FADOConPool: TADOConPool;
  protected
    procedure Execute; override;
  end;

implementation

uses BasisFunction, Logger;

{ TADOConPool }

constructor TADOConPool.Create;
begin
  inherited Create;
  FADOConList := TList.Create;
  FCurrIndex := 0;
  FLock := TCriticalSection.Create;
  FMonitorThread := TMonitorThread.Create(True);
  FMonitorThread.FreeOnTerminate := False;
  FMonitorThread.FADOConPool := Self;
  FMonitorThread.Resume;
end;

destructor TADOConPool.Destroy;
begin
  FMonitorThread.Terminate;
  FMonitorThread.WaitFor;
  FMonitorThread.Free;
  FLock.Free;
  Clear;
  FADOConList.Free;
  inherited;
end;

procedure TADOConPool.Connect(AdoCon: TADOConnection);
begin
  if AdoCon.Connected then
    AdoCon.Connected := False;
  AdoCon.ConnectionString := FConnectionString;
  AdoCon.Connected := True;
end;

procedure TADOConPool.CheckReConnect(AdoCon: TADOConnection);
var
  Qry: TADOQuery;
begin
  try
    Qry := TADOQuery.Create(nil);
    try
      Qry.Connection := AdoCon;
      Qry.Close;
      Qry.SQL.Text := 'SELECT 1';
      Qry.Open;
    finally
      Qry.Free;
    end;
  except
    on E: Exception do
    begin
      Connect(AdoCon);
    end;
  end;
end;

procedure TADOConPool.GetConnection(var AdoCon: TADOConnection);
var
  i: Integer;
  ADOConRec: PADOConRec;
begin
  FLock.Enter;
  try
    if FCurrIndex >= FADOConList.Count then
      FCurrIndex := FADOConList.Count - 1;
    if FCurrIndex < 0 then
      FCurrIndex := 0;
    ADOConRec := nil;
    for i := FCurrIndex to FADOConList.Count - 1 do //从当前位置查找
    begin
      if PADOConRec(FADOConList[i]).Idle then
      begin
        ADOConRec := FADOConList[i];
        FCurrIndex := i;
        Break;
      end;
    end;
    if ADOConRec = nil then
    begin
      for i := 0 to FCurrIndex - 1 do  //从头查找到当前位置
      begin
        if PADOConRec(FADOConList[i]).Idle then
        begin
          ADOConRec := FADOConList[i];
          FCurrIndex := i;
          Break;
        end;
      end;
    end;
    if ADOConRec <> nil then //找到了
    begin
      ADOConRec.Idle := False;
      AdoCon := ADOConRec.AdoCon;
      CheckReConnect(AdoCon);
    end
    else
    begin //否则，重新生成连接
      CoInitialize(nil);
      try
        New(ADOConRec);
        ADOConRec.AdoCon := TADOConnection.Create(nil);
        ADOConRec.AdoCon.LoginPrompt := False;
        ADOConRec.AdoCon.CommandTimeout := 120;
        ADOConRec.Idle := False;
        FCurrIndex := FADOConList.Add(ADOConRec);
        AdoCon := ADOConRec.AdoCon;
        
        Connect(AdoCon);
      finally
        CoUninitialize;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TADOConPool.ReleaseConnection(var AdoCon: TADOConnection);
var
  i: Integer;
  AdoConRec: PADOConRec;
begin
  FLock.Enter;
  try
    if FCurrIndex >= FADOConList.Count then
      FCurrIndex := FADOConList.Count - 1;
    if FCurrIndex < 0 then
      FCurrIndex := 0;
    AdoConRec := nil;
    for i := FCurrIndex downto 0 do //从当前位置往下查找
    begin
      AdoConRec := FADOConList[i];
      if not Assigned(FADOConList[i]) then Continue;   //此处FADOConList[i]可能为空
      if AdoConRec.AdoCon = AdoCon then
      begin
        AdoConRec.Idle := True;
        AdoConRec.ReleaseDT := GMTNow;
        FCurrIndex := i;
        Exit;
      end;
    end;
    for i := FCurrIndex + 1 to FADOConList.Count - 1 do
    begin
      AdoConRec := FADOConList[i];
      if not Assigned(FADOConList[i]) then Continue;   //此处FADOConList[i]可能为空
      if AdoConRec.AdoCon = AdoCon then
      begin
        AdoConRec.Idle := True;
        AdoConRec.ReleaseDT := GMTNow;
        FCurrIndex := i;
        Exit;
      end;
    end; 
  finally
    FLock.Leave;
  end;
end;

procedure TADOConPool.Clear;
var
  i: Integer;
  AdoConRec: PADOConRec;
begin
  for i := 0 to FADOConList.Count - 1 do
  begin
    AdoConRec := FADOConList.Items[i];
    FreeAndNilEx(AdoConRec.AdoCon);
    Dispose(AdoConRec);
  end;
  FADOConList.Clear;
end;

procedure TADOConPool.FreeIdleConnection;
var
  i: Integer;
  AdoConRec: PADOConRec;
begin
  FLock.Enter;
  try
    for i := FADOConList.Count - 1 downto 0  do
    begin
      AdoConRec := FADOConList[i];
      if AdoConRec.Idle then
      begin
        if MinutesBetween(GMTNow, AdoConRec.ReleaseDT) >= 10 then //超过10分钟没有使用的连接，释放
        begin
          try
            try
              FreeAndNilEx(AdoConRec.AdoCon);
              Dispose(AdoConRec);
            except
              on E: Exception do
              begin
                WriteLogMsg(ltError, Format('Error at TADOConPool.FreeIdleConnection, Current Index: %d, Total Count: %d, Message: %s',
                  [i, FADOConList.Count, E.Message]));
              end;
            end;
          finally
            //如果释放AdoConRec对象出错，导致不执行FADOConList.Delete(i)，容器还存在该异常对象的
            //索引，下次访问就会出错。此处可确保容器中删除索引，不影响其他地方正常访问数据库。
            FADOConList.Delete(i);
          end;
          //复位
          FCurrIndex := 0;
        end;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TADOConPool.SetConnectionString(const AValue: string);
var
  i: Integer;
  AdoConRec: PADOConRec;
begin
  for i := 0 to FADOConList.Count - 1 do
  begin
    AdoConRec := FADOConList.Items[i];
    if AdoConRec.AdoCon.Connected then
      AdoConRec.AdoCon.Connected := False;
    AdoConRec.AdoCon.ConnectionString := AValue;
  end;
  FConnectionString := AValue;
end;

{ TMonitorThread }

procedure TMonitorThread.Execute;
var
  i: Integer;
begin
  inherited;
  while not Terminated do
  begin
    for i := 0 to 5 * 60 * 10 do //5分钟检测一次
    begin
      if Terminated then Exit;
      Sleep(100);
    end;
    try
      FADOConPool.FreeIdleConnection;
    except
      ;
    end;
  end;
end;

end.

