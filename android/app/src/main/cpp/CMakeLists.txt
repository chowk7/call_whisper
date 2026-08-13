cmake_minimum_required(VERSION 3.22.1)
project(call_whisper)

# Run scripts/bootstrap_native.sh before building. It pins whisper.cpp in
# third_party/whisper.cpp so the speech model code is reproducible.
if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/whisper.cpp/CMakeLists.txt")
  message(FATAL_ERROR "whisper.cpp is missing. Run scripts/bootstrap_native.sh first.")
endif()

set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/../../../../../third_party/whisper.cpp whispercpp)
add_library(call_whisper SHARED whisper_bridge.cpp)
target_link_libraries(call_whisper PRIVATE whisper android log)
