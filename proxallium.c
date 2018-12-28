#include <stdio.h>
#include <stdlib.h>
#include "allium/allium.h"

int main(void) {
	// Create a new instance of Tor
	struct TorInstance *tor_instance = allium_new_instance("tor");
	if (!tor_instance) {
		puts("Failed to allocate a new instance of Tor!");
		return EXIT_FAILURE;
	}
	
	// Start Tor
	if (!
	allium_start(tor_instance)
	) {
		puts("Failed to start Tor!");
		return EXIT_FAILURE;
	}
	printf("Started Tor with PID %li!\n", tor_instance->pid);
	
	// Clean up and exit
	free(tor_instance);
	return EXIT_SUCCESS;
}
