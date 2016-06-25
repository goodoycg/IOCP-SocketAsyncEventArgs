object FmLogin: TFmLogin
  Left = 325
  Top = 230
  Width = 444
  Height = 158
  Caption = 'Login'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  PixelsPerInch = 96
  TextHeight = 13
  object pnl1: TPanel
    Left = 0
    Top = 0
    Width = 428
    Height = 90
    Align = alClient
    TabOrder = 0
    DesignSize = (
      428
      90)
    object lblServer: TLabel
      Left = 16
      Top = 16
      Width = 31
      Height = 13
      Caption = 'Server'
    end
    object lblPort: TLabel
      Left = 16
      Top = 57
      Width = 19
      Height = 13
      Caption = 'Port'
    end
    object edtServer: TEdit
      Left = 70
      Top = 16
      Width = 350
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 0
      Text = '127.0.0.1'
    end
    object edtPort: TEdit
      Left = 70
      Top = 56
      Width = 350
      Height = 21
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
      Text = '9999'
    end
  end
  object pnl2: TPanel
    Left = 0
    Top = 90
    Width = 428
    Height = 30
    Align = alBottom
    TabOrder = 1
    DesignSize = (
      428
      30)
    object btnLogin: TButton
      Left = 265
      Top = 4
      Width = 75
      Height = 23
      Anchors = [akTop, akRight]
      Caption = 'Login'
      Default = True
      TabOrder = 0
      OnClick = btnLoginClick
    end
    object btnCancel: TButton
      Left = 345
      Top = 4
      Width = 75
      Height = 23
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      TabOrder = 1
      OnClick = btnCancelClick
    end
  end
end
