unit OptionSet;

interface

uses
  SysUtils, Classes, Windows, Messages, IniFiles, DefineUnit, Logger;

type
  TIniOptions = class(TObject)
  private
    FFileName: string;
    FIniFile: TIniFile;
    {* 文件存放路径 *}
    FFileDirectory: string;
    {* 工作线程和监听线程 *}
    FMaxWorkThreadCount: Word;
    FMinWorkThreadCount: Word;
    FMaxListenThreadCount: Word;
    FMinListenThreadCount: Word;
    {* 默认监听端口 *}
    FSocketPort: Word;
    FSocketTimeOut: Word;
    FTransTimeOut: Word;
    FMaxSocketCount: Word;
    FSQLProtocol: Boolean;
    FUploadProtocol: Boolean;
    FDownloadProtocol: Boolean;
    FRemoteStreamProtocol: Boolean;
    FControlProtocol: Boolean;
    FLogProtocol: Boolean;
    {* 服务器数据库设置 *}
    FDBServer: string;
    FDBAuthentication: TDBAuthentication;
    FDBPort: Integer;
    FDBLoginName: string;
    FDBPassword: string;
    FDBName: string;
    FDBConnectDB: Boolean;
    {* 日志配置 *}
    FLogFile: TLogFilter;
    FLogDesktop: TLogFilter;
    FLogSocket: TLogFilter;
    procedure SetFileDirectory(const AValue: string);
    procedure SetMaxWorkThreadCount(const AValue: Word);
    procedure SetMinWorkThreadCount(const AValue: Word);
    procedure SetMaxListenThreadCount(const AValue: Word);
    procedure SetMinListenThreadCount(const AValue: Word);
    procedure SetDefaultPort(const AValue: Word);
    procedure SetSocketTimeOut(const AValue: Word);
    procedure SetTransTimeOut(const AValue: Word);
    procedure SetMaxSocketCount(const AValue: Word);
    procedure SetSQLProtocol(const AValue: Boolean);
    procedure SetUploadProtocol(const AValue: Boolean);
    procedure SetDownloadProtocol(const AValue: Boolean);
    procedure SetRemoteStreamProtocol(const AValue: Boolean);
    procedure SetControlProtocol(const AValue: Boolean);
    procedure SetLogProtocol(const AValue: Boolean);
    procedure SetDBServer(const AValue: string);
    procedure SetDBAuthentication(const AValue: TDBAuthentication);
    procedure SetDBPort(const AValue: Integer);
    procedure SetDBLoginName(const AValue: string);
    procedure SetDBPassword(const AValue: string);
    procedure SetDBName(const AValue: string);
    procedure SetDBConnectDB(const AValue: Boolean);
    procedure SetLogFile(const AValue: TLogFilter);
    procedure SetLogDesktop(const AValue: TLogFilter);
    procedure SetLogSocket(const AValue: TLogFilter);
  public
    constructor Create;
    procedure BeginWrite;
    procedure EndWrite;
    {* 加载 *}
    procedure Load;

    property FileDirestory: string read FFileDirectory write SetFileDirectory;
    property MaxWorkThreadCount: Word read FMaxWorkThreadCount write SetMaxWorkThreadCount;
    property MinWorkThreadCount: Word read FMinWorkThreadCount write SetMinWorkThreadCount;
    property MaxListenThreadCount: Word read FMaxListenThreadCount write SetMaxListenThreadCount;
    property MinListenThreadCount: Word read FMinListenThreadCount write SetMinListenThreadCount;
    property SocketPort: Word read FSocketPort write SetDefaultPort;
    property SocketTimeOut: Word read FSocketTimeOut write SetSocketTimeOut;
    property TransTimeOut: Word read FTransTimeOut write SetTransTimeOut;
    property MaxSocketCount: Word read FMaxSocketCount write SetMaxSocketCount;
    property SQLProtocol: Boolean read FSQLProtocol write SetSQLProtocol;
    property UploadProtocol: Boolean read FUploadProtocol write SetUploadProtocol;
    property DownloadProtocol: Boolean read FDownloadProtocol write SetDownloadProtocol;
    property RemoteStreamProtocol: Boolean read FRemoteStreamProtocol write SetRemoteStreamProtocol;
    property ControlProtocol: Boolean read FControlProtocol write SetControlProtocol;
    property LogProtocol: Boolean read FLogProtocol write SetLogProtocol;
    property DBServer: string read FDBServer write SetDBServer;
    property DBAuthentication: TDBAuthentication read FDBAuthentication write SetDBAuthentication;
    property DBPort: Integer read FDBPort write SetDBPort;
    property DBLoginName: string read FDBLoginName write SetDBLoginName;
    property DBPassword: string read FDBPassword write SetDBPassword;
    property DBName: string read FDBName write SetDBName;
    property DBConnectDB: Boolean read FDBConnectDB write SetDBConnectDB;
    property LogFile: TLogFilter read FLogFile write SetLogFile;
    property LogDesktop: TLogFilter read FLogDesktop write SetLogDesktop;
    property LogSocket: TLogFilter read FLogSocket write SetLogSocket;
  end;

var
  GIniOptions: TIniOptions;

procedure InitOptionSet;
procedure UnInitOptionSet;

implementation

uses BasisFunction;

const
  CSIOCPDemoSvr = 'IOCPDemoSvr';
  CSFileDirectory = 'FileDirectory';
  CSMaxWorkThreadCount = 'MaxWorkThreadCount';
  CSMinWorkThreadCount = 'MinWorkThreadCount';
  CSMaxListenThreadCount = 'MaxListenThreadCount';
  CSMinListenThreadCount = 'MinListenThreadCount';
  CSSocketPort = 'SocketPort';
  CSSocketTimeOut = 'SocketTimeOut';
  CSTransTimeOut = 'TransTimeOut';
  CSMaxSocketCount = 'MaxSocketCount';
  CSSQLProtocol = 'SQLProtocol';
  CSUploadProtocol = 'UploadProtocol';
  CSDownloadProtocol = 'DownloadProtocol';
  CSRemoteStreamProtocol = 'RemoteStreamProtocol';
  CSControlProtocol = 'ControlProtocol';
  CSLogProtocol = 'LogProtocol';
  CSDBServer = 'DBServer';
  CSDBAuthentication = 'DBAuthentication';
  CSDBPort = 'DBPort';
  CSDBLoginName = 'DBLoginName';
  CSDBPassword = 'DBPassword';
  CSDBName = 'DBName';
  CSDBConnectDB = 'DBConnectDB';
  CSLogFile = 'LogFile';
  CSLogDesktop = 'LogDesktop';
  CSLogSocket = 'LogSocket';

{ TIniOptions }

constructor TIniOptions.Create;
begin
  FFileName := ChangeFileExt(ParamStr(0), '.ini');
end;

procedure TIniOptions.BeginWrite;
begin
  FIniFile := TIniFile.Create(FFileName);
end;

procedure TIniOptions.EndWrite;
begin
  FIniFile.Free;
end;

procedure TIniOptions.Load;
begin
  BeginWrite;
  try
    FFileDirectory := FIniFile.ReadString(CSIOCPDemoSvr, CSFileDirectory, AppPath + 'Files' + PathDelim);
    FMaxWorkThreadCount := FIniFile.ReadInteger(CSIOCPDemoSvr, CSMaxWorkThreadCount, 160);
    FMinWorkThreadCount := FIniFile.ReadInteger(CSIOCPDemoSvr, CSMinWorkThreadCount, 60);
    FMaxListenThreadCount := FIniFile.ReadInteger(CSIOCPDemoSvr, CSMaxListenThreadCount, 120);
    FMinListenThreadCount := FIniFile.ReadInteger(CSIOCPDemoSvr, CSMinListenThreadCount, 40);
    FSocketPort := FIniFile.ReadInteger(CSIOCPDemoSvr, CSSocketPort, 9999);
    FSocketTimeOut := FIniFile.ReadInteger(CSIOCPDemoSvr, CSSocketTimeOut, 10);
    FTransTimeOut := FIniFile.ReadInteger(CSIOCPDemoSvr, CSTransTimeOut, 5);
    FMaxSocketCount := FIniFile.ReadInteger(CSIOCPDemoSvr, CSMaxSocketCount, 0);
    FSQLProtocol := FIniFile.ReadBool(CSIOCPDemoSvr, CSSQLProtocol, True);
    FUploadProtocol := FIniFile.ReadBool(CSIOCPDemoSvr, CSUploadProtocol, True);
    FDownloadProtocol := FIniFile.ReadBool(CSIOCPDemoSvr, CSDownloadProtocol, True);
    FRemoteStreamProtocol := FIniFile.ReadBool(CSIOCPDemoSvr, CSRemoteStreamProtocol, True);
    FControlProtocol := FIniFile.ReadBool(CSIOCPDemoSvr, CSControlProtocol, True);
    FLogProtocol := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogProtocol, True);
    FDBServer := FIniFile.ReadString(CSIOCPDemoSvr, CSDBServer, '');
    FDBAuthentication := TDBAuthentication(FIniFile.ReadInteger(CSIOCPDemoSvr, CSDBAuthentication,
      Integer(daSQLServer)));
    FDBPort := FIniFile.ReadInteger(CSIOCPDemoSvr, CSDBPort, 0);
    FDBLoginName := FIniFile.ReadString(CSIOCPDemoSvr, CSDBLoginName, 'sa');
    FDBPassword := FIniFile.ReadString(CSIOCPDemoSvr, CSDBPassword, '');
    FDBName := FIniFile.ReadString(CSIOCPDemoSvr, CSDBName, '');
    FDBConnectDB := FIniFile.ReadBool(CSIOCPDemoSvr, CSDBConnectDB, True);

    FLogFile[ltInfo] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltInfo], True);
    FLogFile[ltSucc] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltSucc], True);
    FLogFile[ltWarn] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltWarn], True);
    FLogFile[ltError] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltError], True);
    FLogFile[ltDebug] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltDebug], True);
    FLogDesktop[ltInfo] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltInfo], True);
    FLogDesktop[ltSucc] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltSucc], True);
    FLogDesktop[ltWarn] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltWarn], True);
    FLogDesktop[ltError] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltError], True);
    FLogDesktop[ltDebug] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltDebug], True);
    FLogSocket[ltInfo] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltInfo], True);
    FLogSocket[ltSucc] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltSucc], True);
    FLogSocket[ltWarn] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltWarn], True);
    FLogSocket[ltError] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltError], True);
    FLogSocket[ltDebug] := FIniFile.ReadBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltDebug], True);
  finally
    EndWrite;
  end;
end;

procedure InitOptionSet;
begin
  GIniOptions := TIniOptions.Create;
  GIniOptions.Load;
end;

procedure UnInitOptionSet;
begin
  GIniOptions.Free;
end;

procedure TIniOptions.SetFileDirectory(const AValue: string);
begin
  if (not SameText(FFileDirectory, AValue)) and (DirectoryExists(AValue)) then
  begin
    FIniFile.WriteString(CSIOCPDemoSvr, CSFileDirectory, AValue);
    FFileDirectory := AValue;
  end;
end;

procedure TIniOptions.SetMaxWorkThreadCount(const AValue: Word);
begin
  if (FMaxWorkThreadCount <> AValue) and (AValue > 0) then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSMaxWorkThreadCount, AValue);
    FMaxWorkThreadCount := AValue;
  end;
end;

procedure TIniOptions.SetMinWorkThreadCount(const AValue: Word);
begin
  if (FMinWorkThreadCount <> AValue) and (AValue > 0) then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSMinWorkThreadCount, AValue);
    FMinWorkThreadCount := AValue;
  end;
end;

procedure TIniOptions.SetMaxListenThreadCount(const AValue: Word);
begin
  if (FMaxListenThreadCount <> AValue) and (AValue > 0) then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSMaxListenThreadCount, AValue);
    FMaxListenThreadCount := AValue;
  end;
end;

procedure TIniOptions.SetMinListenThreadCount(const AValue: Word);
begin
  if (FMinListenThreadCount <> AValue) and (AValue > 0) then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSMinListenThreadCount, AValue);
    FMinListenThreadCount := AValue;
  end;
end;

procedure TIniOptions.SetDefaultPort(const AValue: Word);
begin
  if FSocketPort <> AValue then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSSocketPort, AValue);
    FSocketPort := AValue;
  end;
end;

procedure TIniOptions.SetSocketTimeOut(const AValue: Word);
begin
  if (FSocketTimeOut <> AValue) and (AValue > 0) then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSSocketTimeOut, AValue);
    FSocketTimeOut := AValue;
  end;
end;

procedure TIniOptions.SetTransTimeOut(const AValue: Word);
begin
  if (FTransTimeOut <> AValue) and (AValue > 0) then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSTransTimeOut, AValue);
    FTransTimeOut := AValue;
  end;
end;

procedure TIniOptions.SetMaxSocketCount(const AValue: Word);
begin
  if FMaxSocketCount <> AValue then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSMaxSocketCount, AValue);
    FMaxSocketCount := AValue;
  end;
end;

procedure TIniOptions.SetSQLProtocol(const AValue: Boolean);
begin
  if FSQLProtocol <> AValue then
  begin
    FIniFile.WriteBool(CSIOCPDemoSvr, CSSQLProtocol, AValue);
    FSQLProtocol := AValue;
  end;
end;

procedure TIniOptions.SetUploadProtocol(const AValue: Boolean);
begin
  if FUploadProtocol <> AValue then
  begin
    FIniFile.WriteBool(CSIOCPDemoSvr, CSUploadProtocol, AValue);
    FUploadProtocol := AValue;
  end;
end;

procedure TIniOptions.SetDownloadProtocol(const AValue: Boolean);
begin
  if FDownloadProtocol <> AValue then
  begin
    FIniFile.WriteBool(CSIOCPDemoSvr, CSDownloadProtocol, AValue);
    FDownloadProtocol := AValue;
  end;
end;

procedure TIniOptions.SetRemoteStreamProtocol(const AValue: Boolean);
begin
  if FRemoteStreamProtocol <> AValue then
  begin
    FIniFile.WriteBool(CSIOCPDemoSvr, CSRemoteStreamProtocol, AValue);
    FRemoteStreamProtocol := AValue;
  end;
end;

procedure TIniOptions.SetControlProtocol(const AValue: Boolean);
begin
  if FControlProtocol <> AValue then
  begin
    FIniFile.WriteBool(CSIOCPDemoSvr, CSUploadProtocol, AValue);
    FUploadProtocol := AValue;
  end;
end;

procedure TIniOptions.SetLogProtocol(const AValue: Boolean);
begin
  if FLogProtocol <> AValue then
  begin
    FIniFile.WriteBool(CSIOCPDemoSvr, CSLogProtocol, AValue);
    FLogProtocol := AValue;
  end;
end;

procedure TIniOptions.SetDBServer(const AValue: string);
begin
  if FDBServer <> AValue then
  begin
    FIniFile.WriteString(CSIOCPDemoSvr, CSDBServer, AValue);
    FDBServer := AValue;
  end;
end;

procedure TIniOptions.SetDBAuthentication(
  const AValue: TDBAuthentication);
begin
  if FDBAuthentication <> AValue then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSDBAuthentication, Integer(AValue));
    FDBAuthentication := AValue;
  end;
end;

procedure TIniOptions.SetDBPort(const AValue: Integer);
begin
  if FDBPort <> AValue then
  begin
    FIniFile.WriteInteger(CSIOCPDemoSvr, CSDBPort, AValue);
    FDBPort := AValue;
  end;
end;

procedure TIniOptions.SetDBLoginName(const AValue: string);
begin
  if FDBLoginName <> AValue then
  begin
    FIniFile.WriteString(CSIOCPDemoSvr, CSDBLoginName, AValue);
    FDBLoginName := AValue;
  end;
end;

procedure TIniOptions.SetDBPassword(const AValue: string);
begin
  if FDBPassword <> AValue then
  begin
    FIniFile.WriteString(CSIOCPDemoSvr, CSDBPassword, AValue);
    FDBPassword := AValue;
  end;
end;

procedure TIniOptions.SetDBName(const AValue: string);
begin
  if FDBName <> AValue then
  begin
    FIniFile.WriteString(CSIOCPDemoSvr, CSDBName, AValue);
    FDBName := AValue;
  end;
end;

procedure TIniOptions.SetDBConnectDB(const AValue: Boolean);
begin
  if FDBConnectDB <> AValue then
  begin
    FIniFile.WriteBool(CSIOCPDemoSvr, CSDBConnectDB, AValue);
    FDBConnectDB := AValue;
  end;
end;

procedure TIniOptions.SetLogFile(const AValue: TLogFilter);
begin
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltInfo], AValue[ltInfo]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltSucc], AValue[ltSucc]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltWarn], AValue[ltWarn]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltError], AValue[ltError]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogFile + CSLogType[ltDebug], AValue[ltDebug]);
  FLogFile := AValue;
end;

procedure TIniOptions.SetLogDesktop(const AValue: TLogFilter);
begin
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltInfo], AValue[ltInfo]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltSucc], AValue[ltSucc]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltWarn], AValue[ltWarn]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltError], AValue[ltError]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogDesktop + CSLogType[ltDebug], AValue[ltDebug]);
  FLogDesktop := AValue;
end;

procedure TIniOptions.SetLogSocket(const AValue: TLogFilter);
begin
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltInfo], AValue[ltInfo]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltSucc], AValue[ltSucc]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltWarn], AValue[ltWarn]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltError], AValue[ltError]);
  FIniFile.WriteBool(CSIOCPDemoSvr, CSLogSocket + CSLogType[ltDebug], AValue[ltDebug]);
  FLogSocket := AValue;
end;

end.
