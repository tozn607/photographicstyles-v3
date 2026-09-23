#ifndef C_PHOTOSTYLE_H
#define C_PHOTOSTYLE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    bool success;
    char *mode;
    char *family;
    double edr_scale;
    double gain_map_max;
    char *error_message;
} ConversionResult;

typedef struct {
    uint8_t oppo_compat;
    uint8_t oppo_camera_tail;
    uint8_t strict_tmap;
    uint8_t apple_photographic_styles;
    uint8_t apple_portrait;
} ConvertConfig;

char *xdremux_version(void);
void xdremux_free_string(char *s);
void xdremux_free_result(ConversionResult res);

ConversionResult xdremux_convert(
    const char *input_path,
    const char *output_path,
    const ConvertConfig *config
);

ConversionResult xdremux_convert_with_progress(
    const char *input_path,
    const char *output_path,
    const ConvertConfig *config,
    uint32_t handle
);

uint8_t xdremux_inject_texture_styles(
    const char *input_path,
    const char *output_path,
    uint64_t grain_seed
);

uint8_t xdremux_inject_semantic_mattes(
    const char *input_path,
    const char *output_path
);

char *xdremux_attach_styles(
    const char *input_path,
    const char *output_path,
    uint64_t grain_seed
);

bool xdremux_verify_output(const char *path);
bool xdremux_verify_styles_output(const char *path);
bool xdremux_verify_portrait_output(const char *path);

ConversionResult xdremux_inspect(const char *path);
char *xdremux_diagnose_portrait(const char *input_path);

uint32_t xdremux_progress_begin(void);
void xdremux_progress_end(uint32_t handle);
void xdremux_read_progress_for(uint32_t handle, uint32_t *stage, uint32_t *current, uint32_t *total);

#ifdef __cplusplus
}
#endif

#endif /* C_PHOTOSTYLE_H */
