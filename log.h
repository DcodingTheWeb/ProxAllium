#ifndef LOG_H
#define LOG_H

#include <stdarg.h>
#include <stdio.h>

void log_output(const char *format, ...);
int log_output_raw(const char *format, ...);
int log_output_raw_var(const char *format, va_list args);

void log_output(const char *format, ...) {
	va_list args;
	va_start(args, format);
	log_output_raw_var(format, args);
	va_end(args);
	log_output_raw("\n");
}

int log_output_raw(const char *format, ...) {
	va_list args;
	va_start(args, format);
	int bytes_written = log_output_raw_var(format, args);
	va_end(args);
	return bytes_written;
}

int log_output_raw_var(const char *format, va_list args) {
	return vprintf(format, args);
}

#endif
