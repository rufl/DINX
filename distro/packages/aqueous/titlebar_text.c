// SPDX-FileCopyrightText: © 2026 Seafoam Labs
// SPDX-License-Identifier: GPL-3.0-only
#include <cairo/cairo.h>
#include <glib.h>
#include <pango/pangocairo.h>
#include <stddef.h>
#include <stdint.h>

int dinx_titlebar_render_text(
    const char *title,
    int max_width,
    int height,
    uint32_t *pixels,
    size_t stride
) {
    if (title == NULL || pixels == NULL || max_width <= 0 || height <= 0 ||
        stride < (size_t)max_width * sizeof(*pixels) || stride > G_MAXINT) {
        return 0;
    }

    size_t title_length = 0;
    while (title_length < 1024 && title[title_length] != '\0') ++title_length;
    if (title_length == 0) return 0;

    gchar *valid_title = g_utf8_make_valid(title, (gssize)title_length);
    if (valid_title == NULL) return 0;
    cairo_surface_t *surface = cairo_image_surface_create_for_data(
        (unsigned char *)pixels,
        CAIRO_FORMAT_ARGB32,
        max_width,
        height,
        (int)stride
    );
    if (cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
        cairo_surface_destroy(surface);
        g_free(valid_title);
        return 0;
    }

    cairo_t *context = cairo_create(surface);
    if (cairo_status(context) != CAIRO_STATUS_SUCCESS) {
        cairo_destroy(context);
        cairo_surface_destroy(surface);
        g_free(valid_title);
        return 0;
    }

    cairo_set_operator(context, CAIRO_OPERATOR_CLEAR);
    cairo_paint(context);
    cairo_set_operator(context, CAIRO_OPERATOR_OVER);

    PangoLayout *layout = pango_cairo_create_layout(context);
    PangoFontDescription *font = pango_font_description_from_string("Sans 10");
    pango_layout_set_font_description(layout, font);
    pango_layout_set_single_paragraph_mode(layout, TRUE);
    pango_layout_set_ellipsize(layout, PANGO_ELLIPSIZE_END);
    pango_layout_set_width(layout, max_width * PANGO_SCALE);
    pango_layout_set_text(layout, valid_title, -1);

    int text_width = 0;
    int text_height = 0;
    pango_layout_get_pixel_size(layout, &text_width, &text_height);
    cairo_set_source_rgba(context, 0.94, 0.95, 0.98, 1.0);
    cairo_move_to(context, 0, (height - text_height) / 2);
    pango_cairo_show_layout(context, layout);
    cairo_surface_flush(surface);

    pango_font_description_free(font);
    g_object_unref(layout);
    cairo_destroy(context);
    cairo_surface_destroy(surface);
    g_free(valid_title);

    if (text_width <= 0) return 0;
    return MIN(text_width, max_width);
}
