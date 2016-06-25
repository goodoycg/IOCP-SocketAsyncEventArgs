unit ClientDefineUnit;

interface

uses
  Windows, Messages;

const
  {* 断开通知消息 *}
  WM_Disconnect = WM_User + 1000;
  {* 提示框Caption定义 *}
  CHint = 'Hint';
  CError = 'Error';
  CAsk = 'Confirm';

implementation

end.
