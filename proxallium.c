#include <errno.h>
#include <limits.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <string.h>
#include "allium/allium.h"

struct {
	unsigned int port;
	bool localhost_only;
} options = {
	9050,
	true
};

void process_cmdline_options(int argc, char *argv[]);
noreturn void print_help(bool error, char *program_name);
char *proxallium_gen_torrc();

int main(int argc, char *argv[]) {
	// Process command-line arguments
	process_cmdline_options(argc, argv);
	
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
	printf("Started Tor with PID %lu!\n", tor_instance->pid);
	
	// Clean up and exit
	free(tor_instance);
	return EXIT_SUCCESS;
}

void process_cmdline_options(int argc, char *argv[]) {
	struct option long_options[] = {
		{"port", required_argument, NULL, 'p'},
		{"help", no_argument, NULL, 'h'},
		{"version", no_argument, NULL, 'v'},
		{NULL, 0, NULL, 0}
	};
	int option;
	while ((option = getopt_long(argc, argv, "p:hv", long_options, NULL)) != -1) {
		switch (option) {
			long port;
			case 'p':
				port = strtol(optarg, NULL, 0);
				if (errno == ERANGE || port < 0 || port > UINT_MAX) {
					printf("Port is out of range! Please use something between 0 and %u\n", UINT_MAX);
					exit(EXIT_FAILURE);
				}
				options.port = port;
				break;
			case 'h':
			case '?':
				print_help(option == '?', argv[0]);
				break;
			case 'v':
				puts(
					"ProxAllium " VERSION "\n"
					"\n"
					"Copyright (c) 2019, Dcoding The Web"
				);
				exit(EXIT_SUCCESS);
		}
	}
}

void noreturn print_help(bool error, char *program_name) {
	if (!error) puts(
		"ProxAllium - front-end and controller for Tor"
	);
	printf("\nUsage: %s [OPTION]...\n", program_name);
	puts(
		"\n"
		"Options:\n"
		"	-p, --port            Port for Tor's proxy to bind\n"
		"	-h, --help            Show this help text\n"
		"	-v, --version         Print the version\n"
		"\n"
		"Report bugs at the GitHub repository <https://github.com/DcodingTheWeb/ProxAllium>"
	);
	exit(error ? EXIT_FAILURE : EXIT_SUCCESS);
}

char *proxallium_gen_torrc() {
	// Temp variables to store format strings and their sizes
	char *format_string;
	int string_size;
	
	// Socks Port
	format_string = "SocksPort %u\n";
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
