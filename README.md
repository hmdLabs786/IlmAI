<div align="center">
  <img src="assets/logo.png" width="100" height="100" alt="IlmAI Logo"/>
  <h1 align="center">IlmAI</h1>
  <p align="center"><strong>Your AI-Powered Academic Assistant for Pakistani Board Students</strong></p>
  <p align="center">
    <a href="https://play.google.com/store/apps/details?id=com.habban.ilmai">
      <img src="https://img.shields.io/badge/Google_Play-414141?style=for-the-badge&logo=google-play&logoColor=white" alt="Google Play"/>
    </a>
    <a href="https://apps.apple.com/app/ilmai">
      <img src="https://img.shields.io/badge/App_Store-0D96F6?style=for-the-badge&logo=app-store&logoColor=white" alt="App Store"/>
    </a>
    <a href="https://ilm-ai-web-ten.vercel.app">
      <img src="https://img.shields.io/badge/Visit_Website-1E3A8A?style=for-the-badge&logo=vercel&logoColor=white" alt="Website"/>
    </a>
  </p>
</div>

---

## About IlmAI

IlmAI is a comprehensive study companion designed specifically for **Pakistani board students** (Sindh Board, BSEK, BIEK, and more). Powered by Google Gemini AI, it provides personalised tutoring, exam preparation, smart revision tools, and board-aligned study materials — all in one app.

---

## Features

### 🤖 AI Tutor
Chat with an intelligent AI tutor that understands your board syllabus, class level, and academic performance. Get structured answers with LaTeX-rendered math, bullet-point explanations, and exam-focused tips.

### 📝 Revision Notes
Generate concise, board-aligned revision notes on any topic. Smart parsing renders mathematical expressions, bold/italic text, and structured headings beautifully.

### 📚 Library
Access a curated collection of Sindh Board textbooks and reference materials. Download books as PDFs with page selection and read them offline with the built-in PDF viewer.

### 📋 Exams & Tests
Practice with board-pattern mock exams. Get MCQs and full-length exam simulations with instant AI-powered feedback and marking.

### 🃏 Flashcards
Create and review AI-generated flashcards for any subject. Spaced repetition helps reinforce your learning.

### 📰 News Feed
Stay updated with the latest board announcements, exam schedules, and educational news from BSEK and BIEK.

### 📊 Study Analytics
Track your study progress with detailed analytics, including a study heatmap, weekly stats, and performance insights.

### 🌙 Dark Theme
Switch between light and dark themes. Your preference is saved and persists across sessions.

### 🔔 Notifications
Get study reminders, board news alerts, and personalised recommendations to stay on track.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter 3.x / Dart |
| **AI Engine** | Google Gemini 2.5 Flash |
| **Backend** | Firebase (Auth, Firestore, Storage, Messaging) |
| **State Management** | Provider |
| **Routing** | GoRouter |
| **PDF** | flutter_pdf / printing |
| **Math Rendering** | flutter_math_fork |
| **Icons** | flutter_launcher_icons |

---

## Screenshots

<div align="center">
  <table>
    <tr>
      <td><img src="screenshots/home.png" width="200" alt="Dashboard"/></td>
      <td><img src="screenshots/chat.png" width="200" alt="AI Chat"/></td>
      <td><img src="screenshots/exams.png" width="200" alt="Exams"/></td>
    </tr>
    <tr>
      <td align="center"><b>Dashboard</b></td>
      <td align="center"><b>AI Tutor</b></td>
      <td align="center"><b>Exams</b></td>
    </tr>
  </table>
</div>

---

## Getting Started

### Prerequisites
- Flutter SDK `>=3.0.0`
- Dart `>=3.0.0`
- Firebase project with Auth, Firestore, Storage, and Messaging enabled
- Google Gemini API key

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/hmdLabs786/IlmAI.git
   cd IlmAI
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Place your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in the respective platform directories
   - Or use FlutterFire CLI: `flutterfire configure`

4. **Add your Gemini API key**
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=your_key_here
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

### Build APK
```bash
flutter build apk --release
```

---

## Available on

<div align="center">
  <a href="https://play.google.com/store/apps/details?id=com.habban.ilmai">
    <img src="https://upload.wikimedia.org/wikipedia/commons/7/78/Google_Play_Store_badge_EN.svg" width="200" alt="Google Play"/>
  </a>
  <a href="https://apps.apple.com/app/ilmai">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" width="180" alt="App Store"/>
  </a>
</div>

---

## Visit Our Website

<div align="center">
  <a href="https://ilm-ai-web-ten.vercel.app">
    <img src="https://img.shields.io/badge/🌐_ilm--ai--web--ten.vercel.app-1E3A8A?style=for-the-badge" alt="Website"/>
  </a>
</div>

---

## License

This project is proprietary software. All rights reserved.

---

<div align="center">
  Made with ❤️ for Pakistani students
</div>
