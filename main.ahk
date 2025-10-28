;DebugMode := True
DebugMode := False

SetKeyDelay(0)

ImeSet(status, windowTitle := "A") {
    hwnd := WinExist(windowTitle)
    if WinActive(windowTitle) {
        ptrSize := A_PtrSize ? A_PtrSize : 4
        cbSize := 4 + 4 + (ptrSize * 6) + 16
        stGTI := Buffer(cbSize, 0)
        NumPut("uint", cbSize, stGTI.Ptr, 0)
        hwnd := DllCall("GetGUIThreadInfo", "UInt", 0, "UInt", stGTI.Ptr)
            ? NumGet(stGTI.Ptr, 8 + ptrSize, "UInt") : hwnd
    }
    result := DllCall("SendMessage",
        "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hwnd),
        "UInt", 0x0283, ;Message : WM_IME_CONTROL
        "Int", 0x006,   ;wParam  : IMC_SETOPENSTATUS
        "Int", status)  ;lParam  : 0 or 1
    ShowImeStatus(status)
    return result
}

; IMEステータスを画面中央に表示
ShowImeStatus(status) {
    ; 既存のGUIを破棄
    try {
        ImeGui.Destroy()
    }

    ; 新しいGUIを作成
    global ImeGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    ImeGui.BackColor := status ? "0x4CAF50" : "0x2196F3"
    ImeGui.SetFont("s48 bold cWhite", "メイリオ")

    statusText := status ? "あ" : "_A"
    ImeGui.Add("Text", "Center w120 h80", statusText)
    ImeGui.Show("AutoSize Center NoActivate")
    SetTimer(() => ImeGui.Destroy(), -1000)
}

; F18 Modifier Key Mappings
#HotIf GetKeyState("F18", "P")

; カーソル移動
h:: Send "{Left}"
j:: Send "{Down}"
k:: Send "{Up}"
l:: Send "{Right}"

; 削除
s:: Send "{Backspace}"
d:: Send "{Delete}"

; Ctrl + キャレット移動
^h:: Send "^{Left}"  ; 単語ジャンプ左
^l:: Send "^{Right}" ; 単語ジャンプ右
^j:: Send "{PgDn}"   ; ページダウン
^k:: Send "{PgUp}"   ; ページアップ

; Alt + キャレット移動
!h:: Send "{Home}"  ; 行頭へジャンプ
!l:: Send "{End}"   ; 行末へジャンプ
!j:: Send "^{End}"  ; 最下部へジャンプ
!k:: Send "^{Home}" ; 最上部へジャンプ

; 選択
a:: Send "+{Home}"  ; キャレット左から行頭までを選択
f:: Send "+{End}"   ; キャレット右から行末までを選択

; 編集
z:: Send "^z"       ; Undo
+z:: Send "^y"      ; Redo
x:: Send "^x"       ; 切り取り
c:: Send "^c"       ; コピー
v:: Send "^v"       ; 貼り付け

; IME切り替え
Space:: ImeSet(0)   ; 英数入力
+Space:: ImeSet(1)  ; 日本語入力

; ブラウザナビゲーション
[:: Send "{Browser_Back}"    ; ブラウザバック
]:: Send "{Browser_Forward}" ; ブラウザフォワード

; 未定義のキーを無効化（定義済みのホットキー以外）
b:: return
e:: return
g:: return
i:: return
m:: return
n:: return
o:: return
p:: return
q:: return
r:: return
t:: return
u:: return
w:: return
y:: return
0:: return
1:: return
2:: return
3:: return
4:: return
5:: return
6:: return
7:: return
8:: return
9:: return
-:: return
^:: return
\:: return
@:: return
SC027:: return  ; ; キー (セミコロン)
,:: return
.:: return
/:: return
F1:: return
F2:: return
F3:: return
F4:: return
F5:: return
F6:: return
F7:: return
F8:: return
F9:: return
F10:: return
F11:: return
F12:: return
Tab:: return
Enter:: return
Esc:: return
BackSpace:: return
Delete:: return
Home:: return
End:: return
PgUp:: return
PgDn:: return
Insert:: return
PrintScreen:: return
ScrollLock:: return
Pause:: return
Left:: return
Right:: return
Up:: return
Down:: return

#HotIf