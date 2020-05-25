#ifndef INTERRUPT_H
#define INTERRUPT_H

#include <signal.h>
#include <stdbool.h>

volatile sig_atomic_t interrupted = false;

void handle_signal(int sig_num) {
	interrupted = true;
}

void init_interrupt_catcher() {
	signal(SIGINT, handle_signal);
	signal(SIGTERM, handle_signal);
}

#endif
