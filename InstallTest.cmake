define_property(
  TEST
  PROPERTY INSTALL_TEST_INSTALL_DIR
  BRIEF_DOCS "Install dir for this install test"
  FULL_DOCS
    "This property is used to store the install dir for this install test")

set(InstallTestPrefix InstallTest)

#[[
  This function adds a test that will build and install the project specified by SOURCE_DIR.
  An additional test is added that will uninstall the project.
  Parameters:
  - NAME: Name for this installed, can be used to reference this test in test_subdirectory
  - SOURCE_DIR: The source directory of the project to build and install
  - CONFIGURE_ARGS: Additional arguments to pass to CMake configure step
  - NO_UNINSTALL: If set, the uninstall will be skipped

  The build and install location are relative to the current binary directory.
  ]]
function(add_install_test)
  set(optionArgs NO_UNINSTALL)
  set(oneValueArgs SOURCE_DIR NAME)
  set(multiValueArgs CONFIGURE_ARGS)
  cmake_parse_arguments(PARSE_ARGV 0 arg "${optionArgs}" "${oneValueArgs}"
                        "${multiValueArgs}")
  if(NOT arg NAME)
    message(FATAL_ERROR "NAME argument is required")
  endif()
  if(NOT arg SOURCE_DIR)
    message(FATAL_ERROR "SOURCE_DIR argument is required")
  endif()
  set(test_name ${InstallTestPrefix}.${arg_NAME})
  set(build_dir ${CMAKE_CURRENT_BINARY_DIR}/${test_name}-build)
  set(install_dir ${CMAKE_CURRENT_BINARY_DIR}/${test_name}-install)

  add_test(
    NAME ${test_name}.install # name of the test
    COMMAND
      ${CMAKE_CTEST_COMMAND} --build-and-test #
      ${arg_SOURCE_DIR} # user provided source directory of this build
      ${build_dir} # the build directory
      --build-generator ${CMAKE_GENERATOR} --build-options #
      -DCMAKE_INSTALL_PREFIX=${install_dir} ${arg_CONFIGURE_ARGS} # pass user
                                                                  # provide args
                                                                  # to CMake
                                                                  # configure
                                                                  # step
      --build-target install)
  set_tests_properties(${test_name}.install PROPERTIES FIXTURES_SETUP
                                                       ${test_name}.fixture)
  if(NOT arg_NO_UNINSTALL)
    add_test(NAME ${test_name}.uninstall COMMAND ${CMAKE_COMMAND} -E rm -rf
                                                 ${install_dir} ${build_dir})
    set_tests_properties(${test_name}.uninstall PROPERTIES FIXTURES_CLEANUP
                                                           ${test_name}.fixture)
  endif()
  set_tests_properties(${test_name}.install PROPERTIES INSTALL_TEST_INSTALL_DIR
                                                       ${install_dir})
endfunction()

#[[
This function adds a test that will build and test the project specified by SOURCE_DIR.
The INSTALL_NAMES argument allows passing a list of install tests created via add_install_test.
The install directories of these tests are appended to CMAKE_PREFIX_PATH.
This also ensures that the install tests are run before this test.

This allows to test if the installed project can be found and used correctly.
Parameters:
- NAME: Name for this test
- SOURCE_DIR: The source directory of the project to build and test
- INSTALL_NAMES: List of names of install tests to append to CMAKE_PREFIX_PATH
- CONFIGURE_ARGS: Additional arguments to pass to CMake configure step

The build location is relative to the current binary directory.
]]
function(test_subdirectory)
  set(optionArgs "")
  set(oneValueArgs NAME SOURCE_DIR)
  set(multiValueArgs INSTALL_NAMES CONFIGURE_ARGS)
  cmake_parse_arguments(PARSE_ARGV 0 arg "${optionArgs}" "${oneValueArgs}"
                        "${multiValueArgs}")
  if(NOT arg NAME)
    message(FATAL_ERROR "NAME argument is required")
  endif()
  if(NOT arg_SOURCE_DIR)
    message(FATAL_ERROR "SOURCE_DIR argument is required")
  endif()
  if(arg_SOURCE_DIR STREQUAL ${PROJECT_SOURCE_DIR})
    message(
      FATAL_ERROR
        "Source directory cannot be the same as the project source directory")
  endif()
  set(prefix_path "")
  foreach(install_name IN LISTS arg_INSTALL_NAMES)
    set(test_name ${InstallTestPrefix}.${install_name})
    get_test_property(${test_name}.install INSTALL_TEST_INSTALL_DIR install_dir)
    if(NOT install_dir)
      message(FATAL_ERROR "No install dir found for ${test_name}")
    endif()
    list(APPEND prefix_path ${install_dir})
  endforeach()
  set(build_dir ${CMAKE_CURRENT_BINARY_DIR}/${arg_NAME}.link_install-build)
  add_test(
    NAME ${arg_NAME}.link_install
    COMMAND
      ${CMAKE_CTEST_COMMAND} --build-and-test #
      ${arg_SOURCE_DIR} # user provided source directory of this build
      ${build_dir} # the build directory
      --build-generator ${CMAKE_GENERATOR} --build-options #
      -DCMAKE_PREFIX_PATH=${prefix_path} ${arg_CONFIGURE_ARGS} # pass user
      # provide args to CMake configure step
      --test-command ${CMAKE_CTEST_COMMAND})
  foreach(install_name IN LISTS arg_INSTALL_NAMES)
    set(test_name ${InstallTestPrefix}.${install_name})
    set_tests_properties(${arg_NAME}.link_install
                         PROPERTIES FIXTURES_REQUIRED ${test_name}.fixture)
  endforeach()
endfunction()
