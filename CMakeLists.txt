cmake_minimum_required(VERSION 3.10)

project(actions
	VERSION 0.1
    DESCRIPTION "Event Driven Actions"
)

include(GNUInstallDirs)

find_package(BISON)
find_package(FLEX)

FLEX_TARGET( Actions_Scanner src/lexan.l ${CMAKE_CURRENT_BINARY_DIR}/lex.yy.c )
BISON_TARGET( Actions_Parser src/actions.y ${CMAKE_CURRENT_BINARY_DIR}/actions.tab.c )
ADD_FLEX_BISON_DEPENDENCY(Actions_Scanner Actions_Parser)

add_executable( ${PROJECT_NAME}
	src/lineno.c
    src/actions.c
    src/timer.c
    src/engine.c

    ${FLEX_Actions_Scanner_OUTPUTS}
    ${BISON_Actions_Parser_OUTPUTS}
)

target_link_libraries( ${PROJECT_NAME}
	${CMAKE_THREAD_LIBS_INIT}
	rt
    varserver
    varaction
)

target_include_directories( ${PROJECT_NAME} PRIVATE
    .
    inc
    ${CMAKE_CURRENT_BINARY_DIR}
    ${CMAKE_BINARY_DIR} )

install(TARGETS ${PROJECT_NAME}
	RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} )

file(GLOB test_files "test/*.act")

install( FILES ${test_files}
	DESTINATION /usr/share/actions
)
