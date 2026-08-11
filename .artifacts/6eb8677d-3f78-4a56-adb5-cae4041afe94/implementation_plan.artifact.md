# Implementation Plan - Theme Maintenance Page

This plan outlines the steps to add a theme maintenance (settings) page to the Mess Management application, allowing users to switch between Light, Dark, and System theme modes.

## User Review Required

> [!IMPORTANT]
> This change introduces the `provider` package for state management. This is the recommended approach for handling global application state like themes in Flutter.

## Proposed Changes

### Core
#### [NEW] [theme_provider.dart](file:///D:/all code/Flutter all projects/mess_management/lib/core/theme_provider.dart)
- Create a `ThemeProvider` class extending `ChangeNotifier`.
- Manage `ThemeMode` (light, dark, system).
- Persist theme selection using `SharedPreferences` (optional but recommended, will check if available).

#### [MODIFY] [pubspec.yaml](file:///D:/all code/Flutter all projects/mess_management/pubspec.yaml)
- Add `provider: ^6.1.1` dependency.
- Add `shared_preferences: ^2.3.2` for persistence.

#### [MODIFY] [main.dart](file:///D:/all code/Flutter all projects/mess_management/lib/main.dart)
- Wrap `MyApp` with `ChangeNotifierProvider<ThemeProvider>`.
- Configure `MaterialApp` to use `themeMode` from the provider.
- Define `darkTheme` in `MaterialApp`.

### Views
#### [NEW] [settings_page.dart](file:///D:/all code/Flutter all projects/mess_management/lib/views/settings/settings_page.dart)
- Implement a dedicated settings page.
- Add a section for "Theme Settings" with options for Light, Dark, and System Default.
- Use `RadioListTile` or a `Switch` for selection.

#### [MODIFY] [profile.dart](file:///D:/all code/Flutter all projects/mess_management/lib/views/member/profile.dart)
- Remove the local `SettingsPage` class.
- Update the navigation to point to the new `SettingsPage` file.

#### [MODIFY] [user_home.dart](file:///D:/all code/Flutter all projects/mess_management/lib/views/member/user_home.dart)
- Add a "Settings" option to the `Drawer` if not already present (it's currently missing, though "Profile" is there).
- Alternatively, ensure "Profile" -> "Settings" flow is clear.

## Verification Plan

### Automated Tests
- N/A (Manual UI verification)

### Manual Verification
1. Open the app and navigate to **Profile** -> **Settings**.
2. Change theme to **Dark Mode** and verify the whole app UI updates.
3. Change theme to **Light Mode** and verify.
4. Change theme to **System Default** and verify it follows device settings.
5. Restart the app and verify the theme preference is persisted (if SharedPreferences is implemented).
