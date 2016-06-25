program IOCPDemoCln;

uses
  ShareMem,
  Forms,
  IOCPDemoClnMain in 'Forms\IOCPDemoClnMain.pas' {FmIOCPDemoClnMain},
  BaseForm in 'Forms\BaseForm.pas' {FmBase},
  BaseClientSocket in 'Socket\BaseClientSocket.pas',
  ControlSocket in 'Socket\ControlSocket.pas',
  DefineUnit in '..\IOCPDemoSvr\Unit\DefineUnit.pas',
  LoginForm in 'Forms\LoginForm.pas' {FmLogin},
  ModalForm in 'Forms\ModalForm.pas' {FmModal},
  DataMgrCtr in 'Units\DataMgrCtr.pas',
  LogSocket in 'Socket\LogSocket.pas',
  ClientDefineUnit in 'Units\ClientDefineUnit.pas',
  SQLSocket in 'Socket\SQLSocket.pas',
  BaseFrame in 'Forms\BaseFrame.pas' {FamBase: TFrame},
  LogFrame in 'Forms\LogFrame.pas' {FamLog: TFrame},
  ClientsFrame in 'Forms\ClientsFrame.pas' {FamClients: TFrame},
  SQLFrame in 'Forms\SQLFrame.pas' {FamSQL: TFrame},
  UploadSocket in 'Socket\UploadSocket.pas',
  UploadFrame in 'Forms\UploadFrame.pas' {FamUpload: TFrame},
  DrawListViewProgress in 'Units\DrawListViewProgress.pas',
  DownloadSocket in 'Socket\DownloadSocket.pas',
  DownloadFrame in 'Forms\DownloadFrame.pas' {FamDownload: TFrame},
  BasisFunction in '..\IOCPDemoSvr\Unit\BasisFunction.pas',
  RemoteStreamSocket in 'Socket\RemoteStreamSocket.pas',
  RemoteStream in 'Units\RemoteStream.pas',
  RemoteStreamFrame in 'Forms\RemoteStreamFrame.pas' {FamRemoteStream: TFrame},
  ThroughputForm in 'Forms\ThroughputForm.pas' {FmThroughputForm},
  ThroughputSocket in 'Socket\ThroughputSocket.pas',
  Logger in '..\IOCPDemoSvr\Unit\Logger.pas';

{$R *.res}
{$R ..\WindowsXP_UAC.res}

begin
  Application.Initialize;
  GLogger := TLogger.Create;
  GDataMgrCtr := TDataMgrCtr.Create;
  try
    InitLogger(1024 * 64, 'Log');
    Application.Title := 'IOCP Demo Client';
    Application.CreateForm(TFmIOCPDemoClnMain, FmIOCPDemoClnMain);
    Application.Run;
  finally
    GDataMgrCtr.Free;
    GLogger.Free;
  end;
end.
