unit DrawListViewProgress;

interface

uses CommCtrl, ComCtrls, Graphics, Windows, SysUtils;

type
  TProcessStyle = (psSolid, psLine);

procedure DrawSubItem(LV: TListView; Item: TListItem; SubItem: Integer;
  Position: Single; Max: Integer; Style: TProcessStyle; IsShowProgress: Boolean;
  DrawColor: TColor = $00005B00; FrameColor: TColor = $00002F00);

implementation

procedure DrawSubItem(LV: TListView; Item: TListItem; SubItem: Integer;
  Position: Single; Max: Integer; Style: TProcessStyle; IsShowProgress: Boolean;
  DrawColor: TColor = $00005B00; FrameColor: TColor = $00002F00);  
  
  function GetItemRect(LV_Handle, iItem, iSubItem: Integer): TRect; //获取SubItem的区域
  var
    Rect: TRect;
  begin
    ListView_GetSubItemRect(LV_Handle, iItem, iSubItem, LVIR_LABEL, @Rect);
    Result := Rect;
  end;
var
  PaintRect, r: TRect;
  i, iWidth, x, y: integer;
  S: string;
begin
  try
    with lv do
    begin
      PaintRect := GetItemRect(LV.Handle, Item.Index, SubItem);
      r := PaintRect;
      //这一段是算出百分比
      if Position >= Max then
        Position := 100
      else
      begin
        if Position <= 0 then
          Position := 0
        else
          Position := Round((Position / Max) * 100);
      end; 
      if (Position = 0) and (not IsShowProgress) then
      begin 
        //如果是百分比是0，就直接显示空白
        Canvas.FillRect(r);
      end
      else
      begin
        if Position = Round(Position) then
          S := Format('%d%%', [Round(Position)])
        else
          S := FormatFloat('#0.0', Position);
        with PaintRect do
        begin
          x := Left + (Right - Left + 1 - Canvas.TextWidth(S)) div 2;
          y := Top + (Bottom - Top + 1 - Canvas.TextHeight(S)) div 2;
        end;
        //先直充背景色
        Canvas.FillRect(r);
        //画一个外框
        InflateRect(r, -2, -2);
        Canvas.Brush.Color := FrameColor; //$00002F00;
        Canvas.FrameRect(R);
        InflateRect(r, -1, -1);
        InflateRect(r, -1, -1);
        //根据百分比算出要画的进度条内容宽度
        SetBkMode(Canvas.handle, TRANSPARENT);
        Canvas.Brush.Color := DrawColor;
        Canvas.Brush.Style := bsClear;
        //Canvas.Font.Color := DrawColor;
        SetTextColor(Canvas.Handle, DrawColor);
        Canvas.TextOut(x, y, S);
        iWidth := R.Right - Round((R.Right - r.Left) * ((100 - Position) / 100));
        case Style of
          psSolid: //进度条类型，实心填充
          begin
            Canvas.Brush.Color := DrawColor;
            r.Right := iWidth;
            Canvas.FillRect(r);
          end;
          psLine: //进度条类型，竖线填充
          begin
            i := r.Left;
            R.Right := iWidth;
            while i < iWidth do
            begin
              Canvas.Pen.Color := Color;
              Canvas.MoveTo(i, r.Top);
              Canvas.Pen.Color := DrawColor;
              canvas.LineTo(i, r.Bottom);
              Inc(i, 3);
            end;
          end;
        end;
        //画好了进度条后，现在要做的就是显示进度数字了
        Canvas.Brush.Style := bsClear;

        SetTextColor(Canvas.Handle, clWhite);
        Canvas.TextRect(r, x, y, S);
      end;
      //进度条全部画完，把颜色设置成默认色了
      Canvas.Brush.Color := Color;
    end;
  except
  end;
end;

end.
