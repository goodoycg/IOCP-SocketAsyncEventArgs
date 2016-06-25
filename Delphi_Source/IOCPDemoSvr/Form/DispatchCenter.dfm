object DMDispatchCenter: TDMDispatchCenter
  OldCreateOrder = False
  Left = 335
  Top = 221
  Height = 150
  Width = 215
  object IcpSvr: TIocpServer
    Active = False
    Port = 0
    OnConnect = IcpSvrConnect
    OnError = IcpSvrError
    OnDisconnect = IcpSvrDisconnect
    MaxWorkThrCount = 160
    MinWorkThrCount = 120
    MaxCheckThrCount = 60
    MinCheckThrCount = 40
    Left = 72
    Top = 32
  end
end
