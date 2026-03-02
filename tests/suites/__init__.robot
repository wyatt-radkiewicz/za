# Initialization file for test case suites
*** Settings ***
Suite Setup     Setup Test Machine
Suite Teardown  Teardown
Test Teardown   Test Teardown
Resource        ${RENODEKEYWORDS}

*** Variables ***

*** Keywords ***
Setup Test Machine
    Setup
    
