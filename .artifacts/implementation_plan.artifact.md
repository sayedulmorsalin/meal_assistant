# Fix Compilation Errors and Missing Imports

The project currently has several compilation errors following the folder reorganization. These are primarily due to missing imports, missing helper classes, and potentially stale analyzer data.

## Proposed Changes

### 1. Fix Missing Import in `user_home.dart`
- Add `import 'package:mess_management/models/request_model.dart';` to `lib/views/member/user_home.dart`.

### 2. Fix Missing Class in `add_shopping.dart`
- Add the `InputRow` class to `lib/views/manager/add_shopping.dart`. This class was lost during the reorganization.

### 3. Cleanup and Import Verification
- I will rewrite `lib/views/manager/manager_home.dart` and `lib/views/member/user_home.dart` using `write_file` to ensure there are no hidden characters or encoding issues that might be confusing the analyzer.
- I will verify that all class names match their usages across the project.

## Verification Plan

### Automated Tests
- Run `analyze_file` on all modified files to ensure zero errors and warnings.

### Manual Verification
- Check the `manager_home.dart` and `user_home.dart` files to ensure all navigation calls (e.g., to `Profile`, `History`, `Transaction`) are resolved.
