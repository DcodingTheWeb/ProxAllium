#define __STDC_WANT_LIB_EXT1__

#include <errno.h>
#include <limits.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <string.h>
#include "allium/allium.h"

#include "log.h"
#include "utils.h"

struct {
	unsigned int port;
	bool localhost_only;
} options = {
	9050,
	true
};


struct OutputHandler {
	bool (*function)(char *);
	bool finished;
};

void process_cmdline_options(int argc, char *argv[]);
noreturn void print_help(bool error, char *program_name);
char *proxallium_gen_torrc();
bool handler_bootstrap(char *line);
bool handler_warnings_and_errors(char *line);

struct TorInstance *tor_instance;

int main(int argc, char *argv[]) {
	// Process command-line arguments
	process_cmdline_options(argc, argv);
	
	// Create a new instance of Tor
	tor_instance = allium_new_instance("tor");
	if (!tor_instance) {
		log_output("Failed to allocate a new instance of Tor!");
		return EXIT_FAILURE;
	}
	
	// Generate the tor config according to the options
	char *config = proxallium_gen_torrc();
	if (!config) {
		log_output("Failed to generate configuration for Tor!");
		return EXIT_FAILURE;
	}
	
	// Start Tor
	if (!allium_start(tor_instance, config, NULL)) {
		log_output("Failed to start Tor!");
		return false;
	}
	
	log_output("Started Tor with PID %lu!", tor_instance->pid);
	
	// Main event loop
	struct OutputHandler handlers[] = {
		{handler_bootstrap, false},
		{handler_warnings_and_errors, false}
	};
	size_t handlers_num = sizeof handlers / sizeof(struct OutputHandler);
	
	char *output;
	while ((output = allium_read_stdout_line(tor_instance))) {
		for (int handler = 0; handler < handlers_num; handler++) {
			if (!handlers[handler].finished)
			handlers[handler].finished = handlers[handler].function(output);
		}
	}
	log_output("\nFinished reading Tor's output! Tor exited with exit code %i.", allium_get_exit_code(tor_instance));
	
	// Clean up and exit
	allium_clean(tor_instance);
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

bool handler_bootstrap(char *output) {
	unsigned int percentage;
	
	char *compare_string, *message, *segment = output;
	size_t segment_len;
	unsigned int segment_num = 0;
	while (true) {
		// Get the next segment of text
		segment = segstr(segment, &segment_len, ' ', &segment_num);
		if (!segment) return false;
		
		switch (segment_num) {
			case 5: // Identify if we are bootstrapping
				compare_string = "Bootstrapped";
				if (strncmp(segment, compare_string, segment_len) != 0) return false;
				message = segment;
				break;
			case 6: // Get the percentage
				if (sscanf(segment, "%3u%%:", &percentage) == 0) return false;
				break;
		}
		
		// Check if we got all of the information we needed
		if (segment_num == 6) break;
	}
	
	if (percentage == 0) log_output("Trying to establish a connection and build a circuit, please wait...");
	log_output("%s", message);
	if (percentage == 100) {
		log_output(
			"##################################################\n"
			"# You can now connect to the Tor proxy hosted at:\n"
			"# IP Address: 127.0.0.1\n"
			"# Port      : %u\n"
			"# Proxy Type: SOCKS5\n"
			"##################################################"
		, options.port);
		return true;
	}
	
	return false;
}

bool handler_warnings_and_errors(char *output) {
	char *segment = output;
	size_t segment_len;
	unsigned int segment_num = 0;
	bool warning, error;
	while (segment = segstr(segment, &segment_len, ' ', &segment_num)) {
		if (segment_num == 4) {
			// Check for warning or error
			warning = segequstr(segment, segment_len, "[warn]");
			error = warning ? false : segequstr(segment, segment_len, "[err]");
			
			// No warning and error
			if (!warning && !error) break;
		} else if (segment_num == 5) {
			// Print the error or warning
			log_output("%s: %s", warning ? "Warning" : "Error", segment);
			break;
		}
	}
	
	return false;
}
