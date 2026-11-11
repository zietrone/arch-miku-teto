--  ╭──────────────────────────────────────────────────────────╮
--  │  Hyprland · Miku (ミク) / Kasane Teto (テト) modes          │
--  │  palette: theme/current.lua  (switch: desktop-mode)       │
--  │  Shell/bar/launcher/lockscreen: DankMaterialShell (DMS)   │
--  ╰──────────────────────────────────────────────────────────╯

-- DMS-generated includes (outputs/cursor/window rules set from DMS settings).
-- pcall so a missing file never breaks the session.
local function try_require(mod)
    local ok, err = pcall(require, mod)
    if not ok and not tostring(err):find("not found") then
        hl.notification.create({ text = "hyprland.lua: " .. mod .. ": " .. tostring(err) })
    end
end

-----------------
---- PALETTE ----
-----------------

-- theme/current.lua -> miku.lua or teto.lua, switched by ~/.local/bin/desktop-mode
-- (or by picking "Hyprland · Teto" / "Hyprland · Miku" on the login screen).
local pal = {   -- Miku fallback if theme/current.lua is missing
    primary = "39c5bb", deep = "137a7f", light = "86cecb", accent = "e12885",
    accent2 = "ff5c8a", outline = "3d6066", bg = "0b1416", cursor = "miku-cursor-linux",
}
package.loaded["theme.current"] = nil
do
    local ok, p = pcall(require, "theme.current")
    if ok and type(p) == "table" then pal = p end
end

------------------
---- MONITORS ----
------------------

hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
try_require("dms.outputs")

---------------------
---- MY PROGRAMS ----
---------------------

local terminal    = "kitty"
local fileManager = "nautilus"
local dms         = "dms ipc call "

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    -- If DMS was already started by systemd (uwsm session), don't start a second copy
    hl.exec_cmd("systemctl --user is-active -q dms || dms run")
    hl.exec_cmd("hyprctl setcursor " .. pal.cursor .. " 24")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

hl.env("TERMINAL", "kitty")   -- default terminal for apps/scripts that honour $TERMINAL
hl.env("XCURSOR_THEME", pal.cursor)
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-----------------------
---- LOOK AND FEEL ----
-----------------------

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 8,

        border_size = 2,

        col = {
            -- signature twin-tail gradient (Miku teal → aqua → pink · Teto red → rose → gold)
            active_border   = { colors = { "rgb(" .. pal.primary .. ")", "rgb(" .. pal.light .. ")", "rgb(" .. pal.accent .. ")" }, angle = 45 },
            inactive_border = "rgba(" .. pal.outline .. "aa)",
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 14,
        rounding_power = 2.5,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,    -- opaque: readable + no blur pass behind every window

        dim_inactive = true,
        dim_strength = 0.06,

        shadow = {
            enabled      = true,
            range        = 14,
            render_power = 3,
            offset       = "0 5",
            color        = "rgba(" .. pal.primary .. "38)",   -- soft glow on the focused window
            color_inactive = "rgba(00000070)",
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            noise             = 0.02,
            contrast          = 1.0,
            brightness        = 0.9,
            vibrancy          = 0.25,
            vibrancy_darkness = 0.2,
            popups            = true,
            new_optimizations = true,
        },
    },

    group = {
        col = {
            border_active   = "rgb(" .. pal.primary .. ")",
            border_inactive = "rgb(" .. pal.outline .. ")",
        },
        groupbar = {
            col = {
                active   = "rgb(" .. pal.deep .. ")",
                inactive = "rgb(" .. pal.bg .. ")",
            },
        },
    },

    animations = {
        enabled = true,
    },
})

-- Bouncy "idol stage" animations
hl.curve("mikuPop",      { type = "bezier", points = { {0.34, 1.56}, {0.64, 1}  } })
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},    {0.32, 1}  } })
hl.curve("almostLinear", { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}  } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},       {1, 1}     } })
hl.curve("quick",        { type = "bezier", points = { {0.15, 0},    {0.1, 1}   } })
hl.curve("bounce",       { type = "spring", mass = 1, stiffness = 420, dampening = 34 })  -- snappy, tiny overshoot

-- speed = duration in 100ms units (lower = faster)
hl.animation({ leaf = "global",      enabled = true, speed = 6,    bezier = "default" })
hl.animation({ leaf = "windows",     enabled = true, speed = 3,    spring = "bounce" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 2.6,  bezier = "mikuPop",      style = "popin 85%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 1.2,  bezier = "linear",       style = "popin 85%" })
hl.animation({ leaf = "border",      enabled = true, speed = 3,    bezier = "easeOutQuint" })
-- rotating gradient off: a looping border repaints the screen every frame forever
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "fade",        enabled = true, speed = 2,    bezier = "quick" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 2.4,  bezier = "mikuPop",      style = "slide" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 1.2,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 2.8,  bezier = "easeOutQuint", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.8, bezier = "mikuPop",  style = "slidevert" })

hl.config({
    dwindle = { preserve_split = true },
    master  = { new_status = "master" },
})

----------------
----  MISC  ----
----------------

hl.config({
    misc = {
        force_default_wallpaper = 0,      -- DMS draws the wallpaper
        disable_hyprland_logo   = true,
        background_color        = 0xff0b1416,
    },
})

---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout  = "de",
        kb_model   = "pc105",
        kb_options = "terminate:ctrl_alt_bksp",
        numlock_by_default = true,

        follow_mouse = 1,
        sensitivity  = 0,
        accel_profile = "flat",

        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

---------------------
---- KEYBINDINGS ----
---------------------
-- Mirrors the niri/DMS binds so both sessions feel the same.

local mod = "SUPER"

hl.bind(mod .. " + T",       hl.dsp.exec_cmd(terminal))
hl.bind(mod .. " + E",       hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + Q",       hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

-- DMS shell
hl.bind(mod .. " + space",   hl.dsp.exec_cmd(dms .. "spotlight toggle"))
hl.bind(mod .. " + V",       hl.dsp.exec_cmd(dms .. "clipboard toggle"))
hl.bind(mod .. " + M",       hl.dsp.exec_cmd(dms .. "processlist focusOrToggle"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd(dms .. "processlist focusOrToggle"))
hl.bind(mod .. " + X",       hl.dsp.exec_cmd(dms .. "powermenu toggle"))
hl.bind(mod .. " + comma",   hl.dsp.exec_cmd(dms .. "settings focusOrToggle"))
hl.bind(mod .. " + Y",       hl.dsp.exec_cmd(dms .. "dankdash wallpaper"))
hl.bind(mod .. " + N",       hl.dsp.exec_cmd(dms .. "notifications toggle"))
hl.bind(mod .. " + SHIFT + N", hl.dsp.exec_cmd(dms .. "notepad toggle"))
hl.bind(mod .. " + ALT + L", hl.dsp.exec_cmd(dms .. "lock lock"))

-- Windows
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + SHIFT + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P",         hl.dsp.window.pseudo())
hl.bind(mod .. " + J",         hl.dsp.layout("togglesplit"))

-- Focus / move (arrows + vim keys)
local dirs = { left = "left", right = "right", up = "up", down = "down", H = "left", L = "right", K = "up" }
for key, d in pairs(dirs) do
    hl.bind(mod .. " + " .. key,             hl.dsp.focus({ direction = d }))
    hl.bind(mod .. " + SHIFT + " .. key,     hl.dsp.window.move({ direction = d }))
end
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

-- Workspaces 1–10
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + U",          hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + I",          hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + Page_Down",  hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + Page_Up",    hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Scratchpad
hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("miku"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:miku" }))

-- Mouse drag / resize
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Screenshots (needs grim, slurp, wl-clipboard)
local shotdir = "$HOME/Pictures/Screenshots/Screenshot from $(date +'%Y-%m-%d %H-%M-%S').png"
hl.bind("Print",         hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | tee \"" .. shotdir .. "\" | wl-copy"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grim - | tee \"" .. shotdir .. "\" | wl-copy"))

-- Media keys via DMS (same OSD as on niri)
local lr = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(dms .. "audio increment 3"), lr)
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(dms .. "audio decrement 3"), lr)
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(dms .. "audio mute"),        { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(dms .. "audio micmute"),     { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(dms .. "brightness increment 5 ''"), lr)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(dms .. "brightness decrement 5 ''"), lr)
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(dms .. "mpris playPause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(dms .. "mpris playPause"), { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(dms .. "mpris next"),      { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(dms .. "mpris previous"),  { locked = true })

--------------------------------
---- WINDOWS AND LAYERS ----
--------------------------------

hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({
    name  = "floating-utilities",
    match = { class = "^(org\\.gnome\\.Calculator|blueman-manager|pavucontrol|nm-connection-editor|xdg-desktop-portal.*|org\\.quickshell|com\\.danklinux\\.dms|zoom)$" },
    float = true,
    center = true,
})

hl.window_rule({
    name  = "pip",
    match = { title = "^Picture-in-Picture$" },
    float = true,
    pin   = true,
})

-- Frosted-glass DMS bar/panels
hl.layer_rule({
    name  = "dms-blur",
    match = { namespace = "^(quickshell|dms.*)$" },
    blur  = true,
    ignore_alpha = 0.3,
})

try_require("dms.cursor")
try_require("dms.windowrules")
