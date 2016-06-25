unit ControlSocket;

interface

uses
  SysUtils, Classes, IOCPSocket, ADODB, DB, Windows, DefineUnit, BaseSocket;

type
  TControlSocket = class(TBaseSocket)
  protected
    {* 处理数据接口 *}
    procedure Execute(AData: PByte; const ALen: Cardinal); override;
    {* 获取客户端列表 *}
    procedure DoCmdGetClients;
  public
    procedure DoCreate; override;
    destructor Destroy; override;
  end;

implementation

uses Logger;

{ TControlSocket }

procedure TControlSocket.DoCreate;
begin
  inherited;
  LenType := ltCardinal;
  FSocketFlag := sfControl;
end;

destructor TControlSocket.Destroy;
begin
  inherited;
end;

procedure TControlSocket.Execute(AData: PByte; const ALen: Cardinal);
var
  sErr: string;
  ControlCmd: TControlCmd;
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
      ControlCmd := StrToControlCommand(Command);
      if (not (ControlCmd in [ccLogin, ccActive])) and (not FLogined) then
      begin //必须先登陆，才能发起业务
        DoFailure(CINotLogin);
        DoSendResult(True);
        Exit;
      end;
      case ControlCmd of
        ccLogin:
        begin
          DoCmdLogin;
          DoSendResult(True);
        end;
        ccActive:
        begin
          DoSuccess;
          DoSendResult(True);
        end;
        ccGetClients:
        begin
          DoCmdGetClients;
          DoSendResult(True);
        end;
      else
        DoFailure(CINoExistCommand, 'Unknow Command');
        DoSendResult(True);
      end;
    end
    else
    begin
      DoFailure(CIPackFormatError, 'Decode Packet Error');
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

procedure TControlSocket.DoCmdGetClients;
var
  i: Integer;
  slItem: TStringList;
  BaseSocket: TBaseSocket;
begin
  slItem := TStringList.Create;
  try
    IocpServer.SocketHandles.Lock;
    try
      for i := IocpServer.SocketHandles.Count - 1 downto 0 do
      begin
        BaseSocket := IocpServer.SocketHandles[i].SocketHandle as TBaseSocket;
        slItem.Add(Format('Item= %s'#9'%s'#9'%s'#9'%s'#9'%s'#9'%s',
          [BaseSocket.LocalAddress, BaseSocket.RemoteAddress,
          GetSocketFlagStr(BaseSocket.SocketFlag), BaseSocket.UserName,
          FormatDateTime('YYYY-MM-DD HH:NN:SS.ZZZ', BaseSocket.ConnectTime),
          FormatDateTime('YYYY-MM-DD HH:NN:SS.ZZZ', BaseSocket.ActiveTime)]));
      end;
    finally
      IocpServer.SocketHandles.UnLock;
    end;
    DoSuccess;
    FResponse.AddStrings(slItem);
  finally
    slItem.Free;
  end;
end;

end.
