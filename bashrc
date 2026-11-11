#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
export PATH="$HOME/.local/bin:$PATH"

# ── Miku / Teto prompt ♪ ──
# Follows ~/.config/desktop-mode (miku|teto, set by desktop-mode / the login screen).
# Every prompt checks the mode, so already-open shells switch too.
# path colours (miku/teto): ~ pink/gold · / soft pink/orange · parent dirs aqua/rose · current dir bold teal/red
# The path is stored in _MIKU_PATH (raw escape bytes, \001/\002 = readline's \[ \])
# and only referenced from PS1, so odd dir names like $(cmd) are never executed.
_MIKU_MODE=''
_miku_colours() {  # sets _C_T (main) _C_A (light) _C_P (accent) _C_S (soft accent) as r;g;b
    if [[ $_MIKU_MODE == teto ]]; then
        _C_T='224;64;91' _C_A='255;143;163' _C_P='242;178;92' _C_S='255;122;89' _MIKU_ID=14696539  # 0xe0405b
    else
        _C_T='57;197;187' _C_A='134;206;203' _C_P='225;40;133' _C_S='255;92;138' _MIKU_ID=3786171  # 0x39c5bb
    fi
    local e=$'\001\e[38;2;' z=$'m\002'
    _MT="$e$_C_T$z" _MA="$e$_C_A$z" _MP="$e$_C_P$z" _MS="$e$_C_S$z"
}
_miku_path() {
    local t=$_MT a=$_MA p=$_MP s=$_MS
    local b=$'\001\e[1m\002' r=$'\001\e[0m\002'
    local path=$PWD out=''
    if [[ $path == "$HOME" ]]; then _MIKU_PATH="${b}${p}~${r}"; return
    elif [[ $path == / ]]; then _MIKU_PATH="${b}${s}/${r}"; return
    elif [[ $path == "$HOME"/* ]]; then out="${p}~"; path=${path#"$HOME"/}
    else path=${path#/}
    fi
    local IFS=/; local -a parts; read -ra parts <<< "$path"; unset IFS
    local n=${#parts[@]} i=0
    if (( n > 4 )); then out="${a}…"; i=$((n - 3)); fi
    for (( ; i < n; i++ )); do
        out+="${s}/"
        if (( i == n - 1 )); then out+="${b}${t}${parts[i]}${r}"; else out+="${a}${parts[i]}"; fi
    done
    _MIKU_PATH=$out
}
_MARCH=$'\001\e[38;2;23;147;209m\002'  # Arch blue #1793d1
PS1='${_MIKU_ROW0}${_MP}♪ ${_MARCH} ${_MT}\u${_MA}@\h ${_MIKU_PATH} ${_MP}❯\[\e[0m\] '

# mini pixel Miku (with a leek) / Teto (with a baguette) at the start of the prompt line.
# kitty only: drawn with kitty's graphics protocol + unicode placeholders, so the
# picture is made of real text cells and scrolls / wraps like normal text.
_MIKU_ROW0='' _MIKU_TX='' _MIKU_CELL=''
_miku_pic_setup() {
    _MIKU_ROW0='' _MIKU_TX=''
    [[ $TERM == xterm-kitty && -z $TMUX && -z $SSH_TTY ]] || return
    local ch cw cols
    if [[ -z $_MIKU_CELL ]]; then
        # ask kitty for the cell size in pixels: reply is ESC [ 6 ; H ; W t
        IFS=';' read -rs -d t -t 0.3 -p $'\e[16t' _ ch cw < /dev/tty || return
        _MIKU_CELL="${cw}x${ch}"
    fi
    cw=${_MIKU_CELL%x*} ch=${_MIKU_CELL#*x}
    local png=~/.cache/mini-miku/$_MIKU_MODE-${cw}x${ch}.png
    if [[ ! -s $png || ! -s $png.cols ]]; then
        mkdir -p ~/.cache/mini-miku
        mini-miku-png "$cw" "$ch" 1 "$png" "$_MIKU_MODE" > "$png.cols" || return
    fi
    cols=$(<"$png.cols")
    # image id = the mode's main colour (_MIKU_ID); the placeholder's fg colour selects the image
    _MIKU_TX=$'\e_Ga=T,U=1,i='"$_MIKU_ID"',f=100,t=f,q=2,c='"$cols"',r=1;'"$(printf %s "$png" | base64 -w0)"$'\e\\'
    # the first cell carries row/column diacritics (U+0305 = 0); the rest continue the row
    local rest='' i
    for (( i = 1; i < cols; i++ )); do rest+=$'\U10EEEE'; done
    _MIKU_ROW0="$_MT"$'\U10EEEE̅̅'"$rest"$'\001\e[39m\002 '
}
_miku_mode_check() {
    local m=miku
    [[ -r ~/.config/desktop-mode ]] && m=$(<~/.config/desktop-mode)
    [[ $m == teto ]] || m=miku
    [[ $m == "$_MIKU_MODE" ]] && return
    _MIKU_MODE=$m
    _miku_colours
    _miku_pic_setup
}
_miku_prompt_cmd() {
    _miku_mode_check
    _miku_path
    # (re)send the image each prompt so it survives `clear` / ctrl+L
    [[ -n $_MIKU_TX ]] && printf '%s' "$_MIKU_TX"
}
PROMPT_COMMAND="_miku_prompt_cmd${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
alias ff='fastfetch'

# fastfetch: real picture in kitty, text-art elsewhere; follows the Miku/Teto mode
# (desktop-mode points ~/.config/fastfetch/config.jsonc at config-miku/config-teto.jsonc)
# The Miku picture is not part of the repo: put your own image at MIKU_PIC.
# Without it (or outside kitty) fastfetch shows the text-art from miku.txt / teto.txt.
MIKU_PIC=~/.config/fastfetch/images/miku.png
TETO_PIC=~/.config/fastfetch/images/teto-pixel.png
fastfetch() {
    local pic=$MIKU_PIC
    [[ $(<~/.config/desktop-mode) == teto ]] 2>/dev/null && pic=$TETO_PIC
    if [[ $TERM == xterm-kitty && -r $pic ]]; then
        command fastfetch --logo-type kitty-direct --logo "$pic" \
            --logo-width 34 --logo-height 17 --logo-padding-top 1 "$@"
    else
        command fastfetch "$@"
    fi
}
