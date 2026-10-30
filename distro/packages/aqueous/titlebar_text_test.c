// SPDX-FileCopyrightText: © 2026 Seafoam Labs
// SPDX-License-Identifier: GPL-3.0-only
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

int dinx_titlebar_render_text(
    const char *title,
    int max_width,
    int height,
    uint32_t *pixels,
    size_t stride
);

static int has_ink(const uint32_t *pixels, int width, int height, size_t stride_pixels) {
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            if ((pixels[(size_t)y * stride_pixels + (size_t)x] >> 24) != 0) return 1;
        }
    }
    return 0;
}

int main(void) {
    uint32_t short_pixels[160 * 24] = {0};
    const int short_width = dinx_titlebar_render_text(
        "DINX title",
        160,
        24,
        short_pixels,
        160 * sizeof(uint32_t)
    );
    if (short_width <= 0 || short_width > 160 || !has_ink(short_pixels, 160, 24, 160)) {
        fprintf(stderr, "short title was not rendered\n");
        return 1;
    }

    char long_title[1024];
    memset(long_title, 'W', sizeof(long_title) - 1);
    long_title[sizeof(long_title) - 1] = '\0';
    uint32_t clipped_pixels[48 * 24] = {0};
    const int clipped_width = dinx_titlebar_render_text(
        long_title,
        48,
        24,
        clipped_pixels,
        48 * sizeof(uint32_t)
    );
    if (clipped_width <= 0 || clipped_width > 48 || !has_ink(clipped_pixels, 48, 24, 48)) {
        fprintf(stderr, "long title was not bounded and rendered\n");
        return 1;
    }

    const char invalid_utf8[] = {'D', 'I', 'N', 'X', ' ', (char)0xff, '\0'};
    uint32_t utf8_pixels[96 * 24] = {0};
    const int utf8_width = dinx_titlebar_render_text(
        invalid_utf8,
        96,
        24,
        utf8_pixels,
        96 * sizeof(uint32_t)
    );
    if (utf8_width <= 0 || !has_ink(utf8_pixels, 96, 24, 96)) {
        fprintf(stderr, "invalid UTF-8 title was not repaired and rendered\n");
        return 1;
    }

    if (dinx_titlebar_render_text(NULL, 48, 24, clipped_pixels, 48 * sizeof(uint32_t)) != 0 ||
        dinx_titlebar_render_text("", 48, 24, clipped_pixels, 48 * sizeof(uint32_t)) != 0 ||
        dinx_titlebar_render_text("x", 0, 24, clipped_pixels, 48 * sizeof(uint32_t)) != 0 ||
        dinx_titlebar_render_text("x", 48, 0, clipped_pixels, 48 * sizeof(uint32_t)) != 0 ||
        dinx_titlebar_render_text("x", 48, 24, clipped_pixels, 48 * sizeof(uint32_t) - 1) != 0) {
        fprintf(stderr, "invalid renderer arguments were accepted\n");
        return 1;
    }

    puts("titlebar_text_smoke short=true bounded=true utf8_repaired=true invalid_args=true");
    return 0;
}
