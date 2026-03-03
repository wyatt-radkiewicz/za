*** Settings ***
Documentation   Test to see if the Register struct correctly sets cpu registers
Suite Setup     Setup
Suite Teardown  Teardown
Test Setup      Load Machine
Test Teardown   Test Teardown
Resource        ${ZA_TEST_RESOURCES}

*** Test Cases ***
PRIMASK is true
    Execute Command  cpu PRIMASK 0x0
    Test Case        Passes  ${PRIMASK IS TRUE}
    ${primask}       Execute Command  cpu PRIMASK
    Should Be Equal As Numbers  ${primask}  0x1

PRIMASK is false
    Execute Command  cpu PRIMASK 0x1
    Test Case        Passes  ${PRIMASK IS FALSE}
    ${primask}       Execute Command  cpu PRIMASK
    Should Be Equal As Numbers  ${primask}  0x0
