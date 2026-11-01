cmake_minimum_required(VERSION 3.20)
project(naimport C CXX)

# libnaimport: GDExtension for Neutron Arena that imports the player's own game CDs on the device.
#   cmake -S native -B native/build-linux -DCMAKE_BUILD_TYPE=Release && cmake --build native/build-linux -j8
#   Android: see native/build.sh (NDK toolchain).
# godot-cpp is fetched by native/fetch-deps.sh (not committed).

set(GODOTCPP_TARGET template_release CACHE STRING "")
set(GODOTCPP_DISABLE_EXCEPTIONS OFF CACHE BOOL "")
set(GODOTCPP_SYMBOL_VISIBILITY hidden CACHE STRING "")
add_subdirectory(godot-cpp)
get_target_property(GODOTCPP_SUFFIX godot-cpp GODOTCPP_SUFFIX)

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
find_package(ZLIB REQUIRED)

# --- unshield (MIT) + the ISO/cabinet importer
set(US ${CMAKE_CURRENT_SOURCE_DIR}/third_party/unshield/lib)
file(GLOB US_SRC ${US}/*.c)
add_library(na_iso STATIC src/iso/NegImport.c ${US_SRC} ${US}/convert_utf/ConvertUTF.c ${US}/md5/md5c.c)
target_include_directories(na_iso PUBLIC src/iso PRIVATE ${US} ${US}/..)
target_compile_options(na_iso PRIVATE -w)
set_target_properties(na_iso PROPERTIES C_STANDARD 99 C_EXTENSIONS ON)
target_link_libraries(na_iso PUBLIC ZLIB::ZLIB)

# --- OMT 2.5 subset (LGPL 2.1+): database / 3D shape / canvas readers.  Old C++ dialect + the original's quirks.
file(GLOB OMT_SRC src/omt/src/*.cpp)
add_library(na_omt STATIC ${OMT_SRC} src/omt/omt_dump.cpp src/omt/shim/sdl_shim.cpp)
target_include_directories(na_omt PRIVATE src/omt/inc src/omt/shim)
target_compile_definitions(na_omt PRIVATE omd_DISABLE_OPENGL)
target_compile_options(na_omt PRIVATE -std=gnu++98 -fpermissive -w -fno-strict-aliasing -fexceptions)
set_target_properties(na_omt PROPERTIES CXX_STANDARD 98 CXX_EXTENSIONS ON)
target_link_libraries(na_omt PUBLIC ZLIB::ZLIB)

# --- Granny 1.2b replacement (reads the game's .grn files).  Exact IEEE float arithmetic, see granny_internal.h.
file(GLOB GRN_SRC src/granny/*.cpp)
add_library(na_granny STATIC ${GRN_SRC})
target_include_directories(na_granny PUBLIC src/granny)
target_compile_options(na_granny PRIVATE -ffp-contract=off -fno-fast-math -w -fexceptions)
set_target_properties(na_granny PROPERTIES CXX_STANDARD 17)

# --- GDExtension glue (glTF writers, importer class)
file(GLOB GLUE_SRC src/glue/*.cpp)
add_library(naimport SHARED ${GLUE_SRC})
target_link_libraries(naimport PRIVATE godot-cpp na_iso na_omt na_granny)
set_target_properties(naimport PROPERTIES CXX_STANDARD 17 CXX_EXTENSIONS OFF POSITION_INDEPENDENT_CODE ON
	PREFIX "lib" OUTPUT_NAME "naimport${GODOTCPP_SUFFIX}"
	LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../addons/naimport/bin")
target_compile_options(naimport PRIVATE -fexceptions)
