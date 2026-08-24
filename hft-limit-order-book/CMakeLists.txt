cmake_minimum_required(VERSION 3.20)
project(hft-limit-order-book CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(include)

set(SOURCES
    src/OrderBook.cpp
)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-O3 -march=native -Wall -Wextra -Wpedantic -Wshadow -fno-omit-frame-pointer)
endif()

add_library(lob STATIC ${SOURCES})

add_executable(lob_tests tests/LOB_tests.cpp)
target_link_libraries(lob_tests PRIVATE lob)

add_executable(lob_benchmarks benchmark/LOB_benchmark.cpp)
target_link_libraries(lob_benchmarks PRIVATE lob)
