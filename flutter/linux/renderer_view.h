#ifndef RUSTDESK_RENDERER_VIEW_H_
#define RUSTDESK_RENDERER_VIEW_H_

#include <flutter_linux/flutter_linux.h>

static inline FlView* rustdesk_renderer_view_new(FlDartProject* project) {
  const gchar* renderer = g_getenv("RUSTDESK_DEV_RENDERER");
  if (g_strcmp0(renderer, "skia") == 0 ||
      g_strcmp0(renderer, "impeller") == 0) {
    // Release ignores FLUTTER_ENGINE_SWITCHES. Configure each project before
    // its engine starts, including the plugin's remote-window projects.
    fl_dart_project_set_enable_impeller(
        project, g_strcmp0(renderer, "impeller") == 0);
    g_message("RustDesk project renderer: %s", renderer);
  }
  return fl_view_new(project);
}

// Included only while compiling the runner and desktop_multi_window. This
// keeps the plugin's project setup consistent without editing its shared cache.
#define fl_view_new rustdesk_renderer_view_new

#endif  // RUSTDESK_RENDERER_VIEW_H_
