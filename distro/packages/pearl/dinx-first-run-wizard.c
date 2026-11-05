#include <gtk/gtk.h>
#include <stdio.h>

struct Wizard {
    GtkApplication *application;
    GtkCssProvider *style_provider;
    GtkWidget *window;
    GtkWidget *stack;
    GtkWidget *dock_enabled;
    GtkWidget *bar_top;
    GtkWidget *theme;
    GtkWidget *back_button;
    GtkWidget *next_button;
    guint page;
    gboolean completed;
    gboolean portuguese;
};

typedef struct Wizard Wizard;

static const char dark_css[] =
    ".dinx-wizard { background-color: #0b0d12; color: #d7dde8; }\n"
    ".dinx-wizard label { color: #d7dde8; }\n"
    ".dinx-wizard label.dim-label { color: #7f8a9c; }\n"
    ".dinx-wizard button, .dinx-wizard dropdown { background-color: #11151d; color: #d7dde8; border-color: #222a38; background-image: none; }\n"
    ".dinx-wizard dropdown button { background-color: #11151d; color: #d7dde8; border-color: #222a38; background-image: none; }\n"
    ".dinx-wizard dropdown button label { color: #d7dde8; }\n"
    ".dinx-wizard dropdown listview row:selected { background-color: #263249; color: #d7dde8; }\n"
    ".dinx-wizard dropdown listview row:selected label { color: #d7dde8; }\n"
    ".dinx-wizard button:disabled { background-color: #11151d; color: #7f8a9c; border-color: #222a38; }\n"
    ".dinx-wizard button:hover, .dinx-wizard dropdown:hover { background-color: #263249; color: #d7dde8; }\n"
    ".dinx-wizard button.suggested-action, .dinx-wizard button.default { background-color: #8fb8ff; color: #0b0d12; border-color: #8fb8ff; }\n"
    ".dinx-wizard checkbutton { color: #d7dde8; }\n"
    ".dinx-wizard checkbutton check { background-color: #11151d; border-color: #222a38; }\n"
    ".dinx-wizard checkbutton check:checked { background-color: #8fb8ff; border-color: #8fb8ff; }\n"
    ".dinx-wizard button:focus-visible, .dinx-wizard dropdown:focus-visible, .dinx-wizard checkbutton:focus-visible { outline: 2px solid #8fb8ff; outline-offset: 2px; }\n"
    ".dinx-wizard popover, .dinx-wizard popover contents, .dinx-wizard listview, .dinx-wizard row { background-color: #11151d; color: #d7dde8; }\n"
    ".dinx-wizard row:hover { background-color: #263249; color: #d7dde8; }\n";

static const char light_css[] =
    ".dinx-wizard { background-color: #f7f8fa; color: #202631; }\n"
    ".dinx-wizard label { color: #202631; }\n"
    ".dinx-wizard label.dim-label { color: #687386; }\n"
    ".dinx-wizard button, .dinx-wizard dropdown { background-color: #eef1f6; color: #202631; border-color: #d9dee8; background-image: none; }\n"
    ".dinx-wizard dropdown button { background-color: #eef1f6; color: #202631; border-color: #d9dee8; background-image: none; }\n"
    ".dinx-wizard dropdown button label { color: #202631; }\n"
    ".dinx-wizard dropdown listview row:selected { background-color: #d9e5ff; color: #202631; }\n"
    ".dinx-wizard dropdown listview row:selected label { color: #202631; }\n"
    ".dinx-wizard button:disabled { background-color: #eef1f6; color: #687386; border-color: #d9dee8; }\n"
    ".dinx-wizard button:hover, .dinx-wizard dropdown:hover { background-color: #d9e5ff; color: #202631; }\n"
    ".dinx-wizard button.suggested-action, .dinx-wizard button.default { background-color: #2859a8; color: #f7f8fa; border-color: #2859a8; }\n"
    ".dinx-wizard checkbutton { color: #202631; }\n"
    ".dinx-wizard checkbutton check { background-color: #eef1f6; border-color: #d9dee8; }\n"
    ".dinx-wizard checkbutton check:checked { background-color: #2859a8; border-color: #2859a8; }\n"
    ".dinx-wizard button:focus-visible, .dinx-wizard dropdown:focus-visible, .dinx-wizard checkbutton:focus-visible { outline: 2px solid #2859a8; outline-offset: 2px; }\n"
    ".dinx-wizard popover, .dinx-wizard popover contents, .dinx-wizard listview, .dinx-wizard row { background-color: #eef1f6; color: #202631; }\n"
    ".dinx-wizard row:hover { background-color: #d9e5ff; color: #202631; }\n";

static void
apply_theme(Wizard *wizard)
{
    guint selected;
    gboolean light;

    if (wizard->style_provider == NULL)
        return;
    selected = gtk_drop_down_get_selected(GTK_DROP_DOWN(wizard->theme));
    light = selected == 1 || selected == 3;
    gtk_css_provider_load_from_string(wizard->style_provider,
                                     light ? light_css : dark_css);
}

static void
on_theme_changed(GObject *object, GParamSpec *property, gpointer user_data)
{
    Wizard *wizard = user_data;
    (void)object;
    (void)property;
    apply_theme(wizard);
}

static void
install_theme(Wizard *wizard)
{
    GdkDisplay *display = gdk_display_get_default();
    if (display == NULL)
        return;

    wizard->style_provider = gtk_css_provider_new();
    gtk_style_context_add_provider_for_display(
        display, GTK_STYLE_PROVIDER(wizard->style_provider),
        GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
}

static void
remove_theme(Wizard *wizard)
{
    GdkDisplay *display = gdk_display_get_default();
    if (wizard->style_provider == NULL)
        return;
    if (display != NULL)
        gtk_style_context_remove_provider_for_display(
            display, GTK_STYLE_PROVIDER(wizard->style_provider));
    g_object_unref(wizard->style_provider);
}


static const char *
text(Wizard *wizard, const char *portuguese, const char *english)
{
    return wizard->portuguese ? portuguese : english;
}

static GtkWidget *
make_page(Wizard *wizard, const char *title, const char *description)
{
    GtkWidget *page = gtk_box_new(GTK_ORIENTATION_VERTICAL, 16);
    GtkWidget *heading = gtk_label_new(title);
    GtkWidget *body = gtk_label_new(description);

    gtk_widget_set_halign(heading, GTK_ALIGN_START);
    gtk_widget_add_css_class(heading, "title-1");
    gtk_label_set_wrap(GTK_LABEL(body), TRUE);
    gtk_widget_set_halign(body, GTK_ALIGN_START);
    gtk_widget_add_css_class(body, "dim-label");
    gtk_box_append(GTK_BOX(page), heading);
    gtk_box_append(GTK_BOX(page), body);
    gtk_widget_set_margin_top(page, 28);
    gtk_widget_set_margin_bottom(page, 20);
    gtk_widget_set_margin_start(page, 28);
    gtk_widget_set_margin_end(page, 28);
    (void)wizard;
    return page;
}

static void
emit_result(Wizard *wizard, gboolean skipped)
{
    if (wizard->completed)
        return;

    wizard->completed = TRUE;
    if (skipped) {
        puts("skip");
    } else {
        const char *dock = gtk_check_button_get_active(GTK_CHECK_BUTTON(wizard->dock_enabled)) ? "on" : "off";
        const char *edge = gtk_check_button_get_active(GTK_CHECK_BUTTON(wizard->bar_top)) ? "top" : "bottom";
        guint theme = gtk_drop_down_get_selected(GTK_DROP_DOWN(wizard->theme));
        const char *theme_name[] = { "dinx-dark", "dinx-light", "material-dark", "material-light" };
        if (theme >= G_N_ELEMENTS(theme_name))
            theme = 0;
        printf("%s %s %s\n", dock, edge, theme_name[theme]);
    }
    fflush(stdout);
    g_application_quit(G_APPLICATION(wizard->application));
}

static gboolean
on_close_request(GtkWindow *window, gpointer user_data)
{
    Wizard *wizard = user_data;
    (void)window;
    emit_result(wizard, TRUE);
    return TRUE;
}

static void
on_back_clicked(GtkButton *button, gpointer user_data)
{
    Wizard *wizard = user_data;
    (void)button;
    if (wizard->page == 0)
        return;
    wizard->page--;
    gtk_stack_set_visible_child_name(GTK_STACK(wizard->stack),
                                     wizard->page == 0 ? "dock" : "bar");
    gtk_widget_set_sensitive(wizard->back_button, wizard->page != 0);
    gtk_button_set_label(GTK_BUTTON(wizard->next_button),
                         text(wizard, "Próximo", "Next"));
}

static void
on_next_clicked(GtkButton *button, gpointer user_data)
{
    Wizard *wizard = user_data;
    (void)button;
    if (wizard->page == 0) {
        wizard->page = 1;
        gtk_stack_set_visible_child_name(GTK_STACK(wizard->stack), "bar");
        gtk_widget_set_sensitive(wizard->back_button, TRUE);
        return;
    }
    if (wizard->page == 1) {
        wizard->page = 2;
        gtk_stack_set_visible_child_name(GTK_STACK(wizard->stack), "theme");
        gtk_button_set_label(GTK_BUTTON(wizard->next_button),
                             text(wizard, "Concluir", "Finish"));
        return;
    }
    emit_result(wizard, FALSE);
}

static void
on_activate(GtkApplication *application, gpointer user_data)
{
    Wizard *wizard = user_data;
    GtkWidget *root;
    GtkWidget *navigation;
    GtkWidget *bar_choice;
    const char *theme_names[5];
    const char * const *languages = g_get_language_names();

    wizard->application = application;
    wizard->portuguese = g_str_has_prefix(languages[0], "pt");
    wizard->window = gtk_application_window_new(application);
    install_theme(wizard);
    gtk_widget_add_css_class(wizard->window, "dinx-wizard");
    gtk_window_set_title(GTK_WINDOW(wizard->window),
                         text(wizard, "Configuração inicial do Pearl", "Pearl first-run setup"));
    gtk_window_set_default_size(GTK_WINDOW(wizard->window), 560, 390);
    gtk_window_set_resizable(GTK_WINDOW(wizard->window), FALSE);
    g_signal_connect(wizard->window, "close-request", G_CALLBACK(on_close_request), wizard);

    root = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_widget_add_css_class(root, "dinx-wizard");
    gtk_window_set_child(GTK_WINDOW(wizard->window), root);
    wizard->stack = gtk_stack_new();
    gtk_stack_set_transition_type(GTK_STACK(wizard->stack), GTK_STACK_TRANSITION_TYPE_CROSSFADE);
    gtk_widget_set_vexpand(wizard->stack, TRUE);

    GtkWidget *dock_page = make_page(wizard,
        text(wizard, "Dock", "Dock"),
        text(wizard, "Escolha se deseja manter o dock de aplicativos na sessão.",
                     "Choose whether to show the application dock in this session."));
    wizard->dock_enabled = gtk_check_button_new_with_label(
        text(wizard, "Mostrar o dock", "Show the dock"));
    gtk_check_button_set_active(GTK_CHECK_BUTTON(wizard->dock_enabled), TRUE);
    gtk_box_append(GTK_BOX(dock_page), wizard->dock_enabled);
    gtk_stack_add_named(GTK_STACK(wizard->stack), dock_page, "dock");

    GtkWidget *bar_page = make_page(wizard,
        text(wizard, "Barra do Pearl", "Pearl bar"),
        text(wizard, "Selecione a posição da barra. O dock, quando ativo, ficará na borda oposta.",
                     "Choose the bar position. When enabled, the dock will use the opposite edge."));
    wizard->bar_top = gtk_check_button_new_with_label(text(wizard, "Em cima", "Top"));
    bar_choice = gtk_check_button_new_with_label(text(wizard, "Em baixo", "Bottom"));
    gtk_check_button_set_group(GTK_CHECK_BUTTON(bar_choice), GTK_CHECK_BUTTON(wizard->bar_top));
    gtk_check_button_set_active(GTK_CHECK_BUTTON(wizard->bar_top), TRUE);
    gtk_box_append(GTK_BOX(bar_page), wizard->bar_top);
    gtk_box_append(GTK_BOX(bar_page), bar_choice);
    gtk_stack_add_named(GTK_STACK(wizard->stack), bar_page, "bar");

    GtkWidget *theme_page = make_page(wizard,
        text(wizard, "Tema", "Theme"),
        text(wizard, "Escolha o tema visual do Pearl. A escolha não altera o tema do greeter.",
                     "Choose Pearl's visual theme. This does not change the greeter theme."));
    theme_names[0] = text(wizard, "DINX escuro", "DINX dark");
    theme_names[1] = text(wizard, "DINX claro", "DINX light");
    theme_names[2] = text(wizard, "Pearl Material escuro", "Pearl Material dark");
    theme_names[3] = text(wizard, "Pearl Material claro", "Pearl Material light");
    theme_names[4] = NULL;
    GtkStringList *theme_model = gtk_string_list_new(theme_names);
    wizard->theme = gtk_drop_down_new(G_LIST_MODEL(theme_model), NULL);
    g_object_unref(theme_model);
    gtk_drop_down_set_selected(GTK_DROP_DOWN(wizard->theme), 2);
    gtk_widget_set_halign(wizard->theme, GTK_ALIGN_FILL);
    gtk_box_append(GTK_BOX(theme_page), wizard->theme);
    g_signal_connect(wizard->theme, "notify::selected",
                     G_CALLBACK(on_theme_changed), wizard);
    apply_theme(wizard);
    gtk_stack_add_named(GTK_STACK(wizard->stack), theme_page, "theme");

    gtk_box_append(GTK_BOX(root), wizard->stack);
    navigation = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_halign(navigation, GTK_ALIGN_END);
    gtk_widget_set_margin_top(navigation, 12);
    gtk_widget_set_margin_bottom(navigation, 20);
    gtk_widget_set_margin_start(navigation, 28);
    gtk_widget_set_margin_end(navigation, 28);
    wizard->back_button = gtk_button_new_with_label(text(wizard, "Voltar", "Back"));
    gtk_widget_set_sensitive(wizard->back_button, FALSE);
    wizard->next_button = gtk_button_new_with_label(text(wizard, "Próximo", "Next"));
    gtk_widget_add_css_class(wizard->next_button, "suggested-action");
    g_signal_connect(wizard->back_button, "clicked", G_CALLBACK(on_back_clicked), wizard);
    g_signal_connect(wizard->next_button, "clicked", G_CALLBACK(on_next_clicked), wizard);
    gtk_box_append(GTK_BOX(navigation), wizard->back_button);
    gtk_box_append(GTK_BOX(navigation), wizard->next_button);
    gtk_box_append(GTK_BOX(root), navigation);
    gtk_window_present(GTK_WINDOW(wizard->window));
}

int
main(int argc, char **argv)
{
    GtkApplication *application = gtk_application_new(
        "org.dinx.PearlFirstRun", G_APPLICATION_NON_UNIQUE);
    Wizard wizard = { 0 };
    g_signal_connect(application, "activate", G_CALLBACK(on_activate), &wizard);
    int status = g_application_run(G_APPLICATION(application), argc, argv);
    if (!wizard.completed)
        puts("skip");
    remove_theme(&wizard);
    g_object_unref(application);
    return status;
}
