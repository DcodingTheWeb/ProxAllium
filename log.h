#ifndef LOG_H
#define LOG_H

void log_output(const char *format, ...);
int log_output_raw(const char *format, ...);
int log_output_raw_var(const char *format, va_list args);

#endif
