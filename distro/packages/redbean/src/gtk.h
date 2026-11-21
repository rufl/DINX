/* SPDX-FileCopyrightText: 2026 DINX Contributors */
/* SPDX-License-Identifier: Apache-2.0 */
#include <gtk/gtk.h>
#include <gtk4-layer-shell/gtk4-layer-shell.h>
#include <astal-apps.h>
#include <astal-river.h>
#include <astal/wireplumber/wp.h>
#include <gio/gdesktopappinfo.h>
#include <glib-unix.h>
#include <sys/file.h>
#include <fcntl.h>
#include <unistd.h>
#include <math.h>

typedef struct _AstalNotifdNotifd AstalNotifdNotifd;
typedef struct _AstalTrayTray AstalTrayTray;

AstalNotifdNotifd *astal_notifd_get_default(void);
GList *astal_notifd_notifd_get_notifications(AstalNotifdNotifd *self);
AstalNotifdNotifd *astal_notifd_notifd_get_notification(AstalNotifdNotifd *self, guint id);
void astal_notifd_notification_dismiss(void *notification);

AstalTrayTray *astal_tray_get_default(void);
GList *astal_tray_tray_get_items(AstalTrayTray *self);

typedef void (*RedbeanNotificationCallback)(
    guint id,
    const char *app_name,
    const char *summary,
    const char *body,
    void *data
);
static inline AstalAppsApps *redbean_apps_new(void) {
    return astal_apps_apps_new();
}

static inline void redbean_object_unref(void *object) {
    if (object != NULL) g_object_unref(object);
}

static inline GList *redbean_apps_list(AstalAppsApps *apps) {
    return apps == NULL ? NULL : astal_apps_apps_get_list(apps);
}

static inline GList *redbean_apps_query(AstalAppsApps *apps, const char *search) {
    return apps == NULL ? NULL : astal_apps_apps_fuzzy_query(apps, search);
}

static inline void redbean_list_free(GList *list) {
    g_list_free(list);
}

static inline void *redbean_list_data(GList *node) {
    return node == NULL ? NULL : node->data;
}

static inline GList *redbean_list_next(GList *node) {
    return node == NULL ? NULL : node->next;
}

static inline const char *redbean_app_name(void *application) {
    return application == NULL ? NULL : astal_apps_application_get_name(application);
}

static inline const char *redbean_app_description(void *application) {
    return application == NULL ? NULL : astal_apps_application_get_description(application);
}

static inline const char *redbean_app_entry(void *application) {
    return application == NULL ? NULL : astal_apps_application_get_entry(application);
}

static inline const char *redbean_app_icon_name(void *application) {
    return application == NULL ? NULL : astal_apps_application_get_icon_name(application);
}

static inline gboolean redbean_app_has_category(void *application, const char *wanted) {
    if (application == NULL || wanted == NULL) return FALSE;
    char **categories = astal_apps_application_get_categories(application);
    if (categories == NULL) return FALSE;
    for (gsize index = 0; categories[index] != NULL; index++) {
        if (g_strcmp0(categories[index], wanted) == 0) return TRUE;
    }
    return FALSE;
}

static inline gboolean redbean_app_launch(void *application) {
    return application != NULL && astal_apps_application_launch(application);
}

static inline void redbean_set_app_pointer(GtkWidget *widget, void *application) {
    g_object_set_data(G_OBJECT(widget), "redbean-application", application);
}

static inline void *redbean_get_app_pointer(GtkWidget *widget) {
    return g_object_get_data(G_OBJECT(widget), "redbean-application");
}

static inline gboolean redbean_launch_desktop(const char *desktop_id) {
    GDesktopAppInfo *desktop = g_desktop_app_info_new(desktop_id);
    if (desktop == NULL) return FALSE;
    GError *error = NULL;
    gboolean launched = g_app_info_launch(G_APP_INFO(desktop), NULL, NULL, &error);
    if (error != NULL) g_error_free(error);
    g_object_unref(desktop);
    return launched;
}

static inline gboolean redbean_spawn_fixed(const char *path) {
    char *argv[] = {(char *)path, NULL};
    GError *error = NULL;
    gboolean started = g_spawn_async(NULL, argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, NULL, &error);
    if (error != NULL) g_error_free(error);
    return started;
}

static inline int redbean_mkdir(const char *path) {
    return g_mkdir_with_parents(path, 0700);
}
static inline void redbean_set_string_data(GtkWidget *widget, const char *key, const char *value) {
    g_object_set_data_full(G_OBJECT(widget), key, g_strdup(value), g_free);
}

static inline const char *redbean_get_string_data(GtkWidget *widget, const char *key) {
    return g_object_get_data(G_OBJECT(widget), key);
}

static inline void redbean_set_uint_data(GtkWidget *widget, const char *key, guint value) {
    g_object_set_data(G_OBJECT(widget), key, GUINT_TO_POINTER(value));
}

static inline guint redbean_get_uint_data(GtkWidget *widget, const char *key) {
    return GPOINTER_TO_UINT(g_object_get_data(G_OBJECT(widget), key));
}

static inline gboolean redbean_launch_path(const char *path) {
    char *uri = g_filename_to_uri(path, NULL, NULL);
    if (uri == NULL) return FALSE;
    GError *error = NULL;
    gboolean launched = g_app_info_launch_default_for_uri(uri, NULL, &error);
    if (error != NULL) g_error_free(error);
    g_free(uri);
    return launched;
}

static inline gboolean redbean_spawn_fixed_args(
    const char *path,
    const char *arg1,
    const char *arg2,
    const char *arg3
) {
    char *argv[] = {
        (char *)path,
        (char *)arg1,
        (char *)arg2,
        (char *)arg3,
        NULL,
    };
    GError *error = NULL;
    gboolean started = g_spawn_async(
        NULL,
        argv,
        NULL,
        G_SPAWN_SEARCH_PATH,
        NULL,
        NULL,
        NULL,
        &error
    );
    if (error != NULL) g_error_free(error);
    return started;
}

static inline gboolean redbean_file_is_directory(const char *path) {
    return g_file_test(path, G_FILE_TEST_IS_DIR);
}

static inline void redbean_file_search_walk(
    const char *directory,
    const char *query,
    guint depth,
    guint limit,
    GList **results
) {
    if (depth > 3 || g_list_length(*results) >= limit) return;
    GDir *dir = g_dir_open(directory, 0, NULL);
    if (dir == NULL) return;
    const char *name = NULL;
    char *needle = g_utf8_casefold(query, -1);
    while ((name = g_dir_read_name(dir)) != NULL && g_list_length(*results) < limit) {
        if (name[0] == '.') continue;
        char *path = g_build_filename(directory, name, NULL);
        if (g_file_test(path, G_FILE_TEST_IS_SYMLINK)) {
            g_free(path);
            continue;
        }
        char *folded = g_utf8_casefold(name, -1);
        gboolean matches = folded != NULL && needle != NULL && g_strstr_len(folded, -1, needle) != NULL;
        g_free(folded);
        if (matches) *results = g_list_append(*results, g_strdup(path));
        if (g_file_test(path, G_FILE_TEST_IS_DIR)) {
            redbean_file_search_walk(path, query, depth + 1, limit, results);
        }
        g_free(path);
    }
    g_free(needle);
    g_dir_close(dir);
}

static inline GList *redbean_file_search(const char *root, const char *query, guint limit) {
    GList *results = NULL;
    if (root == NULL || query == NULL || query[0] == '\0') return results;
    redbean_file_search_walk(root, query, 0, limit, &results);
    return results;
}

static inline void redbean_file_list_free(GList *results) {
    g_list_free_full(results, g_free);
}
static inline gboolean redbean_text_matches(const char *text, const char *query) {
    if (text == NULL || query == NULL) return FALSE;
    char *folded_text = g_utf8_casefold(text, -1);
    char *folded_query = g_utf8_casefold(query, -1);
    gboolean matches = folded_text != NULL && folded_query != NULL &&
        g_strstr_len(folded_text, -1, folded_query) != NULL;
    g_free(folded_text);
    g_free(folded_query);
    return matches;
}

static inline gboolean redbean_audio_change(gdouble delta) {
    AstalWpWp *wp = astal_wp_get_default();
    if (wp == NULL) return FALSE;
    AstalWpEndpoint *speaker = astal_wp_wp_get_default_speaker(wp);
    if (speaker == NULL) return FALSE;
    AstalWpNode *node = ASTAL_WP_NODE(speaker);
    gdouble next = astal_wp_node_get_volume(node) + delta;
    if (next < 0.0) next = 0.0;
    if (next > 1.5) next = 1.5;
    astal_wp_node_set_volume(node, next);
    return TRUE;
}

static inline gboolean redbean_audio_toggle_mute(void) {
    AstalWpWp *wp = astal_wp_get_default();
    if (wp == NULL) return FALSE;
    AstalWpEndpoint *speaker = astal_wp_wp_get_default_speaker(wp);
    if (speaker == NULL) return FALSE;
    AstalWpNode *node = ASTAL_WP_NODE(speaker);
    astal_wp_node_set_mute(node, !astal_wp_node_get_mute(node));
    return TRUE;
}

static inline gboolean redbean_river_command(const char *command, const char *argument) {
    AstalRiverRiver *river = astal_river_get_default();
    if (river == NULL) return FALSE;
    const gchar *argv[] = {command, argument};
    astal_river_river_run_command_async(river, argument == NULL ? 1 : 2, argv, NULL);
    return TRUE;
}

static inline AstalRiverOutput *redbean_focused_output(AstalRiverRiver *river) {
    if (river == NULL) return NULL;
    gchar *name = astal_river_river_get_focused_output(river);
    if (name != NULL) return astal_river_river_get_output(river, name);
    GList *outputs = astal_river_river_get_outputs(river);
    return outputs == NULL ? NULL : outputs->data;
}

static inline gboolean redbean_river_move_tag(gint direction) {
    AstalRiverRiver *river = astal_river_get_default();
    AstalRiverOutput *output = redbean_focused_output(river);
    if (output == NULL) return FALSE;
    guint tags = astal_river_output_get_focused_tags(output);
    guint current = 0;
    while (current < 9 && (tags & (1u << current)) == 0) current++;
    if (current >= 9) current = 0;
    gint next = ((gint)current + direction) % 9;
    if (next < 0) next += 9;
    astal_river_output_set_focused_tags(output, 1u << (guint)next);
    return TRUE;
}

static inline guint redbean_notification_count(void) {
    AstalNotifdNotifd *notifd = astal_notifd_get_default();
    if (notifd == NULL) return 0;
    GList *items = astal_notifd_notifd_get_notifications(notifd);
    guint count = (guint)g_list_length(items);
    g_list_free(items);
    return count;
}

static inline void redbean_dismiss_notification(guint id) {
    AstalNotifdNotifd *notifd = astal_notifd_get_default();
    if (notifd == NULL) return;
    void *notification = astal_notifd_notifd_get_notification(notifd, id);
    if (notification != NULL) astal_notifd_notification_dismiss(notification);
}

static inline void redbean_notifications_each(
    RedbeanNotificationCallback callback,
    void *data
) {
    AstalNotifdNotifd *notifd = astal_notifd_get_default();
    if (notifd == NULL || callback == NULL) return;
    GList *items = astal_notifd_notifd_get_notifications(notifd);
    for (GList *item = items; item != NULL; item = item->next) {
        guint id = 0;
        char *app_name = NULL;
        char *summary = NULL;
        char *body = NULL;
        g_object_get(
            G_OBJECT(item->data),
            "id",
            &id,
            "app-name",
            &app_name,
            "summary",
            &summary,
            "body",
            &body,
            NULL
        );
        callback(id, app_name == NULL ? "" : app_name, summary == NULL ? "" : summary,
                 body == NULL ? "" : body, data);
        g_free(app_name);
        g_free(summary);
        g_free(body);
    }
    g_list_free(items);
}

static inline guint redbean_tray_count(void) {
    AstalTrayTray *tray = astal_tray_get_default();
    if (tray == NULL) return 0;
    GList *items = astal_tray_tray_get_items(tray);
    guint count = (guint)g_list_length(items);
    g_list_free(items);
    return count;
}
