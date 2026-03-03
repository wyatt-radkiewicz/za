# Simple helper script to run renode-test
from robot.api import ExecutionResult, ResultVisitor
import argparse
import subprocess
import sys
import os

# To check results
class MyResultVisitor(ResultVisitor):
    def __init__(self, suite):
        self.suite = suite
        pass

    def visit_test(self, test):
        if test.status == 'FAIL':
            print(f"\"{self.suite}\" - \"{test.name}\" - \x1b[0;31;49m{test.status}\x1b[0;39;49m", file=sys.stderr)

    def end_result(self, result):
        pass

# Get command line arguments
def parse_args():
    parser = argparse.ArgumentParser(prog='run_tests', description='Runs za HAL tests')
    parser.add_argument('-p', '--platform', required=True)
    parser.add_argument('-s', '--suite', required=True)
    parser.add_argument('-t', '--timeout', required=True)
    parser.add_argument('-v', '--variables', required=True)
    parser.add_argument('-b', '--bin', required=True)
    parser.add_argument('-o', '--output', required=True)
    parser.add_argument('-d', '--tests_dir', required=True)
    return parser.parse_args()

# Entry point
def main():
    args = parse_args()

    # Run test
    tests_dir = os.path.abspath(args.tests_dir)
    renode = subprocess.run([
        "renode-test",
        "--variable",
        f"ZA_TEST_VARIABLES:{os.path.abspath(args.variables)}",
        "--variable",
        f"ZA_TEST_RESOURCES:{os.path.join(tests_dir, "scripts/test.resource")}",
        "--variable",
        f"ZA_TEST_TIMEOUT:{args.timeout}",
        "--variable",
        f"ZA_TEST_BIN:{os.path.abspath(args.bin)}",
        "--variable",
        f"ZA_TEST_PLATFORM:{os.path.join(tests_dir, "scripts", args.platform)}",
        "--variable",
        f"ZA_TEST_SCRIPT:{os.path.join(tests_dir, "scripts/init.resc")}",
        "-r",
        os.path.abspath(args.output),
        os.path.join(tests_dir, "suites", args.suite, "cases.robot"),
    ], capture_output=True)

    # Print out test results
    if renode.returncode != 0:
        result = ExecutionResult(os.path.join(args.output, "robot_output.xml"))
        result.visit(MyResultVisitor(args.suite))
        print(f"Report can be found at \"{args.output}\"", file=sys.stderr)
        exit(renode.returncode)

# Entry point
if __name__ == '__main__':
    main()
