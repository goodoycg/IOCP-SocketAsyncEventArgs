object FmConfig: TFmConfig
  Left = 573
  Top = 152
  Width = 441
  Height = 320
  BorderIcons = [biSystemMenu]
  Caption = 'Config'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object pnl1: TPanel
    Left = 0
    Top = 250
    Width = 425
    Height = 32
    Align = alBottom
    TabOrder = 1
    DesignSize = (
      425
      32)
    object btnOk: TBitBtn
      Left = 255
      Top = 4
      Width = 75
      Height = 23
      Anchors = [akTop, akRight]
      Caption = '&Ok'
      Default = True
      Enabled = False
      TabOrder = 0
      OnClick = btnOkClick
    end
    object btnCancel: TBitBtn
      Left = 338
      Top = 4
      Width = 75
      Height = 23
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = '&Cancel'
      TabOrder = 1
      OnClick = btnCancelClick
    end
  end
  object pnl2: TPanel
    Left = 0
    Top = 0
    Width = 425
    Height = 250
    Align = alClient
    TabOrder = 0
    object pgcClient: TPageControl
      Left = 1
      Top = 1
      Width = 423
      Height = 248
      ActivePage = tsSocket
      Align = alClient
      TabOrder = 0
      object tsBasic: TTabSheet
        Caption = 'Basic'
        DesignSize = (
          415
          220)
        object lblFileDirectory: TLabel
          Left = 8
          Top = 14
          Width = 61
          Height = 13
          Caption = 'File Directory'
        end
        object lbl9: TLabel
          Left = 75
          Top = 12
          Width = 7
          Height = 24
          Caption = '*'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -21
          Font.Name = 'MS Sans Serif'
          Font.Style = []
          ParentFont = False
        end
        object chkMaxWorkThreadCount: TLabel
          Left = 8
          Top = 72
          Width = 117
          Height = 13
          Caption = 'Max Work Thread Count'
        end
        object chkMaxListenThreadCount: TLabel
          Left = 8
          Top = 134
          Width = 119
          Height = 13
          Caption = 'Max Listen Thread Count'
        end
        object chkMinWorkThreadCount: TLabel
          Left = 8
          Top = 104
          Width = 114
          Height = 13
          Caption = 'Min Work Thread Count'
        end
        object chkMinListenThreadCount: TLabel
          Left = 8
          Top = 164
          Width = 116
          Height = 13
          Caption = 'Min Listen Thread Count'
        end
        object edtFileDirectory: TEdit
          Left = 88
          Top = 12
          Width = 321
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          ReadOnly = True
          TabOrder = 0
          Text = 'edtFileDirectory'
          OnChange = seSocketPortChange
        end
        object btnSelectDirectory: TButton
          Left = 334
          Top = 41
          Width = 75
          Height = 23
          Anchors = [akTop, akRight]
          Caption = 'Browse...'
          TabOrder = 1
          OnClick = btnSelectDirectoryClick
        end
        object seMaxWorkThreadCount: TSpinEdit
          Left = 132
          Top = 72
          Width = 121
          Height = 22
          MaxValue = 1024
          MinValue = 1
          TabOrder = 3
          Value = 1
          OnChange = seSocketPortChange
        end
        object seMaxListenThreadCount: TSpinEdit
          Left = 132
          Top = 132
          Width = 121
          Height = 22
          MaxValue = 1024
          MinValue = 1
          TabOrder = 2
          Value = 1
          OnChange = seSocketPortChange
        end
        object seMinWorkThreadCount: TSpinEdit
          Left = 132
          Top = 102
          Width = 121
          Height = 22
          MaxValue = 1024
          MinValue = 1
          TabOrder = 5
          Value = 1
          OnChange = seSocketPortChange
        end
        object seMinListenThreadCount: TSpinEdit
          Left = 132
          Top = 162
          Width = 121
          Height = 22
          MaxValue = 1024
          MinValue = 1
          TabOrder = 4
          Value = 1
          OnChange = seSocketPortChange
        end
      end
      object tsSocket: TTabSheet
        Caption = 'Socket'
        ImageIndex = 1
        DesignSize = (
          415
          220)
        object lblDefault: TLabel
          Left = 8
          Top = 15
          Width = 56
          Height = 13
          Caption = 'Socket Port'
        end
        object lbl1: TLabel
          Left = 75
          Top = 11
          Width = 7
          Height = 24
          Caption = '*'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -21
          Font.Name = 'MS Sans Serif'
          Font.Style = []
          ParentFont = False
        end
        object lblSocketTimeOut: TLabel
          Left = 8
          Top = 46
          Width = 80
          Height = 13
          Caption = 'Socket Time Out'
        end
        object lblTransTimeOut: TLabel
          Left = 8
          Top = 76
          Width = 73
          Height = 13
          Caption = 'Trans Time Out'
        end
        object lbl14: TLabel
          Left = 229
          Top = 46
          Width = 32
          Height = 13
          Caption = 'Minute'
        end
        object lbl15: TLabel
          Left = 229
          Top = 76
          Width = 32
          Height = 13
          Caption = 'Minute'
        end
        object lblMaxSocketCount: TLabel
          Left = 8
          Top = 104
          Width = 88
          Height = 13
          Caption = 'Max Socket Count'
        end
        object seSocketPort: TSpinEdit
          Left = 104
          Top = 12
          Width = 305
          Height = 22
          Anchors = [akLeft, akTop, akRight]
          MaxValue = 65535
          MinValue = 1
          TabOrder = 0
          Value = 1
          OnChange = seSocketPortChange
        end
        object seSocketTimeOut: TSpinEdit
          Left = 104
          Top = 42
          Width = 121
          Height = 22
          MaxValue = 100
          MinValue = 1
          TabOrder = 1
          Value = 1
          OnChange = seSocketPortChange
        end
        object seTransTimeOut: TSpinEdit
          Left = 104
          Top = 72
          Width = 121
          Height = 22
          MaxValue = 100
          MinValue = 1
          TabOrder = 2
          Value = 1
          OnChange = seSocketPortChange
        end
        object seMaxSocketCount: TSpinEdit
          Left = 104
          Top = 102
          Width = 121
          Height = 22
          MaxValue = 65535
          MinValue = 0
          TabOrder = 3
          Value = 0
          OnChange = seSocketPortChange
        end
        object grpProtocol: TGroupBox
          Left = 8
          Top = 132
          Width = 401
          Height = 80
          Anchors = [akLeft, akTop, akRight]
          Caption = 'Protocol'
          TabOrder = 4
          object chkSQL: TCheckBox
            Left = 24
            Top = 24
            Width = 97
            Height = 17
            Caption = 'SQL'
            TabOrder = 0
            OnClick = seSocketPortChange
          end
          object chkUpload: TCheckBox
            Left = 156
            Top = 24
            Width = 97
            Height = 17
            Caption = 'Upload'
            TabOrder = 2
            OnClick = seSocketPortChange
          end
          object chkDownload: TCheckBox
            Left = 156
            Top = 49
            Width = 97
            Height = 17
            Caption = 'Download'
            TabOrder = 3
            OnClick = seSocketPortChange
          end
          object chkControl: TCheckBox
            Left = 288
            Top = 24
            Width = 97
            Height = 17
            Caption = 'Control'
            TabOrder = 4
            OnClick = seSocketPortChange
          end
          object chkLog: TCheckBox
            Left = 288
            Top = 49
            Width = 97
            Height = 17
            Caption = 'Log'
            TabOrder = 5
            OnClick = seSocketPortChange
          end
          object chkRemoteStream: TCheckBox
            Left = 24
            Top = 49
            Width = 97
            Height = 17
            Caption = 'Remote Stream'
            TabOrder = 1
            OnClick = seSocketPortChange
          end
        end
      end
      object tsDatabase: TTabSheet
        Caption = 'Database'
        ImageIndex = 1
        DesignSize = (
          415
          220)
        object lbl2: TLabel
          Left = 23
          Top = 12
          Width = 62
          Height = 13
          Alignment = taRightJustify
          Caption = 'Server Name'
        end
        object lbl7: TLabel
          Left = 315
          Top = 15
          Width = 22
          Height = 13
          Anchors = [akTop, akRight]
          Caption = 'Port:'
        end
        object lbl5: TLabel
          Left = 17
          Top = 41
          Width = 68
          Height = 13
          Alignment = taRightJustify
          Caption = 'Authentication'
        end
        object lbl4: TLabel
          Left = 28
          Top = 70
          Width = 57
          Height = 13
          Alignment = taRightJustify
          Caption = 'Login Name'
        end
        object lbl6: TLabel
          Left = 39
          Top = 99
          Width = 46
          Height = 13
          Alignment = taRightJustify
          Caption = 'Password'
        end
        object lbl3: TLabel
          Left = 8
          Top = 128
          Width = 77
          Height = 13
          Alignment = taRightJustify
          Caption = 'Database Name'
        end
        object lbl13: TLabel
          Left = 88
          Top = 128
          Width = 7
          Height = 24
          Caption = '*'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -21
          Font.Name = 'MS Sans Serif'
          Font.Style = []
          ParentFont = False
        end
        object lbl12: TLabel
          Left = 88
          Top = 99
          Width = 7
          Height = 24
          Caption = '*'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -21
          Font.Name = 'MS Sans Serif'
          Font.Style = []
          ParentFont = False
        end
        object lbl11: TLabel
          Left = 88
          Top = 70
          Width = 7
          Height = 24
          Caption = '*'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -21
          Font.Name = 'MS Sans Serif'
          Font.Style = []
          ParentFont = False
        end
        object lbl8: TLabel
          Left = 88
          Top = 41
          Width = 7
          Height = 24
          Caption = '*'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -21
          Font.Name = 'MS Sans Serif'
          Font.Style = []
          ParentFont = False
        end
        object lbl10: TLabel
          Left = 88
          Top = 12
          Width = 7
          Height = 24
          Caption = '*'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clRed
          Font.Height = -21
          Font.Name = 'MS Sans Serif'
          Font.Style = []
          ParentFont = False
        end
        object edtDBServer: TEdit
          Left = 99
          Top = 12
          Width = 206
          Height = 21
          Hint = 
            #13#10' Backup data store path.'#13#10' Recommend use a diffrent disk to ba' +
            'ckup data. '#13#10
          Anchors = [akLeft, akTop, akRight]
          ImeName = #28857'['#24320#22987#31243#24207']'#25110'Ctrl+Alt+W'#21551#21160#19975#33021#20116#31508
          TabOrder = 0
          OnChange = seSocketPortChange
        end
        object edtDBPort: TEdit
          Left = 345
          Top = 12
          Width = 63
          Height = 21
          Hint = 
            #13#10' Backup data store path.'#13#10' Recommend use a diffrent disk to ba' +
            'ckup data. '#13#10
          Anchors = [akTop, akRight]
          ImeName = #28857'['#24320#22987#31243#24207']'#25110'Ctrl+Alt+W'#21551#21160#19975#33021#20116#31508
          TabOrder = 1
          Text = '1433'
          OnChange = seSocketPortChange
        end
        object cbbDBAuthentication: TComboBox
          Left = 99
          Top = 41
          Width = 310
          Height = 21
          Style = csDropDownList
          Anchors = [akLeft, akTop, akRight]
          ItemHeight = 13
          ItemIndex = 1
          TabOrder = 2
          Text = 'SQL Server Authentication'
          OnChange = cbbDBAuthenticationChange
          Items.Strings = (
            'Windows Authentication'
            'SQL Server Authentication')
        end
        object edtDBLoginName: TEdit
          Left = 99
          Top = 70
          Width = 310
          Height = 21
          Hint = 
            #13#10' Backup data store path.'#13#10' Recommend use a diffrent disk to ba' +
            'ckup data. '#13#10
          Anchors = [akLeft, akTop, akRight]
          ImeName = #28857'['#24320#22987#31243#24207']'#25110'Ctrl+Alt+W'#21551#21160#19975#33021#20116#31508
          TabOrder = 3
          OnChange = seSocketPortChange
        end
        object edtDBPassword: TEdit
          Left = 99
          Top = 99
          Width = 310
          Height = 21
          Hint = 
            #13#10' Backup data store path.'#13#10' Recommend use a diffrent disk to ba' +
            'ckup data. '#13#10
          Anchors = [akLeft, akTop, akRight]
          ImeName = #28857'['#24320#22987#31243#24207']'#25110'Ctrl+Alt+W'#21551#21160#19975#33021#20116#31508
          PasswordChar = '#'
          TabOrder = 4
          OnChange = seSocketPortChange
        end
        object cbbDBName: TComboBox
          Left = 99
          Top = 128
          Width = 310
          Height = 21
          Anchors = [akLeft, akTop, akRight]
          ItemHeight = 13
          TabOrder = 5
          OnChange = seSocketPortChange
          OnDropDown = cbbDBNameDropDown
        end
        object btnTestCon: TButton
          Left = 312
          Top = 157
          Width = 97
          Height = 23
          Anchors = [akTop, akRight]
          Caption = 'Test Connecttion'
          TabOrder = 6
          OnClick = btnTestConClick
        end
        object chkConnectDB: TCheckBox
          Left = 99
          Top = 157
          Width = 118
          Height = 17
          Caption = 'Connect Database'
          TabOrder = 7
          OnClick = seSocketPortChange
        end
      end
      object tsLog: TTabSheet
        Caption = 'Log'
        ImageIndex = 2
        object cbbLogType: TComboBox
          Left = 8
          Top = 12
          Width = 145
          Height = 21
          Style = csDropDownList
          ItemHeight = 13
          TabOrder = 0
          OnChange = cbbLogTypeChange
          Items.Strings = (
            'File'
            'Desktop'
            'Socket')
        end
        object chkLogInfo: TCheckBox
          Left = 24
          Top = 44
          Width = 97
          Height = 17
          Caption = 'Information'
          TabOrder = 1
          OnClick = seSocketPortChange
        end
        object chkLogSucc: TCheckBox
          Left = 24
          Top = 69
          Width = 97
          Height = 17
          Caption = 'Success'
          TabOrder = 2
          OnClick = seSocketPortChange
        end
        object chkLogWarn: TCheckBox
          Left = 24
          Top = 94
          Width = 97
          Height = 17
          Caption = 'Warn'
          TabOrder = 3
          OnClick = seSocketPortChange
        end
        object chkLogError: TCheckBox
          Left = 24
          Top = 119
          Width = 97
          Height = 17
          Caption = 'Error'
          TabOrder = 4
          OnClick = seSocketPortChange
        end
        object chkLogDebug: TCheckBox
          Left = 24
          Top = 144
          Width = 97
          Height = 17
          Caption = 'Debug'
          TabOrder = 5
          OnClick = seSocketPortChange
        end
      end
    end
  end
end
