*** Settings ***
Documentation   Test to see if the Register struct correctly sets cpu registers
Suite Setup     Setup
Suite Teardown  Teardown
Test Setup      Load Machine
Test Teardown   Test Teardown
Resource        ${ZA_TEST_RESOURCES}

*** Test Cases ***
PRIMASK is true
    Execute Command  cpu PRIMASK 0x1
    Test Case        Passes  ${PRIMASK IS TRUE}

PRIMASK is false
    Execute Command  cpu PRIMASK 0x0
    Test Case        Passes  ${PRIMASK IS FALSE}

PRIMASK is false Fails
    Execute Command  cpu PRIMASK 0x1
    Test Case        Fails  ${PRIMASK IS FALSE}
