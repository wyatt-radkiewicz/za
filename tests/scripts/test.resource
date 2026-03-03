*** Settings ***
Documentation   Robot framework resource file for za tests
Resource        ${RENODEKEYWORDS}
Resource        ${ZA_TEST_VARIABLES}

*** Keywords ***
Load Machine
    Test Setup
    Execute Command     set bin @${ZA_TEST_BIN}
    Execute Command     set platform @${ZA_TEST_PLATFORM}
    Execute Command     include @${ZA_TEST_SCRIPT}
    
Test Case
    [Arguments]         ${expected}  ${test_case}
    Create Log Tester   ${ZA_TEST_TIMEOUT}
    Execute Command     logLevel -1
    Execute Command     cpu AddSymbolHook "test_complete" "cpu.ErrorLog('test_complete')"
    Execute Command     sysbus WriteDoubleWord `sysbus GetSymbolAddress "test_case"` ${test_case}
    Start Emulation
    Wait For Log Entry  test_complete
    ${passed}           Execute Command  sysbus ReadDoubleWord `sysbus GetSymbolAddress "test_pass"`
    IF    $expected == "Passes"
        Should Be Equal As Numbers  ${passed}  1
    ELSE
        Should Be Equal As Numbers  ${passed}  0
    END
