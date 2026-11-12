"""Owned command doubles validate the compile gate; they do not compile iOS."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "build-ios-simulator-ci.sh"

class IOSCompileGateTests(unittest.TestCase):
    def run_gate(self, **options):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "scripts").mkdir()
            shutil.copy2(SCRIPT, root / "scripts" / SCRIPT.name)
            commands = root / "bin"
            commands.mkdir()
            doubles = {
                "uname": '#!/bin/sh\n[ "$1" = "-s" ] && echo Darwin || echo arm64\n',
                "git": '#!/bin/sh\necho owned-compile-checkout\n',
                "xcrun": '#!/bin/sh\necho owned-tool-version\n',
                "xcodebuild": '''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as log: log.write(json.dumps(args) + '\\n')
if '-version' in args:
    print('Xcode 26.3'); sys.exit(0)
if '-showBuildSettings' in args:
    print(json.dumps([{'target':'TaskovskyMobile','buildSettings':{'PLATFORM_NAME':'iphonesimulator','IPHONEOS_DEPLOYMENT_TARGET':'17.0','ARCHS':os.environ.get('BAD_ARCH','arm64'),'CODE_SIGNING_ALLOWED':'NO'}}])); sys.exit(0)
if os.environ.get('FAIL_BUILD'): sys.exit(7)
assert args[-1] == 'build-for-testing'
assert 'test' not in args and '-allowProvisioningUpdates' not in args
assert 'CODE_SIGNING_ALLOWED=NO' in args and 'CODE_SIGNING_REQUIRED=NO' in args
assert args[args.index('-destination')+1] == 'generic/platform=iOS Simulator'
products = pathlib.Path(args[args.index('-derivedDataPath')+1]) / 'Build/Products'
app = products / 'Debug-iphonesimulator/TaskovskyMobile.app'
app.mkdir(parents=True)
(app/'TaskovskyMobile').write_text('owned dummy binary')
for name in ('MobileContracts.xctest','MobileNavigation.xctest'):
    if os.environ.get('OMIT_TEST') != name: (products/name).mkdir()
(products/'TaskovskyMobile.xctestrun').write_text('owned dummy manifest')
''',
            }
            for name, content in doubles.items():
                path = commands / name
                path.write_text(content)
                path.chmod(0o755)
            calls = root / "calls.jsonl"
            env = dict(os.environ, PATH=str(commands) + os.pathsep + os.environ["PATH"], CALLS=str(calls), **options)
            result = subprocess.run(["bash", str(root / "scripts" / SCRIPT.name)], env=env, text=True, capture_output=True)
            recorded = [json.loads(line) for line in calls.read_text().splitlines()]
            return result, recorded

    def test_builds_without_test_execution_or_signing(self):
        result, calls = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sum(call[-1:] == ["build-for-testing"] for call in calls), 1)
        self.assertIn("no tests executed", result.stdout)

    def test_build_failure_survives_tee(self):
        result, _ = self.run_gate(FAIL_BUILD="1")
        self.assertEqual(result.returncode, 7)

    def test_wrong_resolved_architecture_refuses_before_build(self):
        result, calls = self.run_gate(BAD_ARCH="x86_64")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[-1:] == ["build-for-testing"] for call in calls))

    def test_missing_test_bundle_is_not_a_pass(self):
        result, _ = self.run_gate(OMIT_TEST="MobileNavigation.xctest")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing compiled test bundle", result.stderr)

if __name__ == "__main__":
    unittest.main()
