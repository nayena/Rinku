# 🧠 Rinku AI

**A gentle memory companion for those living with Alzheimer's**

Rinku AI is an iOS app designed to help people with memory challenges recognize their loved ones through face recognition technology. The app provides gentle audio reminders about relationships and memories associated with each person.

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2016%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-4.0-green" alt="SwiftUI">
  <img src="https://img.shields.io/badge/License-MIT-lightgrey" alt="License">
</p>

---

## ✨ Features

### 👥 Loved Ones Management
- Add profiles for family members and friends
- Include photos, relationships, and memory prompts
- Organize and search through your loved ones

### 📷 Face Recognition
- Real-time face detection using AWS Rekognition
- Offline face caching for recognition without internet
- Support for Meta Smart Glasses hands-free recognition

### 🔊 Audio Reminders
- Text-to-speech announces who the person is
- Includes relationship and memory prompts
- **Bilingual support** - English and Spanish

### 👨‍👩‍👧‍👦 Family Sharing
- Share loved ones profiles with caregivers
- Family invite codes for easy setup
- Sync across multiple devices

### 🌐 Bilingual Support
- Full English and Spanish interface
- In-app language switching
- Localized text-to-speech

### 🕶️ Meta Smart Glasses Integration
- Hands-free face recognition
- Works with Ray-Ban Meta Smart Glasses
- Bluetooth connectivity

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| **UI Framework** | SwiftUI |
| **Backend** | Supabase (Auth, Database, Storage) |
| **Face Recognition** | AWS Rekognition |
| **Text-to-Speech** | AVSpeechSynthesizer |
| **Smart Glasses** | Meta Wearables DAT SDK |
| **Local Storage** | UserDefaults, FileManager |

---

## 📋 Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+
- AWS Account (for face recognition)
- Supabase Project (for backend)

---

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/jayvura/RinkuAppTest.git
cd RinkuAppTest
```

### 2. Configure Secrets

Copy the template and add your credentials:

```bash
cp RinkuApp/Secrets.template.plist RinkuApp/Secrets.plist
```

Edit `Secrets.plist` with your actual values:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>AWS_ACCESS_KEY_ID</key>
    <string>your-aws-access-key</string>
    <key>AWS_SECRET_ACCESS_KEY</key>
    <string>your-aws-secret-key</string>
    <key>AWS_REGION</key>
    <string>us-east-1</string>
    <key>SUPABASE_URL</key>
    <string>https://your-project.supabase.co</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>your-supabase-anon-key</string>
</dict>
</plist>
```

### 3. Open in Xcode

```bash
open RinkuApp.xcodeproj
```

### 4. Build and Run

Select your target device/simulator and press `Cmd + R`

---

## 🗄️ Supabase Setup

### Required Tables

```sql
-- Loved Ones
CREATE TABLE loved_ones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    family_id UUID REFERENCES families(id),
    full_name TEXT NOT NULL,
    familiar_name TEXT,
    relationship TEXT NOT NULL,
    memory_prompt TEXT,
    enrolled BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Photos
CREATE TABLE photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    loved_one_id UUID REFERENCES loved_ones(id),
    user_id UUID REFERENCES auth.users(id),
    storage_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Families
CREATE TABLE families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_by UUID REFERENCES auth.users(id),
    invite_code TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Family Members
CREATE TABLE family_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES families(id),
    user_id UUID REFERENCES auth.users(id),
    role TEXT CHECK (role IN ('patient', 'caregiver')),
    joined_at TIMESTAMPTZ DEFAULT now()
);
```

### Storage Bucket

Create a private bucket named `face-photos` for storing user photos.

---

## 📁 Project Structure

```
RinkuApp/
├── App/
│   ├── RinkuApp.swift          # App entry point
│   └── ContentView.swift       # Main navigation
├── Views/
│   ├── HomeView.swift          # Home screen
│   ├── LovedOnesView.swift     # List of loved ones
│   ├── AddLovedOneView.swift   # Add new person
│   ├── RecognizeView.swift     # Camera recognition
│   ├── ProfileView.swift       # Settings & profile
│   └── ...
├── Components/
│   ├── TabBar.swift            # Bottom navigation
│   ├── LanguagePickerItem.swift # Language selector
│   └── ...
├── Services/
│   ├── LanguageManager.swift   # Bilingual support
│   ├── AudioService.swift      # Text-to-speech
│   ├── SupabaseService.swift   # Backend API
│   ├── AWSRekognitionService.swift # Face recognition
│   ├── PhotoStorage.swift      # Local photo storage
│   └── ...
├── Models/
│   ├── LovedOne.swift
│   ├── Family.swift
│   └── ...
├── Store/
│   └── AppStore.swift          # App state management
├── en.lproj/
│   └── Localizable.strings     # English translations
├── es.lproj/
│   └── Localizable.strings     # Spanish translations
└── Utilities/
    └── Theme.swift             # Design system
```

---

## 🌍 Localization

The app supports English and Spanish. To add a new language:

1. Create a new folder: `{language_code}.lproj/`
2. Copy `Localizable.strings` from `en.lproj/`
3. Translate all strings
4. Add the language code to `knownRegions` in the Xcode project

---

## 🔒 Privacy & Security

- **Local-first**: Photos are stored locally for fast access
- **Encrypted sync**: Data synced via Supabase with RLS policies
- **No tracking**: No analytics or third-party tracking
- **User control**: All data can be deleted by the user

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'feat: Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 💜 Acknowledgments

- Built with love for those affected by Alzheimer's and their caregivers
- Thanks to the open-source community for the amazing tools and libraries

---

<p align="center">
  <strong>Rinku AI</strong> - Helping memories stay connected 💜
</p>
