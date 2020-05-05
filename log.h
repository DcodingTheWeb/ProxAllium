#include <stdarg.h>

#ifndef LOG_H
#define LOG_H

void log_output(const char *format, ...);
void log_output_raw(const char *format, ...);
int log_calc_buf_size(const char *format, va_list args);
void log_output_raw_var(const char *format, int buffer_size, va_list args);
void log_output_text(const char *string);

#endif
