unit IOCPSocket;
{* |<PRE>
================================================================================
* 软件名称：TaxSvr － IOCPSocket.pas
* 单元名称：IOCPSocket.pas
* 单元作者：SQLDebug_Fan <fansheng_hx@163.com>  
* 备    注：-完成端口封装类 
*           -封装完成端口要注意内存申请，一定要遵循的原则是本线程申请本线程释放
*           -否则会出现一些异常，DELPHI自带的内存管理器检测不出来，但是一些三方
*           -的内存管理器可以检测出来，如FastMM，因此要慎用线程的FreeOnTerminate
* 开发平台：Windows XP + Delphi 7
* 兼容测试：Windows XP, Delphi 7
* 本 地 化：该单元中的字符串均符合本地化处理方式
--------------------------------------------------------------------------------
* 更新记de 录：-
*           - 
================================================================================
|</PRE>}
interface

uses
  Windows, SysUtils, Classes, Messages, SyncObjs, JwaWinsock2, ActiveX,
  DateUtils;

const
  {* 接收数据的缓冲区大小，如果接收到的数据超过大小，会分成几个包接收 *}
  MAX_IOCPBUFSIZE = 4096;
  {* IOCP退出标志 *}
  SHUTDOWN_FLAG = $FFFFFFFF;
  {* 回车换行 *}
  LF = #10;
  CR = #13;
  EOL = CR + LF;
  {* 最大空闲锁个数 *}
  MAX_IDLELOCK = 50;

type
  {* 完成端口操作定义 *}
  TIocpOperate = (ioNone, ioRead, ioWrite, ioStream, ioExit);
  PIocpRecord = ^TIocpRecord;
  TIocpRecord = record
    Overlapped: TOverlapped;   //完成端口重叠结构
    WsaBuf: TWsaBuf;           //完成端口的缓冲区定义
    IocpOperate: TIOCPOperate; //当前操作类型
  end;
  {* TCP心跳包结构体 *}
  TTCPKeepAlive = packed record
    OnOff: Cardinal;
    KeepAliveTime: Cardinal;
    KeepAliveInterval: Cardinal;
  end;

  EObjectList = class(Exception);
  {* 线程安全，检查类型的列表，获取列表需要先Lock，获取之后UnLock，查找函数自带锁 *}
  TObjectList = class(TList) { TObjectList, Lock}
  private
    FLock: TCriticalSection;
    FClassType: TClass;
    FData: Pointer;
    FName: string;
    FTag: integer;
    function GetItems(Index: Integer): TObject;
    procedure SetItems(Index: Integer; const Value: TObject);
  protected
    procedure ClassTypeError(Message: string);
  public
    procedure Lock;
    procedure UnLock;
    function Expand: TObjectList;
    function Add(AObject: TObject): Integer;
    function IndexOf(AObject: TObject): Integer; overload;
    procedure Delete(Index: Integer); overload;
    procedure Clear; override;
    function Remove(AObject: TObject): Integer;
    procedure Insert(Index: Integer; Item: TObject);
    function First: TObject;
    function Last: TObject;
    property ItemClassType: TClass read FClassType;
    property Items[Index: Integer]: TObject read GetItems write SetItems; default;

    constructor Create; overload;
    constructor Create(AClassType: TClass); overload;
    destructor Destroy; override;
    property Data: Pointer read FData write FData;
  published
    property Tag: integer read FTag write FTag;
    property Name: string read FName write FName;
  end;

  ESocketError = class(Exception);
  EIocpError = class(Exception);
  TIocpServer = class;

  {* 发送所申请的重叠端口缓冲 *}
  TSendOverlapped = class
  private
    FList: TList;
    FLock: TCriticalSection;
    procedure Clear;
  public
    constructor Create;
    destructor Destroy; override;
    {* 申请一个 *}
    function Allocate(ALen: Cardinal): PIocpRecord;
    {* 释放一个 *}
    procedure Release(AValue: PIocpRecord);
  end;
  
  {* 长度类型，Word类型还是Cardinal类型 *}
  TLenType = (ltNull, ltWord, ltCardinal);
  {* 客户端对应Socket对象 *}
  TSocketHandle = class
  private
    {* 对等SOCKET对象 *}
    FSocket: TSocket;
    FIocpServer: TIocpServer;
    {* 连接 *}
    FConnected: Boolean;
    {* 远程属性 *}
    FRemoteAddress: string;
    FRemotePort: Word; 
    {* 本地属性 *}
    FLocalAddress: string;
    FLocalPort: Word;
    {* 保存投递请求的地址信息 *}
    FIocpRecv: PIocpRecord;
    {* 发送IOCP结构体缓冲 *}
    FSendOverlapped: TSendOverlapped;
    {* 接收到数据 *}
    FInputBuf: TMemoryStream;
    {* 发送的数据 *}
    FOutputBuf: TMemoryStream;
    {* 长度类型 *}
    FLenType: TLenType;
    {* 包的长度 *}
    FPacketLen: Integer;
    {* 锁和对象分离，锁由外部负责 *}
    FLock: TCriticalSection;
    {* 超时，0表示没有超时 *}
    FTimeOutMS: Cardinal;
    {* 上次激活时间，激活是指收到数据 *}
    FActiveTime: TDateTime;
    {* 连接时间 *}
    FConnectTime: TDateTime;
    {* 标识是否正在处理中 *}
    FExecuting: Boolean;
  protected
    {* 获取SOCKET远程属性 *}
    function GetRemoteAddress: string;
    function GetRemotePort: Word;
    procedure GetRemoteInfo;
    {* 获取SOCKET本地属性 *}
    function GetLocalAddress: string;
    function GetLocalPort: Word;
    procedure GetLocalInfo;
    {* 处理接收到的数据，每个数据包的格式是先发长度，然后发数据，可以避免粘包 *}
    procedure ReceiveData(AData: PAnsiChar; const ALen: Cardinal);
    {* 处理接收的数据 *}
    procedure Process;
    {* 子类处理接收数据接口 *}
    procedure Execute(AData: PByte; const ALen: Cardinal); virtual;
    {* 设置超时 *}
    procedure SetTimeOut(const ATimeOutMS: Cardinal);
    {* 处理网络返回的异常 *}
    procedure ProcessNetError(const AErrorCode: Integer);
    {* 发送流的回调函数，子类如果需要发送流，必须重载这个函数 *}
    procedure WriteStream(const AWriteNow: Boolean = True); overload; virtual;
  public
    constructor Create(const AIocpServer: TIocpServer; const ASocket: TSocket);
    procedure DoCreate; virtual;
    destructor Destroy; override;
    {* 断开连接 *}
    procedure Disconnect;
    {* 投递接收请求 *}
    procedure PreRecv;
    {* 处理IO完成端口请求 *}
    procedure ProcessIOComplete(AIocpRecord: PIocpRecord; const ACount: Cardinal);
    {* 读取函数 *}
    procedure ReadWord(AData: PAnsiChar; var AWord: Word; const AConvert: Boolean = True);
    procedure ReadCardinal(AData: PAnsiChar; var ACardinal: Cardinal; const AConvert: Boolean = True);
    {* 发送函数 *}
    procedure OpenWriteBuffer;
    procedure FlushWriteBuffer(const AIocpOperate: TIocpOperate);
    procedure WriteBuffer(const ABuffer; const ACount: Integer);
    procedure WriteWord(AValue: Word; const AConvert: Boolean = True); 
    procedure WriteCardinal(AValue: Cardinal; const AConvert: Boolean = True); 
    procedure WriteInteger(AValue: Integer; const AConvert: Boolean = True);
    procedure WriteSmallInt(AValue: SmallInt; const AConvert: Boolean = True); 
    procedure WriteString(const AValue: string);
    procedure WriteLn(const AValue: string);
    {* 锁 *}
    procedure Lock;
    procedure UnLock;
    {* 属性 *}
    property Socket: TSocket read FSocket;
    property RemoteAddress: string read GetRemoteAddress;
    property RemotePort: Word read GetRemotePort;
    property LocalAddress: string read GetLocalAddress;
    property LocalPort: Word read GetLocalPort;
    property LenType: TLenType read FLenType write FLenType;
    property TimeOutMS: Cardinal read FTimeOutMS write SetTimeOut;
    property Connected: Boolean read FConnected;
    property ActiveTime: TDateTime read FActiveTime;
    property ConnectTime: TDateTime read FConnectTime;
    property IocpServer: TIocpServer read FIocpServer;
    property Executing: Boolean read FExecuting;
  end;

  {* 客户端对象和锁 *}
  TClientSocket = record
    Lock: TCriticalSection;
    SocketHandle: TSocketHandle;
    IocpRecv: TIocpRecord; //投递请求结构体
    IdleDT: TDateTime;
  end;
  PClientSocket = ^TClientSocket;
  
  {* 客户端对应Socket管理对象 *}
  TSocketHandles = class(TObject)
  private
    {* 正在使用列表管理对象 *}
    FList: TList;
    {* 不再使用列表管理对象 *}
    FIdleList: TList;
    {* 锁 *}
    FLock: TCriticalSection;
    {* 获取某一个 *}
    function GetItems(const AIndex: Integer): PClientSocket;
    {* 获取总个数 *}
    function GetCount: Integer;
    {* 清除 *}
    procedure Clear;
    {* 获取空闲连接个数 *}
    function GetIdleCount: Integer;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    {* 加锁 *}
    procedure Lock;
    {* 解锁 *}
    procedure UnLock;
    {* 添加一个对象 *}
    function Add(ASocketHandle: TSocketHandle): Integer;
    {* 删除 *}
    procedure Delete(const AIndex: Integer); overload;
    procedure Delete(ASocketHandle: TSocketHandle); overload;
    property Items[const AIndex: Integer]: PClientSocket read GetItems; default;
    property Count: Integer read GetCount;
    property IdleCount: Integer read GetIdleCount;
  end;

  TAcceptThread = class;
  TWorkThreads = class;
  TIocpThreadPool = class;

  TOnConnect = procedure(const ASocket: TSocket; var AAllowConnect: Boolean;
    var SocketHandle: TSocketHandle) of object;
  TOnError = procedure(const AName: string; const AError: string) of object;
  TOnDisconnect = procedure(const ASocketHandle: TSocketHandle) of object;
  {* IOCP处理中心 *}
  TIocpServer = class(TComponent)
  private
    {* 端口 *}
    FPort: Word;                          
    {* 套接字 *}
    FSocket: TSocket;                      
    {* 完成端口句柄 *}
    FIocpHandle: THandle;                  
    {* 客户端对象 *}
    FSocketHandles: TSocketHandles;
    {* 工作线程 *}      
    FWorkThreads: TWorkThreads;
    {* 接收线程 *}
    FAcceptThread: TAcceptThread;
    {* 是否已经启动 *}
    FActive: Boolean;
    {* 连接事件 *}
    FOnConnect: TOnConnect;
    {* 错误事件 *}
    FOnError: TOnError;
    {* 断开事件 *}
    FOnDisconnect: TOnDisconnect;
    {* 接收客户端连接的线程池 *}
    FAcceptThreadPool: TIocpThreadPool;
    {* 连接时间 *}
    FConnectTime: TDateTime;
    {* 最大工作线程和最少工作线程 *}
    FMaxWorkThrCount, FMinWorkThrCount: Integer;
    {* 最大接受连接线程和最小接受连接线程 *}
    FMaxCheckThrCount, FMinCheckThrCount: Integer;
  protected
    procedure Open;
    procedure Close;
    procedure SetActive(const AValue: Boolean);
    {* 链接时触发的事件 *}
    function DoConnect(const ASocket: TSocket; var SocketHandle: TSocketHandle): Boolean;
    {* 发生错误触发的事件 *}
    procedure DoError(const AName, AError: string);
    {* 断开连接触发的事件 *}
    procedure DoDisconnect(const ASocketHandle: TSocketHandle);
    {* 断开某个连接，触发断开事件 *}
    procedure FreeSocketHandle(const ASocketHandle: TSocketHandle); overload;
    procedure FreeSocketHandle(const AIndex: Integer); overload;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    {* 接受客户端请求，供接收线程TAcceptThread调用 *}
    procedure AcceptClient;
    {* 判断接收的客户端是否合法 *}
    procedure CheckClient(const ASocket: TSocket);
    {* 处理客户端操作，供处理线程TWorkThread调用 *}
    function WorkClient: Boolean;
    {* 传入Socket句柄，接收一个字符，超时返回False *}
    function ReadChar(const ASocket: TSocket; var AChar: Char; const ATimeOutMS: Integer): Boolean;
    {* 判断指定时间内Socket是否有数据传上来 *}
    function CheckTimeOut(const ASocket: TSocket; const ATimeOutMS: Integer): Boolean;
    {* 检测死链接 *}
    procedure CheckDisconnectedClient;
    property ConnectTime: TDateTime read FConnectTime;
    property SocketHandles: TSocketHandles read FSocketHandles;
  published
    property Active: Boolean read FActive write SetActive;
    property Port: Word read FPort write FPort;
    property OnConnect: TOnConnect read FOnConnect write FOnConnect;
    property OnError: TOnError read FOnError write FOnError;
    property OnDisconnect: TOnDisconnect read FOnDisconnect write FOnDisconnect;
    property MaxWorkThrCount: Integer read FMaxWorkThrCount write FMaxWorkThrCount;
    property MinWorkThrCount: Integer read FMinWorkThrCount write FMinWorkThrCount;
    property MaxCheckThrCount: Integer read FMaxCheckThrCount write FMaxCheckThrCount;
    property MinCheckThrCount: Integer read FMinCheckThrCount write FMinCheckThrCount;
  end;

  TIocpThread = class(TThread)
  private
    FIocpServer: TIocpServer;
  public
    constructor Create(const AServer: TIocpServer; CreateSuspended: Boolean); reintroduce;
  end;

  TAcceptThread = class(TIocpThread)
  protected
    procedure Execute; override;
  end;

  TWorkThread = class(TIocpThread)
  protected
    procedure Execute; override;
  end;

  TWorkThreads = class(TObjectList)
  private
    function GetItems(AIndex: Integer): TWorkThread;
    procedure SetItems(AIndex: Integer; AValue: TWorkThread);
  public
    constructor Create;
    property Items[AIndex: Integer]: TWorkThread read GetItems write SetItems; default;
  end;
  
  TCheckThread = class(TIocpThread)
  private
    FIocpThreadPool: TIocpThreadPool;
  protected
    procedure Execute; override;
  public
    property IocpThreadPool: TIocpThreadPool read FIocpThreadPool write FIocpThreadPool;
  end;

  TCheckThreads = class(TObjectList)
  private
    function GetItems(AIndex: Integer): TCheckThread;
    procedure SetItems(AIndex: Integer; AValue: TCheckThread);
  public
    constructor Create;
    property Items[AIndex: Integer]: TCheckThread read GetItems write SetItems; default;
  end;

  {* 完成端口实现的线程池，主要用于接收客户端连接请求 *}
  TIocpThreadPool = class
  private
    {* 完成端口服务对象 *}
    FIocpServer: TIocpServer;
    {* 完成端口句柄 *}
    FIocpHandle: THandle;
    {* 线程数 *}                       
    FCheckThreads: TCheckThreads;
    FActive: Boolean;
  protected
    procedure Open;
    procedure Close;
    procedure SetActive(const AValue: Boolean);
  public
    constructor Create(const AServer: TIocpServer); reintroduce;
    destructor Destroy; override;
    {* 投递一个SOCKET接收请求 *}
    procedure PostSocket(const ASocket: TSocket);
    property Active: Boolean read FActive write SetActive;
  end;

function GetLastWsaErrorStr: string;
function GetLastErrorStr: string;
function GetCPUCount: Integer;
procedure Register;

resourcestring
  SErrClassType = 'Class type mismatch. Expect: %s , actual: %s';
  SErrOutBounds = 'Out of bounds,The value %d not between 0 and %d.';

implementation

uses TypInfo;

procedure Register;
begin
  RegisterComponents('Fan', [TIocpServer]);
end;

function GetLastWsaErrorStr: string;
begin
  Result := SysErrorMessage(WSAGetLastError);
end;

function GetLastErrorStr: string;
begin
  Result := SysErrorMessage(GetLastError);
end;

function GetCPUCount: Integer;
var
  SysInfo: TSystemInfo;
begin
  FillChar(SysInfo, SizeOf(SysInfo), 0);
  GetSystemInfo(SysInfo);
  Result := SysInfo.dwNumberOfProcessors;
end;

{ TObjectList }

function TObjectList.Add(AObject: TObject): Integer;
begin
  Result := -1;
  Lock;
  try
    if (AObject = nil) or (AObject is FClassType) then
      Result := inherited Add(AObject)
    else
      ClassTypeError(AObject.ClassName);
  finally
    UnLock;
  end;
end;

constructor TObjectList.Create;
begin
  Create(TObject);
end;

constructor TObjectList.Create(AClassType: TClass);
begin
  inherited Create;
  FLock := TCriticalSection.Create;;
  FClassType := AClassType;
end;

procedure TObjectList.Delete(Index: Integer);
begin
  Lock;
  try
    inherited Delete(Index);
  finally
    UnLock;
  end;
end;

procedure TObjectList.ClassTypeError(Message: string);
begin
  raise EObjectList.CreateFmt(SErrClassType, [FClassType.ClassName, Message]);
end;

function TObjectList.Expand: TObjectList;
begin
  Lock;
  try
    Result := (inherited Expand) as TObjectList;
  finally
    UnLock;
  end;
end;

function TObjectList.First: TObject;
begin
  Lock;
  try
    Result := TObject(inherited First);
  finally
    UnLock;
  end;
end;

function TObjectList.GetItems(Index: Integer): TObject;
begin
  Result := TObject(inherited Items[Index]);
end;

function TObjectList.IndexOf(AObject: TObject): Integer;
begin
  Lock;
  try
    Result := inherited IndexOf(AObject);
  finally
    UnLock;
  end;
end;

procedure TObjectList.Insert(Index: Integer; Item: TObject);
begin
  Lock;
  try
    if (Item = nil) or (Item is FClassType) then
      inherited Insert(Index, Pointer(Item))
    else
      ClassTypeError(Item.ClassName);
  finally
    UnLock;
  end;
end;

function TObjectList.Last: TObject;
begin
  Lock;
  try
    Result := TObject(inherited Last);
  finally
    UnLock;
  end;
end;

function TObjectList.Remove(AObject: TObject): Integer;
begin
  Lock;
  try
    Result := IndexOf(AObject);
    if Result >= 0 then Delete(Result);
  finally
    UnLock;
  end;
end;

procedure TObjectList.SetItems(Index: Integer; const Value: TObject);
begin
  if Value = nil then
    Exit
  else if Value is FClassType then
    inherited Items[Index] := Value
  else
    ClassTypeError(Value.ClassName);
end;

destructor TObjectList.Destroy;
begin                
  inherited Destroy;
  FLock.Free;
end;

procedure TObjectList.Lock;
begin
  FLock.Enter;
end;

procedure TObjectList.UnLock;
begin
  FLock.Leave;
end;

procedure TObjectList.Clear;
var
  i : Integer;
begin
  for i := 0 to Count - 1 do
  if Assigned(Items[i]) then
  begin
    Items[i] := nil;
  end;
  inherited;
end;

{ TSendOverlapped }

procedure TSendOverlapped.Clear;
var
  i: Integer;
begin
  FLock.Enter;
  try
    for i := 0 to FList.Count - 1 do
    begin
      FreeMemory(PIocpRecord(FList.Items[i]).WsaBuf.buf);
      PIocpRecord(FList.Items[i]).WsaBuf.buf := nil;
      Dispose(PIocpRecord(FList.Items[i]));
    end;
    FList.Clear;
  finally
    FLock.Leave;
  end;
end;

constructor TSendOverlapped.Create;
begin
  inherited Create;
  FList := TList.Create;
  FLock := TCriticalSection.Create;
end;

destructor TSendOverlapped.Destroy;
begin
  Clear;
  FList.Free;
  FLock.Free;
  inherited;
end;

function TSendOverlapped.Allocate(ALen: Cardinal): PIocpRecord;
begin
  FLock.Enter;
  try
    New(Result);
    Result.Overlapped.Internal := 0;
    Result.Overlapped.InternalHigh := 0;
    Result.Overlapped.Offset := 0;
    Result.Overlapped.OffsetHigh := 0;
    Result.Overlapped.hEvent := 0;
    Result.IocpOperate := ioNone;
    Result.WsaBuf.buf := GetMemory(ALen);
    Result.WsaBuf.len := ALen;
    FList.Add(Result);
  finally
    FLock.Leave;
  end;
end;

procedure TSendOverlapped.Release(AValue: PIocpRecord);
var
  i: Integer;
begin
  FLock.Enter;
  try
    for i := 0 to FList.Count - 1 do
    begin
      if Cardinal(AValue) = Cardinal(FList[i]) then
      begin
        FreeMemory(PIocpRecord(FList.Items[i]).WsaBuf.buf);
        PIocpRecord(FList.Items[i]).WsaBuf.buf := nil;
        Dispose(PIocpRecord(FList.Items[i]));
        FList.Delete(i);
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

{ TSocketHandle }

constructor TSocketHandle.Create(const AIocpServer: TIocpServer;
  const ASocket: TSocket);
begin
  inherited Create;
  FIocpServer := AIocpServer;
  FSocket := ASocket;
  FSendOverlapped := TSendOverlapped.Create;
  FInputBuf := TMemoryStream.Create;
  FConnected := True;
  FConnectTime := Now;
  FActiveTime := Now;
  DoCreate;
end;

procedure TSocketHandle.DoCreate;
begin

end;

destructor TSocketHandle.Destroy;
begin
  closesocket(FSocket);
  FSendOverlapped.Free;
  FInputBuf.Free;
  if Assigned(FOutputBuf) then
    FOutputBuf.Free;
  inherited;
end;

procedure TSocketHandle.Disconnect;
begin
  FConnected := False;
  closesocket(FSocket);
  //IocpRec := FSendOverlapped.Allocate(0);
  //IocpRec.IocpOperate := ioExit;
  //PostQueuedCompletionStatus(FIocpServer.FIocpHandle, 0, DWORD(Self), @IocpRec.Overlapped);
end;

function TSocketHandle.GetRemoteAddress: string;
begin
  GetRemoteInfo;
  Result := FRemoteAddress;
end;

function TSocketHandle.GetRemotePort: Word;
begin
  GetRemoteInfo;
  Result := FRemotePort;
end;

procedure TSocketHandle.GetRemoteInfo;
var
  SockAddrIn: TSockAddrIn;
  iSize: Integer;
begin
  if FRemoteAddress = '' then
  begin
    iSize := SizeOf(SockAddrIn);
    getpeername(FSocket, @SockAddrIn, iSize);
    FRemoteAddress := inet_ntoa(SockAddrIn.sin_addr);
    FRemotePort := ntohs(SockAddrIn.sin_port);
  end;
end;

function TSocketHandle.GetLocalAddress: string;
begin
  GetLocalInfo;
  Result := FLocalAddress;
end;

function TSocketHandle.GetLocalPort: Word;
begin
  GetLocalInfo;
  Result := FLocalPort;
end;

procedure TSocketHandle.GetLocalInfo;
var
  SockAddrIn: TSockAddrIn;
  iSize: Integer;
begin
  if FLocalAddress = '' then
  begin
    iSize := SizeOf(SockAddrIn);
    getsockname(FSocket, @SockAddrIn, iSize);
    FLocalAddress := inet_ntoa(SockAddrIn.sin_addr);
    FLocalPort := ntohs(SockAddrIn.sin_port);
  end;
end;

procedure TSocketHandle.PreRecv;
var
  iFlags, iTransfer: Cardinal;
  iErrCode: Integer;
begin
  FIocpRecv.Overlapped.Internal := 0;
  FIocpRecv.Overlapped.InternalHigh := 0;
  FIocpRecv.Overlapped.Offset := 0;
  FIocpRecv.Overlapped.OffsetHigh := 0;
  FIocpRecv.Overlapped.hEvent := 0;
  FIocpRecv.IocpOperate := ioRead;
  iFlags := 0;
  if WSARecv(FSocket, @FIocpRecv.WsaBuf, 1, iTransfer, iFlags, @FIocpRecv.Overlapped,
    nil) = SOCKET_ERROR then
  begin
    iErrCode := WSAGetLastError;
    if iErrCode = WSAECONNRESET then //客户端被关闭
      FConnected := False;
    if iErrCode <> ERROR_IO_PENDING then //不抛出异常，触发异常事件
    begin
      FIocpServer.DoError('WSARecv', GetLastWsaErrorStr);
      ProcessNetError(iErrCode);
    end;
  end;
end;

procedure TSocketHandle.ProcessIOComplete(AIocpRecord: PIocpRecord;
  const ACount: Cardinal);
begin
  FExecuting := True;
  try
    case AIocpRecord.IocpOperate of
      ioNone: Exit;
      ioRead: //收到数据
      begin
        FActiveTime := Now;
        ReceiveData(AIocpRecord.WsaBuf.buf, ACount);
        if FConnected then
          PreRecv; //投递请求
      end;
      ioWrite: //发送数据完成，需要释放AIocpRecord的指针
      begin
        FActiveTime := Now;
        FSendOverlapped.Release(AIocpRecord);
      end;
      ioStream:
      begin
        FActiveTime := Now;
        FSendOverlapped.Release(AIocpRecord);
        WriteStream; //继续发送流
      end;
    end;
  finally
    FExecuting := False;
  end;
end;

procedure TSocketHandle.ReceiveData(AData: PAnsiChar; const ALen: Cardinal);
begin
  FInputBuf.Write(AData^, ALen);
  Process;
end;

procedure TSocketHandle.Process;
var
  AData, ALast, NewBuf: PByte;
  iLenOffset, iOffset, iReserveLen: Integer;

  function ReadLen: Integer;
  var
    wLen: Word;
    cLen: Cardinal;
  begin
    FInputBuf.Position := iOffset;
    if FLenType = ltWord then
    begin
      FInputBuf.Read(wLen, SizeOf(wLen));
      //wLen := ntohs(wLen);
      Result := wLen;
    end
    else
    begin
      FInputBuf.Read(cLen, SizeOf(cLen));
      //cLen := ntohl(cLen);
      Result := cLen;
    end;
  end;
begin
  case FLenType of
    ltWord, ltCardinal:
    begin
      if FLenType = ltWord then
        iLenOffset := 2
      else
        iLenOffset := 4;
      iReserveLen := 0;
      FPacketLen := 0;
      iOffset := 0;
      if FPacketLen <= 0 then
      begin
        if FInputBuf.Size < iLenOffset then Exit;
        FInputBuf.Position := 0; //移动到最前面
        FPacketLen := ReadLen;
        iOffset := iLenOffset;
        iReserveLen := FInputBuf.Size - iOffset;
        if FPacketLen > iReserveLen then //不够一个包的长度
        begin
          FInputBuf.Position := FInputBuf.Size; //移动到最后，以便接收后续数据
          FPacketLen := 0;
          Exit;
        end;
      end;
      while (FPacketLen > 0) and (iReserveLen >= FPacketLen) do //如果数据够长，则处理
      begin
        AData := Pointer(Longint(FInputBuf.Memory) + iOffset); //取得当前的指针
        Execute(AData, FPacketLen);
        iOffset := iOffset + FPacketLen; //移到下一个点
        FPacketLen := 0;
        iReserveLen := FInputBuf.Size - iOffset;
        if iReserveLen > iLenOffset then //剩下的数据
        begin
          FPacketLen := ReadLen;
          iOffset := iOffset + iLenOffset;
          iReserveLen := FInputBuf.Size - iOffset;
          if FPacketLen > iReserveLen then //不够一个包的长度，需要把长度回退
          begin
            iOffset := iOffset - iLenOffset;
            iReserveLen := FInputBuf.Size - iOffset;
            FPacketLen := 0;
          end;
        end
        else //不够长度字节数
          FPacketLen := 0;
      end;
      if iReserveLen > 0 then //把剩下的自己缓存起来
      begin
        ALast := Pointer(Longint(FInputBuf.Memory) + iOffset);
        GetMem(NewBuf, iReserveLen);
        try
          CopyMemory(NewBuf, ALast, iReserveLen);
          FInputBuf.Clear;
          FInputBuf.Write(NewBuf^, iReserveLen);
        finally
          FreeMemory(NewBuf);
        end;
      end
      else
      begin
        FInputBuf.Clear;
      end;
    end;
  else
    begin
      FInputBuf.Position := 0;
      AData := Pointer(Longint(FInputBuf.Memory)); //取得当前的指针
      Execute(AData, FInputBuf.Size);
      FInputBuf.Clear;
    end;
  end;
end;

procedure TSocketHandle.Execute(AData: PByte; const ALen: Cardinal);
begin
end;

procedure TSocketHandle.ReadWord(AData: PAnsiChar; var AWord: Word;
  const AConvert: Boolean);
begin
  Move(AData^, AWord, SizeOf(AWord));
  if AConvert then
    AWord := ntohs(AWord);
end;

procedure TSocketHandle.ReadCardinal(AData: PAnsiChar; var ACardinal: Cardinal;
  const AConvert: Boolean);
begin
  Move(AData^, ACardinal, SizeOf(ACardinal));
  if AConvert then
    ACardinal := ntohl(ACardinal);
end;

procedure TSocketHandle.OpenWriteBuffer;
begin
  if Assigned(FOutputBuf) then
    FreeAndNil(FOutputBuf);
  FOutputBuf := TMemoryStream.Create;
end;

procedure TSocketHandle.FlushWriteBuffer(const AIocpOperate: TIocpOperate);
var
  IocpRec: PIocpRecord;
  iErrCode: Integer;
  dSend, dFlag: DWORD;
begin
  IocpRec := FSendOverlapped.Allocate(FOutputBuf.Size);
  IocpRec.Overlapped.Internal := 0;
  IocpRec.Overlapped.InternalHigh := 0;
  IocpRec.Overlapped.Offset := 0;
  IocpRec.Overlapped.OffsetHigh := 0;
  IocpRec.Overlapped.hEvent := 0;
  IocpRec.IocpOperate := AIocpOperate;
  System.Move(PAnsiChar(FOutputBuf.Memory)[0], IocpRec.WsaBuf.buf^, FOutputBuf.Size);
  dFlag := 0;
  if WSASend(FSocket, @IocpRec.WsaBuf, 1, dSend, dFlag, @IocpRec.Overlapped, nil) = SOCKET_ERROR then
  begin
    iErrCode := WSAGetLastError;
    if iErrCode <> ERROR_IO_PENDING then
    begin
      FIocpServer.DoError('WSASend', GetLastWsaErrorStr);
      ProcessNetError(iErrCode);
    end;
  end;
  FreeAndNil(FOutputBuf);
end;

procedure TSocketHandle.WriteBuffer(const ABuffer; const ACount: Integer);
begin
  FOutputBuf.WriteBuffer(ABuffer, ACount);
end;

procedure TSocketHandle.WriteWord(AValue: Word; const AConvert: Boolean = True);
begin
  if AConvert then
    AValue := htons(AValue);
  WriteBuffer(AValue, SizeOf(AValue));
end;

procedure TSocketHandle.WriteCardinal(AValue: Cardinal;
  const AConvert: Boolean);
begin
  if AConvert then
    AValue := htonl(AValue);
  WriteBuffer(AValue, SizeOf(AValue));
end;

procedure TSocketHandle.WriteInteger(AValue: Integer; const AConvert: Boolean);
begin
  WriteCardinal(Cardinal(AValue), AConvert);
end;

procedure TSocketHandle.WriteSmallInt(AValue: SmallInt; const AConvert: Boolean);
begin
  WriteWord(Word(AValue), AConvert);
end;

procedure TSocketHandle.WriteString(const AValue: string);
var
  iLen: Integer;
begin
  iLen := Length(AValue);
  if iLen > 0 then
    WriteBuffer(PChar(AValue)^, iLen);
end;

procedure TSocketHandle.WriteLn(const AValue: string);
begin
  WriteString(AValue + EOL);
end;

procedure TSocketHandle.WriteStream(const AWriteNow: Boolean);
begin
  //基类需要继承此函数
end;

procedure TSocketHandle.Lock;
begin
  FLock.Enter;
end;

procedure TSocketHandle.UnLock;
begin
  FLock.Leave;
end;

procedure TSocketHandle.SetTimeOut(const ATimeOutMS: Cardinal);
const
  SIO_KEEPALIVE_VALS = IOC_IN or IOC_VENDOR or 4; 
var
  InKeepAlive, OutKeepAlive: TTCPKeepAlive;
  Ret: Cardinal;
  Opt: BOOL;
begin
  //以下代码可以检测本机拔网线等异常情况，对方拔网线需要用轮循来检测
  FTimeOutMS := ATimeOutMS;
  if FTimeOutMS > 0 then
  begin
    InKeepAlive.OnOff := 1;
    InKeepAlive.KeepAliveTime := ATimeOutMS; //如果超时没有任何流量就断开
    InKeepAlive.KeepAliveInterval := 3000; //每隔多久发心跳包
  end
  else
  begin
    InKeepAlive.OnOff := 0;
  end;
  Opt := True;
  if setsockopt(FSocket, SOL_SOCKET, SO_KEEPALIVE, @Opt, SizeOf(Opt)) = SOCKET_ERROR then
  begin
    ESocketError.Create(GetLastWsaErrorStr);
  end;
  if WSAIoctl(FSocket, SIO_KEEPALIVE_VALS, @InKeepAlive, SizeOf(InKeepAlive),
    @OutKeepAlive, SizeOf(OutKeepAlive), @Ret, nil, nil) = SOCKET_ERROR then
  begin
    ESocketError.Create(GetLastWsaErrorStr);
  end;
end;

procedure TSocketHandle.ProcessNetError(const AErrorCode: Integer);
begin
  if AErrorCode = WSAECONNRESET then //客户端断开连接
    FConnected := False
  else if AErrorCode = WSAEDISCON then //客户端断开连接
    FConnected := False
  else if AErrorCode = WSAENETDOWN then //网络异常
    FConnected := False
  else if AErrorCode = WSAENETRESET then //心跳包拦截到的异常
    FConnected := False
  else if AErrorCode = WSAESHUTDOWN then //连接被关闭
    FConnected := False
  else if AErrorCode = WSAETIMEDOUT then //连接断掉或者网络异常
    FConnected := False;
end;

{ TSocketHandles }

constructor TSocketHandles.Create;
begin
  FList := TList.Create;
  FIdleList := TList.Create;
  FLock := TCriticalSection.Create;
end;

destructor TSocketHandles.Destroy;
begin
  Clear;
  FList.Free;
  FIdleList.Free;
  FLock.Free;
  inherited;
end;

function TSocketHandles.GetItems(const AIndex: Integer): PClientSocket;
begin
  Result := FList[AIndex];
end;

function TSocketHandles.GetCount: Integer;
begin
  Result := FList.Count;
end;

function TSocketHandles.GetIdleCount: Integer;
begin
  Result := FIdleList.Count;
end;

procedure TSocketHandles.Clear;
var
  i: Integer;
  ClientSocket: PClientSocket;
begin
  for i := 0 to Count - 1 do
  begin
    ClientSocket := Items[i];
    ClientSocket.Lock.Free;
    ClientSocket.SocketHandle.Free;
    FreeMemory(ClientSocket.IocpRecv.WsaBuf.buf);
    ClientSocket.IocpRecv.WsaBuf.buf := nil;
    Dispose(ClientSocket);
  end;
  FList.Clear;
  for i := 0 to FIdleList.Count - 1 do
  begin
    ClientSocket := FIdleList[i];
    ClientSocket.Lock.Free; //释放锁
    FreeMemory(ClientSocket.IocpRecv.WsaBuf.buf);
    ClientSocket.IocpRecv.WsaBuf.buf := nil;
    Dispose(ClientSocket);
  end;
  FIdleList.Clear;
end;

procedure TSocketHandles.Lock;
begin
  FLock.Enter;
end;

procedure TSocketHandles.UnLock;
begin
  FLock.Leave;
end;

function TSocketHandles.Add(ASocketHandle: TSocketHandle): Integer;
var
  ClientSocket, IdleClientSocket: PClientSocket;
  i: Integer;
begin
  ClientSocket := nil;
  for i := FIdleList.Count - 1 downto 0 do
  begin
    IdleClientSocket := FIdleList.Items[i];
    if Abs(MinutesBetween(Now, IdleClientSocket.IdleDT)) > 30 then
    begin
      ClientSocket := IdleClientSocket;
      FIdleList.Delete(i);
      Break;
    end;
  end;
  if not Assigned(ClientSocket) then
  begin
    New(ClientSocket);
    ClientSocket.Lock := TCriticalSection.Create;
    ClientSocket.IocpRecv.WsaBuf.buf := GetMemory(MAX_IOCPBUFSIZE);
    ClientSocket.IocpRecv.WsaBuf.len := MAX_IOCPBUFSIZE;
  end;
  ClientSocket.SocketHandle := ASocketHandle;
  ClientSocket.IdleDT := Now;
  ASocketHandle.FLock := ClientSocket.Lock;
  ASocketHandle.FIocpRecv := @ClientSocket.IocpRecv;
  Result := FList.Add(ClientSocket);
end;

procedure TSocketHandles.Delete(const AIndex: Integer);
var
  ClientSocket: PClientSocket;
begin
  ClientSocket := FList[AIndex];
  ClientSocket.Lock.Enter;
  try
    ClientSocket.SocketHandle.Free;
    ClientSocket.SocketHandle := nil;
  finally
    ClientSocket.Lock.Leave;
  end;
  FList.Delete(AIndex);
  ClientSocket.IdleDT := Now;
  FIdleList.Add(ClientSocket);
end;

procedure TSocketHandles.Delete(ASocketHandle: TSocketHandle);
var
  i, iIndex: Integer;
begin
  iIndex := -1;
  for i := 0 to Count - 1 do
  begin
    if Items[i].SocketHandle = ASocketHandle then
    begin
      iIndex := i;
      Break;
    end;
  end;
  if iIndex <> -1 then
  begin
    Delete(iIndex);
  end;
end;

{ TIocpServer }

constructor TIocpServer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FSocketHandles := TSocketHandles.Create;
  FWorkThreads := TWorkThreads.Create;
  FSocket := INVALID_SOCKET;
  FIocpHandle := 0;
  FMaxWorkThrCount := 160;
  FMinWorkThrCount := 120;
  FMaxCheckThrCount := 60;
  FMinCheckThrCount := 40;
  FAcceptThreadPool := TIocpThreadPool.Create(Self);
end;

destructor TIocpServer.Destroy;
begin
  if Active then
    Active := False;
  FWorkThreads.Free;
  FSocketHandles.Free;
  FAcceptThreadPool.Free;
  inherited;
end;

procedure TIocpServer.Open;
var
  WsaData: TWsaData;
  iNumberOfProcessors, i, iWorkThreadCount: Integer;
  WorkThread: TWorkThread;
  Addr: TSockAddr;
begin
  if WSAStartup($0202, WsaData) <> 0 then
    raise ESocketError.Create(GetLastWsaErrorStr);
  FIocpHandle := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
  if FIocpHandle = 0 then
    raise ESocketError.Create(GetLastErrorStr);
  FSocket := WSASocket(PF_INET, SOCK_STREAM, 0, nil, 0, WSA_FLAG_OVERLAPPED);
  if FSocket = INVALID_SOCKET then
    raise ESocketError.Create(GetLastWsaErrorStr);
  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(FPort);
  Addr.sin_addr.S_addr := htonl(INADDR_ANY); //在任何地址上监听，如果有多块网卡，会每块都监听
  if bind(FSocket, @Addr, SizeOf(Addr)) <> 0 then
    raise ESocketError.Create(GetLastWsaErrorStr);
  if listen(FSocket, MaxInt) <> 0 then 
     raise ESocketError.Create(GetLastWsaErrorStr);
  iNumberOfProcessors := GetCPUCount;
  iWorkThreadCount := iNumberOfProcessors * 2 + 4; //由于服务器处理可能比较费时间，因此线程设为CPU*2+4
  if iWorkThreadCount < FMinWorkThrCount then
    iWorkThreadCount := FMinWorkThrCount;
  if iWorkThreadCount > FMaxWorkThrCount then
    iWorkThreadCount := FMaxWorkThrCount;
  for i := 0 to iWorkThreadCount - 1 do 
  begin
    WorkThread := TWorkThread.Create(Self, True);
    FWorkThreads.Add(WorkThread);
    WorkThread.Resume;
  end;
  FAcceptThreadPool.Active := True;
  FAcceptThread := TAcceptThread.Create(Self, True);
  FAcceptThread.Resume;
end;

procedure TIocpServer.Close;
var
  i: Integer;
begin
  FAcceptThread.Terminate;
  closesocket(FSocket);
  FAcceptThread.Free;
  FAcceptThreadPool.Active := False;
  FSocket := INVALID_SOCKET;
  //退出执行线程
  for i := 0 to FWorkThreads.Count - 1 do
  begin
    FWorkThreads.Items[i].Terminate;
    PostQueuedCompletionStatus(FIocpHandle, 0, 0, Pointer(SHUTDOWN_FLAG));
  end;
  //释放执行线程
  for i := 0 to FWorkThreads.Count - 1 do
  begin
    FWorkThreads.Items[i].Free;
  end;
  FWorkThreads.Clear;
  FSocketHandles.Clear;
  CloseHandle(FIocpHandle);
end;

procedure TIocpServer.SetActive(const AValue: Boolean);
begin
  if FActive = AValue then Exit;
  FActive := AValue;
  if AValue then
  begin
    try
      Open;
    except
      on E: Exception do
      begin
        FActive := False;
        raise Exception.Create(E.Message);
      end;
    end;
  end
  else
  begin
    try
      Close;
    except
      on E: Exception do
      begin
        FActive := True;
        raise Exception.Create(E.Message);
      end;
    end;
  end;
end;

procedure TIocpServer.AcceptClient;
var
  ClientSocket: TSocket;
begin
  ClientSocket := WSAAccept(FSocket, nil, nil, nil, 0);
  if ClientSocket <> INVALID_SOCKET then
  begin
    if not FActive then
    begin
      closesocket(ClientSocket);
      Exit;
    end;
    FAcceptThreadPool.PostSocket(ClientSocket);
  end;
end;

procedure TIocpServer.CheckClient(const ASocket: TSocket);
var
  SocketHandle: TSocketHandle;
  iIndex: Integer;
  ClientSocket: PClientSocket;
begin
  SocketHandle := nil;
  if not DoConnect(ASocket, SocketHandle) then //如果不允许连接，则退出
  begin
    closesocket(ASocket);
    Exit;
  end;
  FSocketHandles.Lock; //加到列表中
  try
    iIndex := FSocketHandles.Add(SocketHandle);
    ClientSocket := FSocketHandles.Items[iIndex];
  finally
    FSocketHandles.UnLock;
  end;
  if CreateIoCompletionPort(ASocket, FIOCPHandle, DWORD(ClientSocket), 0) = 0 then
  begin
    DoError('CreateIoCompletionPort', GetLastWsaErrorStr);
    FSocketHandles.Lock; //如果投递到列表中失败，则删除
    try
      FSocketHandles.Delete(iIndex);
    finally
      FSocketHandles.UnLock;
    end;
  end
  else
  begin
    SocketHandle.PreRecv; //投递接收请求
  end;
end;

function TIocpServer.DoConnect(const ASocket: TSocket; var SocketHandle: TSocketHandle): Boolean;
begin
  Result := True;
  FConnectTime := Now;
  if Assigned(FOnConnect) then
  begin
    FOnConnect(ASocket, Result, SocketHandle);
  end;
end;

procedure TIocpServer.DoError(const AName, AError: string);
begin
  if Assigned(FOnError) then
    FOnError(AName, AError);
end;

function TIocpServer.WorkClient: Boolean;
var
  ClientSocket: PClientSocket;
  IocpRecord: PIocpRecord;
  iWorkCount: Cardinal;
begin
  IocpRecord := nil;
  iWorkCount := 0;
  ClientSocket := nil;
  Result := False;
  if not GetQueuedCompletionStatus(FIocpHandle, iWorkCount, DWORD(ClientSocket),
    POverlapped(IocpRecord), INFINITE) then //此处有可能多个线程处理同一个SocketHandle对象，因此需要加锁
  begin  //客户端异常断开
    if Assigned(ClientSocket) and Assigned(ClientSocket.SocketHandle) then
    begin
      ClientSocket.SocketHandle.FConnected := False;
      Exit;
    end;
  end;
  if Cardinal(IocpRecord) = SHUTDOWN_FLAG then
    Exit;
  if not FActive then
    Exit;
  Result := True;

  if Assigned(ClientSocket) and Assigned(ClientSocket.SocketHandle) then
  begin
    if ClientSocket.SocketHandle.Connected then
    begin
      if iWorkCount > 0 then //处理接收到的数据
      begin
        try
          ClientSocket.Lock.Enter;
          try
            if Assigned(ClientSocket.SocketHandle) then
            begin
              ClientSocket.SocketHandle.ProcessIOComplete(IocpRecord, iWorkCount);
              if not ClientSocket.SocketHandle.Connected then
                FreeSocketHandle(ClientSocket.SocketHandle);
            end;
          finally
            ClientSocket.Lock.Leave;
          end;
        except
          on E: Exception do
            DoError('ProcessIOComplete', E.Message);
        end;
      end
      else //如果完成个数为0，且状态为接收，则释放连接
      begin
        if IocpRecord.IocpOperate = ioRead then
        begin
          ClientSocket.Lock.Enter;
          try
            if Assigned(ClientSocket.SocketHandle) then
              FreeSocketHandle(ClientSocket.SocketHandle);
          finally
            ClientSocket.Lock.Leave;
          end;
        end
        else
          DoError('WorkClient', 'WorkCount = 0, Code: ' + IntToStr(GetLastError) + ', Message: ' + GetLastErrorStr);
      end;
    end
    else //断开连接
    begin
      ClientSocket.Lock.Enter;
      try
        if Assigned(ClientSocket.SocketHandle) then
          FreeSocketHandle(ClientSocket.SocketHandle);
      finally
        ClientSocket.Lock.Leave;
      end;
    end;
  end
  else //WorkCount为0表示发生了异常，记录日志
    DoError('GetQueuedCompletionStatus', 'Return SocketHandle nil');
end;

procedure TIocpServer.DoDisconnect(const ASocketHandle: TSocketHandle);
begin
  if Assigned(FOnDisconnect) then
    FOnDisconnect(ASocketHandle);
end;

procedure TIocpServer.FreeSocketHandle(const ASocketHandle: TSocketHandle);
begin
  DoDisconnect(ASocketHandle);
  FSocketHandles.Lock;
  try
    FSocketHandles.Delete(ASocketHandle);
  finally
    FSocketHandles.UnLock;
  end;
end;

procedure TIocpServer.FreeSocketHandle(const AIndex: Integer);
begin
  DoDisconnect(FSocketHandles.Items[AIndex].SocketHandle);
  FSocketHandles.Lock;
  try
    FSocketHandles.Delete(AIndex);
  finally
    FSocketHandles.UnLock;
  end;
end;

function TIocpServer.ReadChar(const ASocket: TSocket; var AChar: Char; const ATimeOutMS: Integer): Boolean;
var
  iRead: Integer;
begin
  Result := CheckTimeOut(ASocket, ATimeOutMS);
  if Result then
  begin
    iRead := recv(ASocket, AChar, 1, 0);
    Result := iRead = 1; 
  end;
end;

function TIocpServer.CheckTimeOut(const ASocket: TSocket;
  const ATimeOutMS: Integer): Boolean;
var
  tmTo: TTimeVal;
  FDRead: TFDSet;
begin
  FillChar(FDRead, SizeOf(FDRead), 0);
  FDRead.fd_count := 1;
  FDRead.fd_array[0] := ASocket;
  tmTo.tv_sec := ATimeOutMS div 1000;
  tmTo.tv_usec := (ATimeOutMS mod 1000) * 1000;
  Result := Select(0, @FDRead, nil, nil, @tmTO) = 1;
end;

procedure TIocpServer.CheckDisconnectedClient;
var
  iCount: Integer;
  ClientSocket: PClientSocket;

  function GetDisconnectSocket: PClientSocket;
  var
    i: Integer;
  begin
    Result := nil;
    FSocketHandles.Lock;
    try
      for i := FSocketHandles.Count - 1 downto 0 do
      begin
        if (not FSocketHandles.Items[i].SocketHandle.Connected)
          and (not FSocketHandles.Items[i].SocketHandle.Executing) then
        begin
          Result := FSocketHandles.Items[i];
          Break;
        end;
      end;
    finally
      FSocketHandles.UnLock;
    end;
  end;
begin
  ClientSocket := GetDisconnectSocket;
  iCount := 0;
  while (ClientSocket <> nil) and (iCount < 1024 * 1024) do
  begin
    //WriteLogMsg(ltWarn, 'CheckDisconnectedClient Free Socket Handle, Idle Time: '
    //  + IntToStr(SecondsBetween(Now, ClientSocket.IdleDT)));
    ClientSocket.Lock.Enter;
    try
      if Assigned(ClientSocket.SocketHandle) then
        FreeSocketHandle(ClientSocket.SocketHandle);
    finally
      ClientSocket.Lock.Leave;
    end;
    //WriteLogMsg(ltWarn, 'CheckDisconnectedClient Get Next Disconnected Socket');
    ClientSocket := GetDisconnectSocket;
    Inc(iCount);
  end;
end;

{ TIocpThread }

constructor TIocpThread.Create(const AServer: TIocpServer; CreateSuspended: Boolean);
begin
  inherited Create(CreateSuspended);
  FIocpServer := AServer;
end;

{ TAcceptThread }

procedure TAcceptThread.Execute;
begin
  inherited;
  while (not Terminated) and FIocpServer.Active do
  begin
    try
      FIocpServer.AcceptClient;
    except
    end;
  end;
end;

{ TWorkThread }

procedure TWorkThread.Execute;
begin
  inherited;
  CoInitialize(nil);
  try
    while (not Terminated) and FIocpServer.Active do
    begin
      try
        if not FIocpServer.WorkClient then Continue;
      except  //处理一切异常，防止挂死线程
        on E: Exception do
          FIocpServer.DoError('WorkClient', E.Message);
      end;
    end;
  finally
    CoUninitialize;
  end;
end;

{ TWorkThreads }

constructor TWorkThreads.Create;
begin
  inherited Create(TWorkThread);
end;

function TWorkThreads.GetItems(AIndex: Integer): TWorkThread;
begin
  Result := TWorkThread(inherited Items[AIndex]);
end;

procedure TWorkThreads.SetItems(AIndex: Integer;
  AValue: TWorkThread);
begin
  inherited Items[AIndex] := AValue;
end;

{ TCheckThread }

procedure TCheckThread.Execute;
var
  Socket: TSocket;
  iWorkCount: Cardinal;
  Overlapped: POverlapped;
begin
  inherited;
  CoInitialize(nil);
  try
    while (not Terminated) and FIocpServer.Active do
    begin
      if not GetQueuedCompletionStatus(FIocpThreadPool.FIocpHandle, iWorkCount, Socket,
        Overlapped, INFINITE) then Continue;
      if Cardinal(Overlapped) = SHUTDOWN_FLAG then Exit; //退出标志
      try
        FIocpServer.CheckClient(Socket);
      except
        on E: Exception do
        begin
          FIocpServer.DoError('CheckClient', E.Message);
        end;
      end;
    end;
  finally
    CoUninitialize;
  end;
end;

{ TCheckThreads }

constructor TCheckThreads.Create;
begin
  inherited Create(TCheckThread);
end;

function TCheckThreads.GetItems(AIndex: Integer): TCheckThread;
begin
  Result := TCheckThread(inherited Items[AIndex]);
end;

procedure TCheckThreads.SetItems(AIndex: Integer; AValue: TCheckThread);
begin
  inherited Items[AIndex] := AValue;
end;

{ TIocpThreadPool }

constructor TIocpThreadPool.Create(const AServer: TIocpServer);
begin
  FIocpServer := AServer;
  FCheckThreads := TCheckThreads.Create;
end;

destructor TIocpThreadPool.Destroy;
begin
  FCheckThreads.Free;                
  inherited;
end;

procedure TIocpThreadPool.Open;
var
  i, iCount: Integer;
  CheckThread: TCheckThread;
begin
  FIocpHandle := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, 0);
  iCount := GetCPUCount * 2;
  if iCount < FIocpServer.MinCheckThrCount then
    iCount := FIocpServer.MinCheckThrCount;
  if iCount > FIocpServer.MaxCheckThrCount then
    iCount := FIocpServer.MaxCheckThrCount;
  for i := 1 to iCount do
  begin
    CheckThread := TCheckThread.Create(FIocpServer, True);
    FCheckThreads.Add(CheckThread);
    CheckThread.IocpThreadPool := Self;
    CheckThread.Resume;
  end;
end;

procedure TIocpThreadPool.Close;
var
  i: Integer;
begin
  //退出线程执行
  for i := 0 to FCheckThreads.Count - 1 do
  begin
    FCheckThreads.Items[i].Terminate;
    PostQueuedCompletionStatus(FIocpHandle, 0, 0, Pointer(SHUTDOWN_FLAG));
  end;
  //释放线程
  for i := 0 to FCheckThreads.Count - 1 do
  begin
    FCheckThreads.Items[i].Free;
  end;
  FCheckThreads.Clear;
  CloseHandle(FIocpHandle);
end;

procedure TIocpThreadPool.SetActive(const AValue: Boolean);
begin
  if FActive = AValue then Exit;
  if AValue then
    Open
  else
    Close;
  FActive := AValue;
end;

procedure TIocpThreadPool.PostSocket(const ASocket: TSocket);
begin
  PostQueuedCompletionStatus(FIocpHandle, 0, ASocket, nil);
end;

end.
