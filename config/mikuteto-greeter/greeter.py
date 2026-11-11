#!/usr/bin/env python3
"""mikuteto-greeter: a small LightDM greeter with a Miku | Teto mode switch.

Logging in starts the "<compositor>-<mode>" session (e.g. niri-teto), whose wrapper
runs ~/.local/bin/desktop-mode to theme the desktop before the compositor starts.
The greeter opens in the user's last mode, read from /var/lib/desktop-mode/<user>
(written by desktop-mode) or, failing that, from the last session's name.

  mikuteto-greeter            run under LightDM
  mikuteto-greeter --demo     windowed preview with fake users, no LightDM needed
"""
import os
import sys
import time

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

DEMO = "--demo" in sys.argv
HERE = os.path.dirname(os.path.realpath(__file__))
MODE_DIR = "/var/lib/desktop-mode"

MODES = {
    "miku": {
        "label": "♪ Miku", "cursor": "miku-cursor-linux",
        "wallpaper": "/usr/share/backgrounds/miku/miku-01.png",
        "accent": "#39c5bb", "accent2": "#e12885", "deep": "#137a7f",
        "panel": "rgba(11, 20, 22, 0.82)", "field": "rgba(20, 35, 42, 0.9)",
        "text": "#e0f4f2", "dim": "#86cecb", "outline": "#3d6066", "on_accent": "#002522",
    },
    "teto": {
        "label": "♪ Teto", "cursor": "teto-cursor-linux",
        "wallpaper": "/usr/share/backgrounds/teto/teto-01.png",
        "accent": "#e0405b", "accent2": "#f2b25c", "deep": "#8f1d33",
        "panel": "rgba(22, 11, 14, 0.82)", "field": "rgba(42, 20, 26, 0.9)",
        "text": "#f8e6ea", "dim": "#ff8fa3", "outline": "#66404a", "on_accent": "#2a0009",
    },
}
COMPOSITORS = [("niri", "Niri"), ("hyprland", "Hyprland")]


# ── LightDM access (real or fake) ──────────────────────────────────────────
class FakeUser:
    def __init__(self, name, session):
        self.name, self.session = name, session
    def get_name(self): return self.name
    def get_display_name(self): return self.name
    def get_session(self): return self.session


class Backend:
    """Thin wrapper so --demo can run without a LightDM daemon."""

    def __init__(self, on_prompt, on_message, on_complete):
        self.pending = None
        if DEMO:
            self.greeter = None
            self.users = [FakeUser("user", "hyprland-miku")]
            self.session_keys = {"niri", "hyprland", "niri-miku", "niri-teto", "hyprland-miku", "hyprland-teto"}
            self.hostname = "demo-host"
            self._on_complete = on_complete
            return
        gi.require_version("LightDM", "1")
        from gi.repository import LightDM
        self.LightDM = LightDM
        self.greeter = LightDM.Greeter()
        self.greeter.connect("show-prompt", lambda g, text, kind: on_prompt(text, kind))
        self.greeter.connect("show-message", lambda g, text, kind: on_message(text))
        self.greeter.connect("authentication-complete", lambda g: on_complete(g.get_is_authenticated()))
        self.users = list(LightDM.UserList.get_instance().get_users())
        self.session_keys = {s.get_key() for s in LightDM.get_sessions()}
        self.hostname = LightDM.get_hostname() or ""

    def connect(self):
        if not DEMO:
            self.greeter.connect_to_daemon_sync()

    def default_user(self):
        hint = None if DEMO else self.greeter.get_select_user_hint()
        return hint or (self.users[0].get_name() if self.users else "")

    def login(self, user, password):
        if DEMO:
            GLib.timeout_add(400, self._on_complete, password == "demo")
            return
        self.pending = password
        if self.greeter.get_in_authentication():
            self.greeter.cancel_authentication()
        self.greeter.authenticate(user)

    def answer_prompt(self):
        if self.pending is not None:
            text, self.pending = self.pending, None
            self.greeter.respond(text)
            return True
        return False

    def start_session(self, key):
        if DEMO:
            print("would start session:", key)
            Gtk.main_quit()
            return
        self.greeter.start_session_sync(key)

    def power(self, action):
        if DEMO:
            print("power:", action)
            return
        getattr(self.LightDM, action)()

    def can(self, action):
        return True if DEMO else getattr(self.LightDM, "get_can_" + action)()


# ── Mode memory ────────────────────────────────────────────────────────────
def last_mode(user, last_session):
    try:
        with open(os.path.join(MODE_DIR, user)) as f:
            mode = f.read().strip()
        if mode in MODES:
            return mode
    except OSError:
        pass
    for mode in MODES:
        if (last_session or "").endswith("-" + mode):
            return mode
    return "miku"


def last_compositor(last_session):
    s = (last_session or "").lower()
    for key, _ in COMPOSITORS:
        if s.startswith(key):
            return key
    return COMPOSITORS[0][0]


def css_for(mode):
    p = dict(MODES[mode])
    if not os.path.exists(p["wallpaper"]):    # --demo before teto-setup.sh copied it
        p["wallpaper"] = os.path.expanduser(f"~/Pictures/Wallpapers/{mode}-01.png")
    with open(os.path.join(HERE, "greeter.css")) as f:
        css = f.read()
    for k, v in p.items():
        css = css.replace("@" + k + "@", v)
    return css.encode()


# ── UI ─────────────────────────────────────────────────────────────────────
class Greeter:
    def __init__(self):
        self.backend = Backend(self.on_prompt, self.on_message, self.on_complete)
        self.mode = "miku"
        self.css = Gtk.CssProvider()
        screen = Gdk.Screen.get_default()
        Gtk.StyleContext.add_provider_for_screen(screen, self.css, Gtk.STYLE_PROVIDER_PRIORITY_USER)
        Gtk.Settings.get_default().set_property("gtk-application-prefer-dark-theme", True)
        self.extra_windows = []
        self.build(screen)
        # connect last: until now nothing has talked to LightDM, so fallback() is still safe
        self.backend.connect()

        user = self.backend.default_user()
        self.user_combo.set_active_id(user)
        self.on_user_changed(self.user_combo)

    # layout
    def build(self, screen):
        display = screen.get_display()
        primary = display.get_primary_monitor() or display.get_monitor(0)

        self.win = Gtk.Window(title="Login")
        self.win.set_name("greeter")
        self.win.set_decorated(False)
        if DEMO:
            self.win.set_default_size(1280, 720)
            self.win.connect("destroy", Gtk.main_quit)
        else:
            geo = primary.get_geometry()
            self.win.move(geo.x, geo.y)
            self.win.set_default_size(geo.width, geo.height)
            for i in range(display.get_n_monitors()):
                m = display.get_monitor(i)
                if m == primary:
                    continue
                g = m.get_geometry()
                bg = Gtk.Window(name="greeter", decorated=False)
                bg.move(g.x, g.y)
                bg.set_default_size(g.width, g.height)
                self.extra_windows.append(bg)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.win.add(root)

        # top bar: host · clock · power
        bar = Gtk.Box(spacing=12, name="topbar")
        root.pack_start(bar, False, False, 0)
        bar.pack_start(Gtk.Label(label=self.backend.hostname, name="host"), False, False, 0)
        self.clock = Gtk.Label(name="clock")
        bar.set_center_widget(self.clock)
        power = Gtk.MenuButton(label="⏻", name="power", relief=Gtk.ReliefStyle.NONE)
        menu = Gtk.Menu()
        for action, text in (("suspend", "Suspend"), ("restart", "Restart"), ("shutdown", "Shut down")):
            item = Gtk.MenuItem(label=text, sensitive=self.backend.can(action))
            item.connect("activate", lambda _w, a=action: self.backend.power(a))
            menu.append(item)
        menu.show_all()
        power.set_popup(menu)
        bar.pack_end(power, False, False, 0)
        self.tick()
        GLib.timeout_add_seconds(1, self.tick)

        # login card
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, name="card")
        card.set_halign(Gtk.Align.CENTER)
        card.set_valign(Gtk.Align.CENTER)
        card.set_size_request(380, -1)
        root.pack_start(card, True, True, 0)

        # the mode button: Miku | Teto
        seg = Gtk.Box(name="modes", homogeneous=True)
        seg.get_style_context().add_class("linked")
        self.mode_buttons = {}
        group = None
        for mode, p in MODES.items():
            b = Gtk.RadioButton.new_with_label_from_widget(group, p["label"])
            b.set_mode(False)       # draw as a button, not a radio dot
            b.set_can_focus(False)
            b.connect("toggled", self.on_mode_toggled, mode)
            group = group or b
            self.mode_buttons[mode] = b
            seg.pack_start(b, True, True, 0)
        card.pack_start(seg, False, False, 0)

        self.title = Gtk.Label(name="title")
        card.pack_start(self.title, False, False, 4)

        self.user_combo = Gtk.ComboBoxText()
        for u in self.backend.users:
            self.user_combo.append(u.get_name(), u.get_display_name() or u.get_name())
        self.user_combo.connect("changed", self.on_user_changed)
        if len(self.backend.users) > 1:
            card.pack_start(self.user_combo, False, False, 0)
        else:
            self.user_label = Gtk.Label(name="user")
            card.pack_start(self.user_label, False, False, 0)

        self.password = Gtk.Entry(visibility=False, placeholder_text="Password")
        self.password.connect("activate", self.on_login)
        card.pack_start(self.password, False, False, 0)

        self.comp_combo = Gtk.ComboBoxText()
        for key, name in COMPOSITORS:
            self.comp_combo.append(key, name)
        card.pack_start(self.comp_combo, False, False, 0)

        self.login_btn = Gtk.Button(label="Log in", name="login")
        self.login_btn.connect("clicked", self.on_login)
        card.pack_start(self.login_btn, False, False, 0)

        self.message = Gtk.Label(name="message")
        card.pack_start(self.message, False, False, 0)

        hint = Gtk.Label(label="F2 switches Miku ⇄ Teto", name="hint")
        card.pack_start(hint, False, False, 0)
        self.win.connect("key-press-event", self.on_key)

    def show(self):
        for w in self.extra_windows:
            w.show_all()
        self.win.show_all()
        self.win.present()
        gdk_win = self.win.get_window()
        if gdk_win and not DEMO:
            gdk_win.focus(Gdk.CURRENT_TIME)
        self.password.grab_focus()

    # behaviour
    def tick(self):
        self.clock.set_text(time.strftime("%a %d %b  %H:%M"))
        return True

    def set_mode(self, mode):
        self.mode = mode
        if not self.mode_buttons[mode].get_active():
            self.mode_buttons[mode].set_active(True)   # re-enters via on_mode_toggled
            return
        self.css.load_from_data(css_for(mode))
        self.title.set_text("HATSUNE MIKU" if mode == "miku" else "KASANE TETO")
        settings = Gtk.Settings.get_default()
        settings.set_property("gtk-cursor-theme-name", MODES[mode]["cursor"])
        display = Gdk.Display.get_default()
        cursor = Gdk.Cursor.new_from_name(display, "default")
        for w in [self.win, *self.extra_windows]:
            if w.get_window():
                w.get_window().set_cursor(cursor)
        root = Gdk.get_default_root_window()
        if root and not DEMO:
            root.set_cursor(cursor)

    def on_mode_toggled(self, button, mode):
        if button.get_active():
            self.set_mode(mode)

    def on_key(self, _w, event):
        if event.keyval == Gdk.KEY_F2:
            self.set_mode("teto" if self.mode == "miku" else "miku")
            return True
        return False

    def selected_user(self):
        return self.user_combo.get_active_id() or self.backend.default_user()

    def on_user_changed(self, combo):
        name = combo.get_active_id()
        user = next((u for u in self.backend.users if u.get_name() == name), None)
        last = user.get_session() if user else None
        if hasattr(self, "user_label"):
            self.user_label.set_text(user.get_display_name() if user else name or "")
        self.comp_combo.set_active_id(last_compositor(last))
        self.set_mode(last_mode(name or "", last))

    def session_key(self):
        comp = self.comp_combo.get_active_id() or COMPOSITORS[0][0]
        key = f"{comp}-{self.mode}"
        return key if key in self.backend.session_keys else comp

    def on_login(self, *_):
        self.message.set_text("")
        self.login_btn.set_sensitive(False)
        self.backend.login(self.selected_user(), self.password.get_text())

    def on_prompt(self, _text, _kind):
        if not self.backend.answer_prompt():
            self.login_btn.set_sensitive(True)

    def on_message(self, text):
        self.message.set_text(text)

    def on_complete(self, ok):
        if ok:
            try:
                self.backend.start_session(self.session_key())
                return False
            except GLib.Error as e:
                self.message.set_text(f"Could not start session: {e.message}")
        else:
            self.message.set_text("Wrong password, try again")
        self.password.set_text("")
        self.password.grab_focus()
        self.login_btn.set_sensitive(True)
        return False


def fallback(err):
    """Something broke before we talked to LightDM: hand over to the stock greeter."""
    print(f"mikuteto-greeter failed ({err}); falling back to lightdm-gtk-greeter", file=sys.stderr)
    os.execvp("lightdm-gtk-greeter", ["lightdm-gtk-greeter"])


def main():
    try:
        app = Greeter()
    except Exception as e:  # noqa: BLE001 - any startup failure must not lock the user out
        if DEMO:
            raise
        fallback(e)
    app.show()
    Gtk.main()


if __name__ == "__main__":
    main()
