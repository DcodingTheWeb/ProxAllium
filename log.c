#include <stdarg.h>
#include <stdio.h>
#include "log.h"

void log_output(const char *format, ...) {
	va_list args;
	
	va_start(args, format);
	int buffer_size = log_calc_buf_size(format, args);
	va_end(args);
	
	va_start(args, format);
	log_output_raw_var(format, buffer_size, args);
	va_end(args);
	
	log_output_text("\n");
}

void log_output_raw(const char *format, ...) {
	va_list args;
	
	va_start(args, format);
	int buffer_size = log_calc_buf_size(format, args);
	va_end(args);
	
	va_start(args, format);
	log_output_raw_var(format, buffer_size, args);
	va_end(args);
}

int log_calc_buf_size(const char *format, va_list args) {
	// Calculate required size to store the formatted string
	return vsnprintf(NULL, 0, format, args) + 1;
}

void log_output_raw_var(const char *format, int buffer_size, va_list args) {
	// Store the formatted string
	char string[buffer_size];
	vsnprintf(string, buffer_size, format, args);
	
	// Pass the string for output
	log_output_text(string);
}

void log_output_text(const char *string) {
	fputs(string, stdout);
}
