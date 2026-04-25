# 🌊 UniFlow

<p align="center">
  <img src="assets/images/app_logo.png" width="150" alt="UniFlow Logo">
</p>

<p align="center">
  <strong>The Ultimate University Management System & Learning Platform</strong>
</p>

---

## 🚀 Overview

**UniFlow** is a comprehensive, cross-platform University ERP and Learning Management System (LMS) built with **Flutter** and **Firebase**. It streamlines the interaction between students, faculty, and administrators, providing a unified flow for all academic and administrative tasks.

Whether it's tracking attendance, submitting assignments, managing course registrations, or viewing academic results, UniFlow brings everything into one intuitive interface.

---

## ✨ Key Features

### 👨‍💼 Administrator Module
*   **User Management:** Seamlessly manage student and faculty accounts.
*   **Course Curator:** Create and configure academic courses and catalogs.
*   **Semester Registration Review:** Process and approve semester registration forms.
*   **Global Dashboard:** Monitor system-wide activity at a glance.

### 👩‍🏫 Faculty Module
*   **Attendance Management:** Mark attendance digitally and export records to **Excel**.
*   **Assignment Center:** Create assignments, set deadlines, and grade student submissions.
*   **Resource Sharing:** Upload study materials and Previous Year Questions (PYQs).
*   **Quiz Engine:** Create and manage interactive quizzes for continuous evaluation.
*   **Marks Entry:** Direct entry and management of internal/external marks.

### 🎓 Student Module
*   **Personal Dashboard:** Stay on top of your academic progress and upcoming deadlines.
*   **Course Hub:** Enroll in courses, view details, and access materials.
*   **Assignment Tracker:** Submit assignments and view grades/feedback.
*   **Result Sheet:** Detailed view of academic performance and transcripts.
*   **Semester Registration:** Integrated form submission for upcoming semesters.
*   **Interactive Quizzes:** Participate in quizzes and receive instant feedback.

---

## 🛠️ Technology Stack

UniFlow leverages modern technologies for a robust and scalable experience:

| Backend & Services | Frontend & State | Utilities |
| :--- | :--- | :--- |
| **Firebase Auth** (Security) | **Flutter** (UI Framework) | **Excel/PDF** (Doc Generation) |
| **Firestore** (Database) | **Provider** (State Management) | **Dio** (Networking) |
| **Cloud Messaging** (Push) | **Go Router** (Navigation) | **Google Fonts** (Typography) |

---

## 📁 Project Structure

The project follows a clean and modular architecture:

```text
lib/
├── core/       # Global constants, themes, and route configurations
├── data/       # Local database handlers or mock data
├── models/     # Data models for Students, Faculty, Courses, etc.
├── providers/  # Business logic and state management
├── screens/    # UI screens categorized by roles (Admin, Faculty, Student)
├── services/   # API and Firebase service implementations
└── widgets/    # Reusable UI components
```

---

## 🛠️ Getting Started

### Prerequisites
*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (Latest Stable version)
*   [Firebase Account](https://console.firebase.google.com/)
*   Android Studio / VS Code

### Setup Instructions

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/your-username/Uniflow.git
    cd Uniflow
    ```

2.  **Install Dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration:**
    *   Create a new project on the Firebase Console.
    *   Add Android/iOS/Web apps.
    *   Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
    *   Place them in the respective directories (`android/app/` and `ios/Runner/`).

4.  **Run the App:**
    ```bash
    flutter run
    ```

---

## 📱 Screenshots

<p align="center">
  <i>Screen mockups and real-world UI snapshots coming soon!</i>
</p>

---


