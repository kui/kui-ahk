;DebugMode := True
DebugMode := False

SetKeyDelay(0)

; マウス座標をスクリーン全体の絶対座標で取得するように設定
; デフォルトだとアクティブなモニターの相対座標になるため実装が複雑になる
CoordMode("Mouse", "Screen")

; グローバル変数
global LastImeStatus := -1

; IME状態の定期チェック（500msごと）
; Pollingではなくイベント駆動型が望ましいが、アクティブウィンドウの変更をフックして
; さらにアクティブウィンドウ内でもIME制御ウィンドウを持つコンポーネントにフォーカスが当たってるか
; 確認し、さらにその中でIMEの変化まで制御するとなるとかなり複雑になるため、ここでは簡易的にポーリングで実装する。
SetTimer(CheckAndUpdateImeStatus, 500)

; IME状態をチェックして更新
CheckAndUpdateImeStatus() {
    global LastImeStatus
    local currentStatus := ImeGet()

    if (currentStatus != LastImeStatus) {
        LastImeStatus := currentStatus
        UpdateMouseIndicatorStatus(currentStatus)
    }
}

; 現在のIME状態を取得
ImeGet(windowTitle := "A") {
    local hwnd := WinExist(windowTitle)
    if WinActive(windowTitle) {
        local ptrSize := A_PtrSize ? A_PtrSize : 4
        local cbSize := 4 + 4 + (ptrSize * 6) + 16
        local stGTI := Buffer(cbSize, 0)
        NumPut("uint", cbSize, stGTI.Ptr, 0)
        hwnd := DllCall("GetGUIThreadInfo", "UInt", 0, "UInt", stGTI.Ptr)
            ? NumGet(stGTI.Ptr, 8 + ptrSize, "UInt") : hwnd
    }
    local result := DllCall("SendMessage",
        "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hwnd),
        "UInt", 0x0283, ;Message : WM_IME_CONTROL
        "Int", 0x005,   ;wParam  : IMC_GETOPENSTATUS
        "Int", 0)       ;lParam  : 0
    return result
}

ImeSet(status, windowTitle := "A") {
    local hwnd := WinExist(windowTitle)
    if WinActive(windowTitle) {
        local ptrSize := A_PtrSize ? A_PtrSize : 4
        local cbSize := 4 + 4 + (ptrSize * 6) + 16
        local stGTI := Buffer(cbSize, 0)
        NumPut("uint", cbSize, stGTI.Ptr, 0)
        hwnd := DllCall("GetGUIThreadInfo", "UInt", 0, "UInt", stGTI.Ptr)
            ? NumGet(stGTI.Ptr, 8 + ptrSize, "UInt") : hwnd
    }
    local result := DllCall("SendMessage",
        "UInt", DllCall("imm32\ImmGetDefaultIMEWnd", "UInt", hwnd),
        "UInt", 0x0283, ;Message : WM_IME_CONTROL
        "Int", 0x006,   ;wParam  : IMC_SETOPENSTATUS
        "Int", status)  ;lParam  : 0 or 1
    ShowImeStatus(status)

    ; マウスカーソル近くのインジケーターも更新
    global LastImeStatus := status
    UpdateMouseIndicatorStatus(status)

    return result
}

; IMEステータスを画面中央に表示
ShowImeStatus(status) {
    ; 既存のGUIを破棄
    try {
        if (IsSet(ImeGuiList)) {
            for guiItem in ImeGuiList {
                guiItem.Destroy()
            }
        }
    }

    ; 各モニターにGUIを作成して表示
    global ImeGuiList := []
    local monitorCount := MonitorGetCount()

    loop monitorCount {
        local monitorIndex := A_Index
        local monLeft, monTop, monRight, monBottom
        MonitorGetWorkArea(monitorIndex, &monLeft, &monTop, &monRight, &monBottom)

        ; 新しいGUI（中央表示用）を作成
        local imeGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        imeGui.BackColor := status ? "0x4CAF50" : "0x2196F3"
        imeGui.SetFont("s48 bold cWhite", "メイリオ")

        local statusText := status ? "あ" : "_A"
        imeGui.Add("Text", "Center w120 h80", statusText)

        ; GUIのサイズを取得するため一旦表示
        imeGui.Show("AutoSize Hide")
        local guiWidth, guiHeight
        imeGui.GetPos(, , &guiWidth, &guiHeight)

        ; モニターの中央座標を計算
        local centerX := monLeft + (monRight - monLeft - guiWidth) // 2
        local centerY := monTop + (monBottom - monTop - guiHeight) // 2

        imeGui.Show("x" . centerX . " y" . centerY . " NoActivate")
        ImeGuiList.Push(imeGui)
    }

    ; 1秒後にすべてのGUIを破棄
    SetTimer(() => DestroyAllImeGui(), -1000)
}

; すべてのIME GUIを破棄
DestroyAllImeGui() {
    global ImeGuiList
    try {
        if (IsSet(ImeGuiList)) {
            for guiItem in ImeGuiList {
                guiItem.Destroy()
            }
            ImeGuiList := []
        }
    }
}

; マウス座標からモニター番号を取得
MonitorFromPoint(x, y) {
    global DebugMode
    local debugMsg := ""
    if (DebugMode) {
        debugMsg := "Checking monitors for point (" . x . ", " . y . "):`n"
    }

    loop MonitorGetCount() {
        local monLeft, monTop, monRight, monBottom
        MonitorGet(A_Index, &monLeft, &monTop, &monRight, &monBottom)

        if (DebugMode) {
            debugMsg .= "Monitor " . A_Index . ": L=" . monLeft . " T=" . monTop . " R=" . monRight . " B=" . monBottom
            if (x >= monLeft && x < monRight && y >= monTop && y < monBottom) {
                debugMsg .= " [MATCH]`n"
            } else {
                debugMsg .= "`n"
            }
        }

        if (x >= monLeft && x < monRight && y >= monTop && y < monBottom) {
            if (DebugMode) {
                ToolTip(debugMsg)
                SetTimer(() => ToolTip(), -3000)
            }
            return A_Index
        }
    }

    if (DebugMode) {
        debugMsg .= "No match found, returning 1"
        ToolTip(debugMsg)
        SetTimer(() => ToolTip(), -3000)
    }
    return 1  ; デフォルトはプライマリモニター
}

; マウスカーソル近くのインジケーターをIME状態に応じて更新
UpdateMouseIndicatorStatus(status) {
    if (status) {
        ; 日本語入力モード: インジケーターを表示してマウス追従開始
        try {
            ImeMouseGui.Destroy()
        }

        global ImeMouseGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        ImeMouseGui.BackColor := "0x4CAF50"
        ImeMouseGui.SetFont("s20 bold cWhite", "メイリオ")
        ImeMouseGui.Add("Text", "Center w50 h35", "あ")

        ; 初期位置を設定してから表示
        UpdateMouseIndicatorPosition()

        ; マウス位置更新タイマーを開始
        SetTimer(UpdateMouseIndicatorPosition, 30)
    } else {
        ; 英数モード: インジケーターを削除してタイマー停止
        try {
            ImeMouseGui.Destroy()
        }

        ; マウス位置更新タイマーを停止
        SetTimer(UpdateMouseIndicatorPosition, 0)
    }
}

; マウスカーソル近くのインジケーター位置だけを更新
UpdateMouseIndicatorPosition() {
    try {
        if (IsSet(ImeMouseGui)) {
            local mouseX, mouseY
            MouseGetPos(&mouseX, &mouseY)
            ; マウスカーソルがどのモニターにあるかを判定
            local monitorIndex := MonitorFromPoint(mouseX, mouseY)
            local monLeft, monTop, monRight, monBottom
            MonitorGet(monitorIndex, &monLeft, &monTop, &monRight, &monBottom)

            ; インジケーターの表示位置を計算（マウスから+20ピクセルオフセット）
            local indicatorX := mouseX + 20
            local indicatorY := mouseY + 20

            ; モニターの境界内に収める
            ; GUIのサイズを考慮（おおよそ幅50、高さ35）
            if (indicatorX + 50 > monRight)
                indicatorX := monRight - 50
            if (indicatorY + 35 > monBottom)
                indicatorY := monBottom - 35
            if (indicatorX < monLeft)
                indicatorX := monLeft
            if (indicatorY < monTop)
                indicatorY := monTop

            ImeMouseGui.Show("x" . indicatorX . " y" . indicatorY . " AutoSize NoActivate")
        }
    }
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