# Test to see if the Register struct correctly sets cpu registers
*** Test Cases ***
PRIMASK is True
    Test Completes with  5000     ${Input PRIMASK is true}
    Cpu has              PRIMASK  True

PRIMASK is False
    Test Completes with  5000     ${Input PRIMASK is false}
    Cpu has              PRIMASK  False
