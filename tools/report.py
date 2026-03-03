# Simple helper script to simply report info of an executed test
# Based off of https://docs.robotframework.org/docs/parsing_results
from robot.api import ExecutionResult, ResultVisitor
import sys

class MyResultVisitor(ResultVisitor):
    def __init__(self):
        print(f"==========")
        pass

    def visit_test(self, test):
        print(f"{test.name} - {test.status}")

    def end_result(self, result):
        pass

# Prints out usage message
def usage():
    print("usage:")
    print(f"\t{sys.argv[0]} <output.xml>")
    exit()

# Entry point
if __name__ == '__main__':
    if len(sys.argv) < 2:
        usage()
    output_file = sys.argv[1]
    result = ExecutionResult(output_file)
    result.visit(MyResultVisitor())
