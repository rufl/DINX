// kwm tag state over the dinx-kwm-tags Unix socket.
//
// river 0.5.x removed zriver_status_manager_v1 and AstalRiver binds exactly
// that protocol, so the RiverTags widget cannot coexist with kwm. kwm is the
// sole owner of tag state (output.tag, occupied_tags()) and publishes it here.
//
// Protocol (newline-delimited UTF-8):
//   kwm -> client:  "T <focused_hex> <occupied_hex>\n"
//   client -> kwm:  "F <mask_hex>\n" (focus) | "X <mask_hex>\n" (toggle)
public class KwmTags : Rolltop {
    private const uint MAX_TAGS = 9;
    private const string[] ICON_NAMES = {
        "terminal-symbolic",
        "browser-symbolic",
        "code-symbolic",
        "explorer-symbolic",
        "social-symbolic",
        "docs-symbolic",
        "media-symbolic",
        "settings-symbolic",
        "gaming-symbolic",
    };

    private List<WorkspaceItem> _tags = new List<WorkspaceItem>();
    private SocketConnection? _conn = null;
    private DataInputStream? _in = null;
    private uint _focused = 0;
    private uint _occupied = 0;

    public KwmTags() {
        initialize_items();
        connect_socket();
    }

    protected override void setup_items_container(Gtk.Box container) {
        for (int i = 0; i < MAX_TAGS; i++) {
            int tag_index = i;

            var tag_button = new WorkspaceItem(
                () => { send_command("F", 1u << tag_index); },
                null,
                () => { send_command("X", 1u << tag_index); }
            ) {
                child = new Gtk.Image.from_icon_name(ICON_NAMES[i]) {
                    pixel_size = 20
                }
            };
            tag_button.add_css_class("empty");

            add_workspace_item(container, tag_button);
            _tags.append(tag_button);
        }
    }

    private void connect_socket() {
        var runtime_dir = Environment.get_variable("XDG_RUNTIME_DIR") ?? "/tmp";
        var path = runtime_dir + "/dinx-kwm-tags.sock";

        try {
            var client = new SocketClient();
            client.timeout = 0;
            _conn = client.connect(new UnixSocketAddress(path), null);
            _in = new DataInputStream(_conn.get_input_stream());

            // Reader thread: kwm only ever writes short "T f o\n" lines.
            new Thread<void*>("kwm-tags", () => {
                try {
                    string? line;
                    while ((line = _in.read_line(null)) != null) {
                        var captured = line;
                        Idle.add(() => { apply_line(captured); return false; });
                    }
                } catch (IOError e) {
                    warning("kwm tags read failed: %s", e.message);
                }
                return null;
            });

            // Test init confirmation
            try {
                var out = _conn.get_output_stream();
                out.write(("KwmTags initialized\n").data);
            } catch (Error e) {
                warning("kwm tags init failed: %s", e.message);
            }
        } catch (Error e) {
            warning("kwm tags socket %s: %s", path, e.message);
            _conn = null;
            _in = null;
            // kwm starts after morghulis; retry until it owns the socket.
            Timeout.add_seconds(2, () => { connect_socket(); return false; });
        }
    }

    private void apply_line(string line) {
        // "T <focused_hex> <occupied_hex>"
        var fields = line.split(" ");
        if (fields.length != 3 || fields[0] != "T") return;

        _focused = parse_hex(fields[1]);
        _occupied = parse_hex(fields[2]);
        update_css();
    }

    private void update_css() {
        int index = 0;
        int focused_index = -1;

        foreach (var tag_button in _tags) {
            if ((_focused & (1u << index)) != 0) {
                tag_button.set_css_classes({ "accent" });
                focused_index = index;
            } else if ((_occupied & (1u << index)) != 0) {
                tag_button.set_css_classes({ "occupied" });
            } else {
                tag_button.set_css_classes({ "empty" });
            }
            index++;
        }

        if (focused_index >= 0) {
            update_underline_position(focused_index);
        }
    }

    private void send_command(string cmd, uint mask) {
        if (_conn == null) return;
        try {
            var out = _conn.get_output_stream();
            out.write(("%s %x\n".printf(cmd, mask)).data);
        } catch (Error e) {
            warning("kwm tags send %s failed: %s", cmd, e.message);
            _conn = null;
            _in = null;
            connect_socket();
        }
    }

    private static uint parse_hex(string s) {
        uint v = 0;
        for (int i = 0; i < s.length; i++) {
            char c = s[i];
            if (c >= '0' && c <= '9') {
                v = v * 16 + (c - '0');
            } else if (c >= 'a' && c <= 'f') {
                v = v * 16 + (c - 'a' + 10);
            } else if (c >= 'A' && c <= 'F') {
                v = v * 16 + (c - 'A' + 10);
            } else {
                break;
            }
        }
        return v;
    }
}