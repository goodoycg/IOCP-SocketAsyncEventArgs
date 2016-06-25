inherited FmThroughputForm: TFmThroughputForm
  Left = 411
  Top = 225
  Width = 648
  Height = 376
  BorderIcons = [biSystemMenu]
  Caption = 'Throughput'
  Position = poMainFormCenter
  OnCloseQuery = FormCloseQuery
  PixelsPerInch = 96
  TextHeight = 13
  object grpConnectionCount: TGroupBox
    Left = 0
    Top = 0
    Width = 632
    Height = 60
    Align = alTop
    Caption = 'Connection Count'
    TabOrder = 0
    object lblConnectionCount: TLabel
      Left = 8
      Top = 27
      Width = 85
      Height = 13
      Caption = 'Connection Count'
    end
    object lblCount: TLabel
      Left = 432
      Top = 27
      Width = 3
      Height = 13
    end
    object cbbConnectionCount: TComboBox
      Left = 115
      Top = 24
      Width = 145
      Height = 21
      ItemHeight = 13
      TabOrder = 0
      Text = '8129'
      Items.Strings = (
        '1024'
        '2048'
        '4096'
        '8129'
        '16384'
        '32768'
        '65536')
    end
    object btnConnect: TButton
      Left = 268
      Top = 24
      Width = 75
      Height = 25
      Caption = 'Connect'
      TabOrder = 1
      OnClick = btnConnectClick
    end
    object btnDisconnect: TButton
      Left = 351
      Top = 24
      Width = 75
      Height = 25
      Caption = 'Disconnect'
      TabOrder = 2
      OnClick = btnDisconnectClick
    end
  end
  object grpCyclePacket: TGroupBox
    Left = 0
    Top = 60
    Width = 632
    Height = 278
    Align = alClient
    Caption = 'Cycle Packet'
    TabOrder = 1
    object lvCyclePacket: TListView
      Left = 2
      Top = 56
      Width = 628
      Height = 220
      Align = alClient
      Columns = <
        item
          Caption = 'Index'
        end
        item
          Caption = 'Thread'
          Width = 80
        end
        item
          Caption = 'Loacl Address'
          Width = 160
        end
        item
          Caption = 'RemoteAddress'
          Width = 160
        end
        item
          Caption = 'Count'
          Width = 80
        end
        item
          Caption = 'Completed'
          Width = 80
        end>
      ReadOnly = True
      RowSelect = True
      TabOrder = 0
      ViewStyle = vsReport
    end
    object pnlCyclePacket: TPanel
      Left = 2
      Top = 15
      Width = 628
      Height = 41
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 1
      object lblThreadCount: TLabel
        Left = 6
        Top = 8
        Width = 65
        Height = 13
        Caption = 'Thread Count'
      end
      object cbbThreadCount: TComboBox
        Left = 113
        Top = 8
        Width = 145
        Height = 21
        ItemHeight = 13
        TabOrder = 0
        Text = '32'
        Items.Strings = (
          '2'
          '4'
          '8'
          '16'
          '32'
          '64'
          '128'
          '256'
          '512'
          '1024')
      end
      object btnStart: TButton
        Left = 266
        Top = 8
        Width = 75
        Height = 25
        Caption = 'Start'
        TabOrder = 1
        OnClick = btnStartClick
      end
      object btnStop: TButton
        Left = 349
        Top = 8
        Width = 75
        Height = 25
        Caption = 'Stop'
        TabOrder = 2
        OnClick = btnStopClick
      end
      object cbbPacketSize: TComboBox
        Left = 432
        Top = 8
        Width = 65
        Height = 21
        Style = csDropDownList
        ItemHeight = 13
        ItemIndex = 13
        TabOrder = 3
        Text = '128K'
        Items.Strings = (
          '16B'
          '32B'
          '64B'
          '128B'
          '256B'
          '512B'
          '1K'
          '2K'
          '4K'
          '8K'
          '16K'
          '32K'
          '64K'
          '128K'
          '256K'
          '512K'
          '1M'
          '2M'
          '4M'
          '8M')
      end
      object cbbCycleCount: TComboBox
        Left = 504
        Top = 8
        Width = 80
        Height = 21
        ItemHeight = 13
        TabOrder = 4
        Text = '65535'
        Items.Strings = (
          '5000'
          '10000'
          '20000'
          '30000'
          '40000'
          '50000'
          '60000'
          '70000'
          '80000'
          '90000'
          '10000')
      end
    end
  end
  object tmrConnectCounter: TTimer
    OnTimer = tmrConnectCounterTimer
    Left = 72
    Top = 156
  end
  object tmrCyclePacketCounter: TTimer
    OnTimer = tmrCyclePacketCounterTimer
    Left = 208
    Top = 156
  end
end
