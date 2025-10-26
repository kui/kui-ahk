; Load by main.ahk

IsCSpace := False
IsCX := False

EnableCSpace() {
    global IsCSpace := True
    ToolTip("Ctrl + Space",,, 10)
}
DisableCSpace() {
    global IsCSpace := False
    ToolTip(,,, 10)
}
EnableCX() {
    global IsCX := True
    ToolTip("Ctrl + X",,, 11)
}
DisableCX() {
    global IsCX := False
    ToolTip(,,, 11)
}

MoveCarret(Keys) {
    global IsCSpace
    If (IsCSpace) {
        Send("+" Keys)
    } Else {
        Send(Keys)
    }
}
EditText(Keys) {
    global IsCSpace
    Send(Keys)
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
!f::MoveCarret("^{Right}")
!b::MoveCarret("^{Left}")

^y::EditText("^v")
^w::EditText("^x")
!w::EditText("^c")
^k:: {
    Send("{ShiftDown}{End}")
    Sleep(100)
    Send("^x")
    DisableCSpace()
}
^h::EditText("{BackSpace}")
^d::EditText("{Delete}")

^s:: {
    Send("^f")
    DisableCSpace()
}
!k:: {
    Send("^w")
    DisableCSpace()
}

^c:: {
    If (IsCX) {
        WinClose("A")
        DisableCX()
    } Else {
        Send("^c")
    }
}
k:: {
    If (IsCX) {
        Send("^w")
        DisableCX()
    } Else {
        Send("k")
    }
}
h:: {
    If (IsCX) {
        Send("^a")
        DisableCX()
    } Else {
        Send("h")
    }
}

^[:: {
    Send("{Esc}")
    DisableCSpace()
}
^g:: {
    HasAnyOperation := False
    If (IsCSpace) {
        DisableCSpace()
        HasAnyOperation := True
    }
    If (IsCX) {
        DisableCX()
        HasAnyOperation := True
    }
    If (Not HasAnyOperation) {
        Send("{Esc}")
    }
}

^Space::EnableCSpace()
^x::EnableCX()

