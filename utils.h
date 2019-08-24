#ifndef UTILS_H
#define UTILS_H

#include <stdbool.h>

char *segstr(const char *str, size_t *seg_len, char delim, unsigned int *seg_num);
bool segequstr(char *seg, size_t seg_len, char *str);

#endif
