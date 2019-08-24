cmake_minimum_required(VERSION 3.0)

# Define the project and executable
project(ProxAllium C)
add_executable(proxallium proxallium.c log.c utils.c)

# Set the version
set(VERSION dev)
find_program(git git)
execute_process(
	COMMAND ${git} rev-parse --short HEAD
	OUTPUT_VARIABLE "GIT_HASH"
	OUTPUT_STRIP_TRAILING_WHITESPACE
)
add_compile_definitions("VERSION=\"${VERSION} (git-${GIT_HASH})\"")

# Enable warnings
if(CMAKE_C_COMPILER_ID STREQUAL "GNU")
	add_compile_options(-Wall -Wno-maybe-uninitialized -Wno-parentheses -Wpedantic)
endif()

# Link liballium
set($ENV{SKIP_CRYPT} "")
add_subdirectory(allium)
target_link_libraries(proxallium PRIVATE allium)
