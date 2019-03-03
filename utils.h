#ifndef UTILS_H
#define UTILS_H

#include <string.h>

/// @brief Get delimiter-separated segments from a string in a non-destructive method.
/// @details A useful function which can be used for parsing in a loop in a safe manner.
/// @author Damon Harris (TheDcoder@protonmail.com)
/// @param [in]     str        Current segment or start of the string.
/// @param [in,out] seg_len    Length of the segment current segment, value does not matter if seg_num is set to 0.
/// @param          delim      Character used for separation (delimiter).
/// @param [in,out] seg_num    Number of the current segment, set to 0 before first call.
/// @returns Pointer to the start of the next segment, seg_len is set to the length of the segment and seg_num is incremented by 1.
///          NULL if there is no next segment, note that NULL is never returned on the first call (even if an empty string is passed).
/// @remarks seg_num only has significance if its value is 0, the reason is for the function to be able to detect the initial call
///          so that it doesn't skip the first segment. seg_len can be any value on the first call since it is not used to calculate
///          the start of the next segment.
///
///          I was inspired by the lack of a helper function which I can use for parsing/tokenizing a string which is both stateless
///          and non-destructive (strtok_s is better than strtok but still modifies the supplied string). The best alternative was to
///          strchr and keep track of other stuff manually, this function tries to give out as much information as possible while keeping
///          the overall concept simple. The length and position (number) of the segment should be enough to get you started on parsing :)
char *segstr(const char *str, size_t *seg_len, char delim, unsigned int *seg_num) {
	if (*seg_num != 0) {
		// Check if we have reached the last segment
		str += *seg_len;
		if (str[0] == '\0') return NULL;

		// Proceed to the next segment
		++str;
	}

	// Increment the segment number
	++*seg_num;

	// Find the delimiter
	char *delim_start = strchr(str, delim);

	// Calculate the length of the segment
	if (delim_start) {
		// Difference between the delimiter and the start of the segment
		*seg_len = delim_start - str;
	} else {
		// We have reached the last segment
		// There is no delimiter, so use the remaining length
		*seg_len = strlen(str);
	}

	// Return the segment
	return (char *) str;
}

#endif
