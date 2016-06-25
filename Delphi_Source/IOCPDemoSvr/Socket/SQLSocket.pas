unit SQLSocket;

interface

uses
  SysUtils, Classes, IOCPSocket, ADODB, DB, Windows, DefineUnit, BaseSocket;

type
  {* SQL查询SOCKET基类 *}
  TSQLSocket = class(TBaseSocket)
  private
    {* 开始事务创建TADOConnection，关闭事务时释放 *}
    FBeginTrans: Boolean;
    FADOConn: TADOConnection;
  protected
    {* 处理数据接口 *}
    procedure Execute(AData: PByte; const ALen: Cardinal); override;
    {* 返回SQL语句执行结果 *}
    procedure DoCmdSQLOpen;
    {* 执行SQL语句 *}
    procedure DoCmdSQLExec;
    {* 开始事务 *}
    procedure DoCmdBeginTrans;
    {* 提交事务 *}
    procedure DoCmdCommitTrans;
    {* 回滚事务 *}
    procedure DoCmdRollbackTrans;
  public
    procedure DoCreate; override;
    destructor Destroy; override;
    {* 获取SQL语句 *}
    function GetSQL: string;
    property BeginTrans: Boolean read FBeginTrans;
  end;

implementation

uses Logger, DBConnect, BasisFunction;

{ TSQLSocket }

destructor TSQLSocket.Destroy;
begin
  if FBeginTrans then //如果开始了事务，则回滚
  begin
    WriteLogMsg(ltError, Format('[%s] trans time out, rollback', [FUserName]));
    FADOConn.RollbackTrans;
  end;
  FreeAndNilEx(FSendStream);
  inherited;
end;

procedure TSQLSocket.DoCreate;
begin
  inherited;
  LenType := ltCardinal;
  FSocketFlag := sfSQL;
end;

procedure TSQLSocket.Execute(AData: PByte; const ALen: Cardinal);
var
  sErr: string;
  SQLCmd: TSQLCmd;
begin
  inherited;
  FRequest.Clear;
  FResponse.Clear;
  try
    AddResponseHeader;
    if ALen = 0 then
    begin
      DoFailure(CIPackLenError);
      DoSendResult(True);
      Exit;
    end;
    if DecodePacket(AData, ALen) then
    begin
      FResponse.Clear;
      AddResponseHeader;
      SQLCmd := StrToSQLCommand(Command);
      if (not (SQLCmd in [scLogin, scActive])) and (not FLogined) then
      begin //必须先登陆，才能发起业务
        DoFailure(CINotLogin);
        DoSendResult(True);
        Exit;
      end;
      case SQLCmd of
        scLogin:
        begin
          DoCmdLogin;
          DoSendResult(True);
        end;
        scActive:
        begin
          DoSuccess;
          DoSendResult(True);
        end;
        scSQLOpen:
        begin
          DoCmdSQLOpen;
        end;
        scSQLExec:
        begin
          DoCmdSQLExec;
          DoSendResult(True);
        end;
        scBeginTrans:
        begin
          DoCmdBeginTrans;
          DoSendResult(True);
        end;
        scCommitTrans:
        begin
          DoCmdCommitTrans;
          DoSendResult(True);
        end;
        scRollbackTrans:
        begin
          DoCmdRollbackTrans;
          DoSendResult(True);
        end;
      else
        DoFailure(CINoExistCommand, 'Unknow Command');
        DoSendResult(True);
      end;
    end
    else
    begin
      DoFailure(CIPackFormatError, 'Packet Must Include \r\n\r\n');
      DoSendResult(True);
    end;
  except
    on E: Exception do //发生未知错误，断开连接
    begin
      sErr := RemoteAddress + ':' + IntToStr(RemotePort) + CSComma + 'Unknow Error: ' + E.Message;
      WriteLogMsg(ltError, sErr);
      Disconnect;
    end;
  end;
end;

procedure TSQLSocket.DoCmdSQLOpen;
var
  ADOConn: TADOConnection;
  Qry: TADOQuery;
  sFileName: string;
begin
  try
    GDBConnect.GetADOConnection(ADOConn);
    Qry := TADOQuery.Create(nil);
    try
      Qry.Connection := ADOConn;
      GDBConnect.SQLOpen(Qry, GetSQL); //如果分析通过，则查询
      sFileName := GetTmpFileEx(ExtractFilePath(GetModuleName(HInstance)), 'SQLOpen', '.xml');
      WriteLogMsg(ltInfo, 'SQLOpen FileName: ' + sFileName);
      Qry.SaveToFile(sFileName, pfXML);
      DoSuccess; //下发成功
      OpenWriteBuffer;
      DoSendResult(False);
      SendFile(sFileName, 0, 1024 * 1024, True, False); //下发查询结果文件
      FlushWriteBuffer(ioStream);
    finally
      Qry.Free;
      GDBConnect.ReleaseADOConnetion(ADOConn);
    end;
  except
    on E: Exception do
    begin
      DoFailure(CISQLOpenError);
      FResponse.Add(Format(CSFmtString, [CSMessage, E.Message]));
      DoSendResult(True);
    end;
  end;
end;

procedure TSQLSocket.DoCmdSQLExec;
var
  ADOConn: TADOConnection;
  Qry: TADOQuery;
  iEffectRow: Integer;
begin
  if not FBeginTrans then
    GDBConnect.GetADOConnection(ADOConn);
  try
    Qry := TADOQuery.Create(nil);
    if not FBeginTrans then
      Qry.Connection := ADOConn
    else
      Qry.Connection := FADOConn;
    try
      iEffectRow := GDBConnect.SQLExce(Qry, GetSQL); 
      DoSuccess;
      FResponse.Add(Format(CSFmtString, [CSEffectRow, IntToStr(iEffectRow)])); //下发影响行数
    except
      on E: Exception do
      begin
        DoFailure(CISQLExecError);
        FResponse.Add(Format(CSFmtString, [CSMessage, E.Message]));
      end;
    end;
  finally
    if not FBeginTrans then
      GDBConnect.ReleaseADOConnetion(ADOConn);
  end;
end;

procedure TSQLSocket.DoCmdBeginTrans;
begin
  if FBeginTrans then //已经开始事务则不能再开始事务
  begin
    DoFailure(CIHavedBeginTrans);
    Exit;
  end;
  try
    GDBConnect.GetADOConnection(FADOConn);
    FADOConn.BeginTrans;
    FBeginTrans := True;
    DoSuccess;
  except
    on E: Exception do
    begin
      DoFailure(CIBeginTransError);
      FResponse.Add(Format(CSFmtString, [CSMessage, E.Message]));
    end;
  end;
end;

procedure TSQLSocket.DoCmdCommitTrans;
begin
  if not FBeginTrans then //如果没有开始事务，则不能提交
  begin
    DoFailure(CINotExistTrans);
    Exit;
  end;
  try
    FADOConn.CommitTrans;
    GDBConnect.ReleaseADOConnetion(FADOConn);
    FADOConn := nil;
    FBeginTrans := False;
    DoSuccess;
  except
    on E: Exception do
    begin
      DoFailure(CICommitTransError);
      FResponse.Add(Format(CSFmtString, [CSMessage, E.Message]));
    end;
  end;
end;

procedure TSQLSocket.DoCmdRollbackTrans;
begin
  if not FBeginTrans then //如果没有开始事务，则不能回滚
  begin
    DoFailure(CINotExistTrans);
    Exit;
  end;
  try
    FADOConn.RollbackTrans;
    GDBConnect.ReleaseADOConnetion(FADOConn);
    FADOConn := nil;
    FBeginTrans := False;
    DoSuccess;
  except
    on E: Exception do
    begin
      DoFailure(CIRollbackTransError);
      FResponse.Add(Format(CSFmtString, [CSMessage, E.Message]));
    end;
  end;
end;

function TSQLSocket.GetSQL: string;
var
  utfSQL: UTF8String;
begin
  SetLength(utfSQL, FRequestDataLen);
  CopyMemory(@utfSQL[1], FRequestData, FRequestDataLen); //读取命令
  Result := Utf8ToAnsi(utfSQL);
end;

end.
