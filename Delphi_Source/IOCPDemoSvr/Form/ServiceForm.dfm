object IOCPDemoSvc: TIOCPDemoSvc
  OldCreateOrder = False
  AllowPause = False
  DisplayName = 'IOCP DEMO Service'
  BeforeInstall = ServiceBeforeInstall
  AfterInstall = ServiceAfterInstall
  OnStart = ServiceStart
  OnStop = ServiceStop
  Left = 524
  Top = 365
  Height = 150
  Width = 215
end
