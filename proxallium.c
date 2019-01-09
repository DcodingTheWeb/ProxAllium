#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "allium/allium.h"

struct {
	int port;
	bool localhost_only;
} options = {
	9051,
	true
};

char *proxallium_gen_torrc();

int main(void) {
	// Create a new instance of Tor
	struct TorInstance *tor_instance = allium_new_instance("tor");
	if (!tor_instance) {
		puts("Failed to allocate a new instance of Tor!");
		return EXIT_FAILURE;
	}
	
	// Generate the tor config according to the options
	char *config = proxallium_gen_torrc();
	if (!config) {
		puts("Failed to generate configuration for Tor!");
		return EXIT_FAILURE;
	}
	
	// Start Tor
	if (!allium_start(tor_instance, config)) {
		puts("Failed to start Tor!");
		return EXIT_FAILURE;
	}
	printf("Started Tor with PID %li!\n", tor_instance->pid);
	
	// Clean up and exit
	free(tor_instance);
	return EXIT_SUCCESS;
}

char *proxallium_gen_torrc() {
	// Temp variables to store format strings and their sizes
	char *format_string;
	int string_size;
	
	// Socks Port
	format_string = "SocksPort %i\n";
	string_size = snprintf(NULL, 0, format_string, options.port);
	char socks_port[string_size + 1];
	snprintf(socks_port, string_size + 1, format_string, options.port);
	
	// Only allow connections from localhost explicitly for safety
	char *localhost_explicit = options.localhost_only ?
		"SOCKSPolicy accept 127.0.0.1\n"
		"SOCKSPolicy accept6 [::1]\n"
		"SOCKSPolicy reject *\n"
	: "";
	
	// Generate the final string with all of the configuration
	char *config_sections[] = {
		socks_port,
		localhost_explicit,
		NULL
	};
	
	// Calculate the total required size for the string
	size_t total_size = 1;
	for (char **section = config_sections; *section != NULL; ++section) {
		total_size += strlen(*section);
	}
	
	// Allocate space for the string and populate it
	char *torrc = malloc(total_size);
	if (!torrc) return NULL;
	torrc[0] = '\0';
	for (char **section = config_sections; *section != NULL; ++section) {
		strcat(torrc, *section);
	}
	
	return torrc;
}
