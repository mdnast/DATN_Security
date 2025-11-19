# WardMail – AI‑powered phishing email detection app

WardMail is a Flutter mobile/desktop application that helps users detect and avoid phishing emails by combining multiple security layers (Firebase Authentication, biometric login, reCAPTCHA, AI‑based content analysis) with a clean and intuitive UI.

---

## 🎯 Project goals

- Provide **secure login** with multiple authentication methods.
- **Read and manage emails** from Gmail and other IMAP mailboxes.
- **Detect phishing emails** based on content, links, sender and other email features.
- Offer **statistics, reports**, and **real‑time alerts** when suspicious activity is detected.

> Status: **Core features for the graduation thesis (DATN) have been completed.**

---

## ✨ Key features

### 1. 🔐 Authentication & security
- Login with **Google Sign‑In**.
- Register / login with **Email & Password** (Firebase Authentication + email verification).
- **Biometric authentication** (fingerprint / Face ID) to lock/unlock the app.
- **reCAPTCHA Enterprise** to protect login and registration forms from automated attacks.
- Session management and secure token storage using `flutter_secure_storage`.

### 2. 📧 Email management & reading
- Integrates **Gmail API** to fetch and read emails from a Gmail account.
- Supports **IMAP** via `enough_mail` for other mail providers.
- Intuitive email list with basic categorization.
- Detailed email view, including HTML content rendered via `webview_flutter`.

### 3. 🤖 AI‑based phishing detection
- Uses **Google Generative AI (Gemini)** (`google_generative_ai`) to analyze email content.
- Evaluates **subject, body, links, sender** to estimate phishing risk.
- Assigns **risk levels** (safe / suspicious / dangerous) to each email.
- Stores analysis history so users can review past results.

### 4. 📊 Statistics & reports
- **Dashboard** with an overview of scanned emails and distribution of safe/suspicious/dangerous messages.
- Visual charts built with `fl_chart` to show trends and common attack types.
- **Export reports** as **PDF** (`pdf`) and **CSV** (`csv`).
- Share reports via email or other apps with `share_plus`.

### 5. 🔔 Notifications & background tasks
- **Firebase Cloud Messaging** (`firebase_messaging`) for push notifications.
- Local alerts using `flutter_local_notifications` when high‑risk emails are detected.
- Periodic background jobs with `workmanager` (e.g., check new emails, refresh stats).

### 6. 🎨 User interface
- Built with **Material Design 3**, supports **multi‑language UI** (see `localization/`).
- Optimized layouts for multiple screen sizes.
- Reusable custom widgets stored in `widgets/`.

---

## 🛠 Tech stack & main packages

### Language & framework
- **Flutter** (project environment: `sdk: ^3.9.2`).
- **Dart** 3.x.

### Auth & backend
- `firebase_core`, `firebase_auth` – user authentication and session management.
- `google_sign_in` – Google login.
- `recaptcha_enterprise_flutter` – reCAPTCHA Enterprise integration.

### Email & networking
- `googleapis`, `googleapis_auth` – Gmail API integration.
- `enough_mail` – IMAP client.
- `http` – REST/HTTP requests.
- `webview_flutter` – display HTML email content.

### AI & analysis
- `google_generative_ai` – calls Gemini models to analyze email content.

### Storage & security
- `flutter_secure_storage` – secure token/credential storage.
- `shared_preferences` – store user preferences and basic settings.
- `local_auth` – biometric authentication.

### Notifications, background & utilities
- `firebase_messaging` – push notifications.
- `flutter_local_notifications` – local notifications.
- `workmanager` – background tasks.
- `pdf`, `csv`, `path_provider` – export and store reports.
- `fl_chart` – data visualization.
- `share_plus` – share files/reports.
- `file_picker` – choose files when importing/exporting data.

---

## 📋 System requirements

- **Flutter SDK**: `>= 3.9.2`.
- **Android**: API level 21 (Android 5.0) or higher.
- **Windows**: Windows 10 or higher (for desktop build).

> iOS builds are possible with proper Xcode and certificate setup, but the main focus of this thesis is Android/Windows.

---

## 🔧 Setup & run

### 1. Clone the repository
```bash

cd DATN---GuardMail
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
- Create a project in [Firebase Console](https://console.firebase.google.com/).
- Add an Android app (and Windows if needed).
- Download config files:
  - Android: `google-services.json` → `android/app/`.
- Enable **Authentication** (Email/Password, Google) and **Cloud Messaging** if you use push notifications.

### 4. Configure Google Sign‑In, Gmail API & Generative AI
- Create an OAuth 2.0 Client ID in [Google Cloud Console](https://console.cloud.google.com/).
- Add your app SHA‑1/SHA‑256 fingerprints.
- Enable required APIs (e.g. Gmail API, Generative Language API) and wire the keys into the app code.

### 5. Run the app
```bash
# Android (device or emulator)
flutter run

# Windows
flutter run -d windows
```

---

## 📁 Main project structure

```text
lib/
├── main.dart        # App entry point
├── img/             # Logos and images
├── localization/    # Localization and translations
├── models/          # Data models (email, user, analysis results, ...)
├── screens/         # UI screens
├── services/        # Business logic & API services (auth, Gmail, AI, ...)
└── widgets/         # Reusable widgets
```

---

## 🔒 Security

- Passwords are handled by **Firebase Authentication**.
- Auth tokens are stored securely using **Secure Storage**, never as plain text.
- **Biometric authentication** (fingerprint / Face ID) can be required to open the app.
- The app does **not** upload email content to any custom server beyond Gmail/IMAP.
- All network traffic uses HTTPS/SSL.

---

## 🎓 Graduation thesis information (DATN)

- Topic: **Building the WardMail application to detect phishing emails using AI**.
- Completed modules:
  - Multi‑layer authentication (Firebase + Google + biometrics + reCAPTCHA).
  - Email reading integration (Gmail API, IMAP).
  - AI‑powered email analysis with Gemini and risk scoring.
  - Statistics, reporting and export modules.
  - Notifications and background processing.

---

## 👨‍💻 Author

**Team 2**  
Contact email: **datlecong156@gmail.com**

---

## 📞 Contact & feedback

- For questions, suggestions or discussions about the project, please reach out via email.
- You can also open an issue in this repository to report bugs or request new features.



