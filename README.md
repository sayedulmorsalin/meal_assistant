# 🍽️ Meal Assistant — Smart Mess Management System

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" />
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" />
  <img src="https://img.shields.io/badge/Version-1.0.0-green?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey?style=for-the-badge" />
</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.sayedulmarsalin.meal_assistant">
    <img src="https://img.shields.io/badge/Google%20Play-Download-414141?style=for-the-badge&logo=google-play&logoColor=white" />
  </a>
</p>

---

**Meal Assistant** is a full-featured Flutter application for managing shared meal systems (mess/hostel mess). It supports three user roles — **Admin**, **Manager**, and **Member** — each with a dedicated dashboard to handle meal tracking, shopping, messaging, planning, and more, all backed by Firebase.

---

## 📥 Download

<a href="https://play.google.com/store/apps/details?id=com.sayedulmarsalin.meal_assistant">
  <img alt="Get it on Google Play" src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" width="200"/>
</a>

> **Play Store Link:** https://play.google.com/store/apps/details?id=com.sayedulmarsalin.meal_assistant

---

## ✨ Features

### 👤 Role-Based Access
| Role | Description |
|------|-------------|
| **Admin** | Create and manage a mess, approve/reject join requests, oversee all members |
| **Manager** | Manage daily meals, shopping lists, meal planning, and member activity |
| **Member** | View meal history, submit meal requests, access shopping list & messaging |

### 🍛 Meal Management
- Add, edit, and delete daily meals for each member
- Track individual meal counts and costs
- View detailed meal history with calendar integration

### 🛒 Shopping Management
- Add and manage shared shopping items and costs
- Track who added what and when
- Real-time updates for all mess members

### 📅 Meal Planning
- Plan upcoming meals in advance
- Calendar-based view for easy scheduling
- Notify members of upcoming meal plans

### 💬 Messaging
- In-app group messaging for mess members
- Real-time chat powered by Cloud Firestore

### 📊 History & Reports
- Per-member meal and expense history
- Admin/Manager financial summaries
- Date-filtered history logs

### 🔐 Authentication
- Email/password sign-up & login via Firebase Auth
- Persistent login with shared preferences
- Secure role-based navigation on launch

### 🎨 Theming
- Light and Dark mode support
- Consistent Material 3 design language
- Custom color scheme with dynamic theming

---

## 🏗️ Architecture

```
lib/
├── core/
│   ├── app_colors.dart       # Global color palette
│   └── theme_provider.dart   # Light/Dark theme state management
├── models/
│   ├── user_model.dart
│   ├── mess_model.dart
│   ├── meal_model.dart
│   ├── meal_plan_model.dart
│   ├── log_model.dart
│   ├── request_model.dart
│   ├── join_request_model.dart
│   └── message_model.dart
├── services/
│   ├── auth_service.dart      # Firebase Authentication logic
│   └── database_service.dart  # Firestore CRUD operations
├── views/
│   ├── splash/                # Splash screen
│   ├── landing/               # Landing/onboarding page
│   ├── auth/                  # Login & Registration screens
│   ├── admin/                 # Admin dashboard & mess creation
│   ├── manager/               # Manager dashboard, meals, shopping, planning
│   ├── member/                # Member dashboard, history, requests, profile
│   └── settings/              # App settings
├── widgets/                   # Shared reusable UI components
└── main.dart                  # App entry point
```

---

## 🛠️ Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform UI framework |
| **Dart** | Programming language |
| **Firebase Auth** | User authentication |
| **Cloud Firestore** | Real-time NoSQL database |
| **Firebase Storage** | Profile image storage |
| **Provider** | State management |
| **Table Calendar** | Meal planning & history calendar |
| **Image Picker** | Profile photo upload |
| **Shared Preferences** | Local session persistence |
| **URL Launcher** | In-app external link handling |
| **HTTP** | REST API communication |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.7.0`
- Dart `>=3.0.0`
- A Firebase project with **Authentication**, **Firestore**, and **Storage** enabled
- Android Studio or VS Code

### 1. Clone the Repository

```bash
git clone https://github.com/sayedulmorsalin/meal_assistant.git
cd meal_assistant
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable **Email/Password Authentication**
3. Enable **Cloud Firestore** (start in test mode)
4. Enable **Firebase Storage**
5. Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
6. Place them in the respective platform directories:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

### 4. Environment Variables

Create a `.env` file at the root of the project (already gitignored) and configure any required API keys.

### 5. Run the App

```bash
flutter run
```

### 6. Build for Release (Android)

```bash
flutter build apk --release
# or for App Bundle
flutter build appbundle --release
```

---

## 📸 Screenshots

> Screenshots coming soon. Download the app from Google Play to see it in action!

---

## 🔒 Firestore Data Schema

Ensure your Firestore rules are properly configured to restrict data access by role. Data structure used in this app:

```
/users/{userId}              → User profiles & roles
/messes/{messId}             → Mess details
/messes/{messId}/meals       → Daily meal records
/messes/{messId}/shopping    → Shopping list items
/messes/{messId}/messages    → Group chat messages
/joinRequests/{requestId}    → Pending join requests
```

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 👨‍💻 Author

**Sayedul Morsalin**

- GitHub: [@sayedulmorsalin](https://github.com/sayedulmorsalin)
- App: [Meal Assistant on Google Play](https://play.google.com/store/apps/details?id=com.sayedulmarsalin.meal_assistant)

---

## 📄 License

This project is private and not licensed for public redistribution.

---

## 📞 Support & Feedback

If you encounter any issues or have suggestions, please:
- Open an [issue on GitHub](https://github.com/sayedulmorsalin/meal_assistant/issues)
- Or leave a review on the [Google Play Store](https://play.google.com/store/apps/details?id=com.sayedulmarsalin.meal_assistant)

---

<p align="center">Made with ❤️ using Flutter & Firebase</p>
