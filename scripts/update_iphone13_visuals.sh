#!/bin/bash
set -euo pipefail

flutter test --update-goldens test/goldens/home_screen_iphone13_test.dart

echo "Updated iPhone 13 golden visuals."
