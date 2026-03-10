; グローバル変数
global LastImeStatus := -1
global LastMouseX := 0
global LastMouseY := 0
global CurrentMouseX := 0
global CurrentMouseY := 0

; 定数
global MOUSE_INDICATOR_OFFSET := 20
global MOUSE_MOVE_THRESHOLD := 500  ; マウス移動の閾値（ピクセル）
global MouseIndicatorSuppressed := false  ; タイピング時にインジケーターを非表示にするフラグ

; IME機能の初期化
InitIme() {
    ; マウス座標をスクリーン全体の絶対座標で取得するように設定
    ; デフォルトだとアクティブなモニターの相対座標になるため実装が複雑になる
    CoordMode("Mouse", "Screen")

    ; キー入力検出（タイピング時にマウスインジケーターを非表示にする）
    global KeyInputHook := InputHook("V")
    KeyInputHook.KeyOpt("{All}", "N")
    KeyInputHook.OnKeyDown := HideMouseIndicatorOnKeyDown
    KeyInputHook.Start()

    ; IME状態の定期チェックとマウス移動チェック（500msごと）
    ; Pollingではなくイベント駆動型が望ましいが、アクティブウィンドウの変更をフックして
    ; さらにアクティブウィンドウ内でもIME制御ウィンドウを持つコンポーネントにフォーカスが当たってるか確認し、
    ; さらにその中でIMEの変化まで制御するとなるとかなり複雑になるため、ここでは簡易的にポーリングで実装する。
    SetTimer(CheckAndUpdateImeStatus, 500)
}

; IME状態をチェックして更新、およびマウス移動チェック
CheckAndUpdateImeStatus() {
    global LastImeStatus, LastMouseX, LastMouseY, CurrentMouseX, CurrentMouseY

    local currentStatus := ImeGet()

    ; 現在のマウス座標を更新（すべての機能で共有）
    MouseGetPos(&CurrentMouseX, &CurrentMouseY)

    ; IME状態の変更チェック
    if (currentStatus != LastImeStatus) {
        LastImeStatus := currentStatus
        UpdateMouseIndicatorStatus(currentStatus)

        ; IME状態変更時はマウス位置をリセット（英字切替判定用）
        LastMouseX := CurrentMouseX
        LastMouseY := CurrentMouseY
    }

    ; 日本語入力モード時: マウス移動チェックとインジケーター更新
    if (LastImeStatus == 1) {
        ; マウス移動距離を計算（ユークリッド距離）
        local deltaX := CurrentMouseX - LastMouseX
        local deltaY := CurrentMouseY - LastMouseY
        local distance := Sqrt(deltaX * deltaX + deltaY * deltaY)

        if (distance > MOUSE_MOVE_THRESHOLD) {
            ; 閾値を超えた場合は英数モードに切り替え
            ; ImeSet() 内でインジケーターの破棄も行われる
            ImeSet(0)
            LastMouseX := CurrentMouseX
            LastMouseY := CurrentMouseY
        } else {
            ; 日本語モード継続中: インジケーター位置を追従
            UpdateMouseIndicatorPosition()
        }
    }
}

; IMEウィンドウハンドルを取得（ImeGet/ImeSetの共通処理）
GetImeHwnd(windowTitle := "A") {
    local hwnd := WinExist(windowTitle)
    if WinActive(windowTitle) {
        local cbSize := 4 + 4 + (A_PtrSize * 6) + 16
        local stGTI := Buffer(cbSize, 0)
        NumPut("uint", cbSize, stGTI.Ptr, 0)
        hwnd := DllCall("GetGUIThreadInfo", "UInt", 0, "Ptr", stGTI.Ptr)
            ? NumGet(stGTI.Ptr, 8 + A_PtrSize, "Ptr") : hwnd
    }
    return DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
}

; 現在のIME状態を取得（0: 英数, 1: 日本語）
ImeGet(windowTitle := "A") {
    local result := DllCall("SendMessage",
        "Ptr", GetImeHwnd(windowTitle),
        "UInt", 0x0283, ;Message : WM_IME_CONTROL
        "Ptr", 0x005,   ;wParam  : IMC_GETOPENSTATUS
        "Ptr", 0)       ;lParam  : 0
    return result ? 1 : 0
}

; IME状態を設定
ImeSet(status, windowTitle := "A") {
    global LastImeStatus, LastMouseX, LastMouseY, MouseIndicatorSuppressed

    MouseIndicatorSuppressed := false  ; 明示的なIME切替時にタイピング抑制をリセット

    local result := DllCall("SendMessage",
        "Ptr", GetImeHwnd(windowTitle),
        "UInt", 0x0283, ;Message : WM_IME_CONTROL
        "Ptr", 0x006,   ;wParam  : IMC_SETOPENSTATUS
        "Ptr", status)  ;lParam  : 0 or 1
    ShowImeStatus(status)

    ; マウスカーソル近くのインジケーターも更新
    LastImeStatus := status
    UpdateMouseIndicatorStatus(status)

    MouseGetPos(&LastMouseX, &LastMouseY)

    return result
}

; マウスカーソル近くのインジケーターをIME状態に応じて更新
UpdateMouseIndicatorStatus(status) {
    global MouseIndicatorSuppressed
    if (status && !MouseIndicatorSuppressed) {
        ; 日本語入力モード（タイピング抑制中でない場合）: インジケーターを表示
        try {
            ImeMouseGui.Destroy()
        }

        global ImeMouseGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
        ImeMouseGui.BackColor := "0x4CAF50"
        ImeMouseGui.SetFont("s20 bold cWhite", "メイリオ")
        ImeMouseGui.Add("Text", "Center w50 h35", "あ")

        ; 初期位置を設定してから表示
        UpdateMouseIndicatorPosition()
    } else {
        ; 英数モードまたはタイピング抑制中: インジケーターを削除
        try {
            ImeMouseGui.Destroy()
        }
    }
}

; マウスカーソル近くのインジケーター位置だけを更新
UpdateMouseIndicatorPosition() {
    global CurrentMouseX, CurrentMouseY, MouseIndicatorSuppressed
    if (MouseIndicatorSuppressed)
        return
    try {
        if (IsSet(ImeMouseGui)) {
            ; グローバルに管理されている現在のマウス座標を使用
            local mouseX := CurrentMouseX
            local mouseY := CurrentMouseY

            ; マウスカーソルがどのモニターにあるかを判定
            local monitorIndex := MonitorFromPoint(mouseX, mouseY)
            local monLeft, monTop, monRight, monBottom
            MonitorGet(monitorIndex, &monLeft, &monTop, &monRight, &monBottom)

            ; インジケーターの実際のサイズを取得
            local guiWidth, guiHeight
            ImeMouseGui.GetPos(, , &guiWidth, &guiHeight)

            ; 表示位置を決定
            ; デフォルトは右下（マウスの右下）
            local indicatorX := mouseX + MOUSE_INDICATOR_OFFSET
            local indicatorY := mouseY + MOUSE_INDICATOR_OFFSET

            ; 右端に近い場合は左側に表示
            if (indicatorX + guiWidth > monRight)
                indicatorX := mouseX - guiWidth - MOUSE_INDICATOR_OFFSET

            ; 下端に近い場合は上側に表示
            if (indicatorY + guiHeight > monBottom)
                indicatorY := mouseY - guiHeight - MOUSE_INDICATOR_OFFSET

            ImeMouseGui.Show("x" . indicatorX . " y" . indicatorY . " AutoSize NoActivate")
        }
    }
}

; キー入力時にマウスインジケーターを非表示にする
HideMouseIndicatorOnKeyDown(ih, vk, sc) {
    global MouseIndicatorSuppressed, LastImeStatus
    ; 修飾キー単体では非表示にしない
    if (vk >= 0x10 && vk <= 0x12)  ; Shift, Ctrl, Alt
        return
    if (vk == 0x5B || vk == 0x5C)  ; LWin, RWin
        return
    if (vk >= 0xA0 && vk <= 0xA5)  ; LShift, RShift, LCtrl, RCtrl, LAlt, RAlt
        return
    if (vk == 0x81)  ; F18（修飾キーとして使用）
        return
    if (LastImeStatus == 1 && !MouseIndicatorSuppressed) {
        MouseIndicatorSuppressed := true
        try {
            ImeMouseGui.Destroy()
        }
    }
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
    loop MonitorGetCount() {
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
