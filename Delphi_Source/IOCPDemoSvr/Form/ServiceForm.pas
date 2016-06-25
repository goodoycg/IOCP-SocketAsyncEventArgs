unit ServiceForm;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, SvcMgr, Dialogs,
  BasisFunction, ActiveX;

type
  TIOCPDemoSvc = class(TService)
    procedure ServiceAfterInstall(Sender: TService);
    procedure ServiceBeforeInstall(Sender: TService);
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
  private
    { Private declarations }
  public
    function GetServiceController: TServiceController; override;
    { Public declarations }
  end;

var
  IOCPDemoSvc: TIOCPDemoSvc;

implementation

uses DispatchCenter;

{$R *.DFM}
const
  CSRegServiceURL = 'SYSTEM\CurrentControlSet\Services\';
  CSRegDescription = 'Description';
  CSRegImagePath = 'ImagePath';
  CSServiceDescription = 'IOCP DEMO Service';

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  IOCPDemoSvc.Controller(CtrlCode);
end;

function TIOCPDemoSvc.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

procedure TIOCPDemoSvc.ServiceAfterInstall(Sender: TService);
begin
  RegWriteString(HKEY_LOCAL_MACHINE, CSRegServiceURL + Name, CSRegDescription,
    CSServiceDescription);
  RegWriteString(HKEY_LOCAL_MACHINE, CSRegServiceURL + Name, CSRegImagePath,
    ParamStr(0) + ' -svc');
end;

procedure TIOCPDemoSvc.ServiceBeforeInstall(Sender: TService);
begin
  RegValueDelete(HKEY_LOCAL_MACHINE, CSRegServiceURL + Name, CSRegDescription);
end;

procedure TIOCPDemoSvc.ServiceStart(Sender: TService; var Started: Boolean);
begin
  CoInitialize(nil);
  Started := DMDispatchCenter.Start;
end;

procedure TIOCPDemoSvc.ServiceStop(Sender: TService; var Stopped: Boolean);
begin
  Stopped := DMDispatchCenter.Stop;
  CoUninitialize;
end;

end.

