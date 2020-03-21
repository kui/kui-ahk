; Load by main.ahk

IsCSpace = False
IsCX = False

EnableCSpace() {
    global IsCSpace = True
    ToolTip, Ctrl + Space,,, 10
}
DisableCSpace() {
    global IsCSpace = False
    ToolTip,,,, 10
}
EnableCX() {
    global IsCX = True
    ToolTip, Ctrl + Space,,, 11
}
DisableCX() {
    global IsCX = False
    ToolTip,,,, 11
}

MoveCarret(Keys) {
    global IsCSpace
    If (IsCSpace) {
        Send, +%Keys%
    } Else {
        Send, %Keys%
    }
}
EditText(Keys) {
    global IsCSpace
    Send, % Keys
    If (IsCSpace) {
        DisableCSpace()
    }
}

^n::MoveCarret("{Down}")
^p::MoveCarret("{Up}")
^f::MoveCarret("{Right}")
^b::MoveCarret("{Left}")
^e::MoveCarret("{End}")
^a::MoveCarret("{Home}")
^v::MoveCarret("{PgDn}")
!v::MoveCarret("{PgUp}")

^y::EditText("^v")
^w::EditText("^x")
!w::EditText("^c")
^k::
    Send, {ShiftDown}{End}
    Sleep, 100
    Send, ^x
    DisableCSpace()
    Return
^h::EditText("{BackSpace}")
^d::EditText("{Delete}")

^s::
    Send, ^f
    DisableCSpace()
    Return
!k::
    Send, ^w
    DisableCSpace()
    Return

^[::
    Send, {Esc}
    DisableCSpace()
    Return
^g::
    HasAnyOperation = False
    If (IsCSpace)
        DisableCSpace()
    If (IsCX)
        DisableCX()
    If (Not HasAnyOperation)
        Send, {Esc}
    Return

^Space::EnableCSpace()
^x::EnableCX()