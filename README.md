# Store App

A full-stack enterprise Store & Inventory Management System consisting of a **NestJS** backend, **MongoDB** database, and a cross-platform **Flutter** frontend (Web and Android).

---

## 📱 Download Android APK

The production release Android APK is built and ready for mobile testing and installation.

[![Download Android APK](https://img.shields.io/badge/Download-Android%20APK-2ea44f?style=for-the-badge&logo=android&logoColor=white)](https://github.com/anshumaan2503/store-app/releases/download/v1.0.0/app-release.apk)

* **Direct APK Download:** [Download app-release.apk](https://github.com/anshumaan2503/store-app/releases/download/v1.0.0/app-release.apk)
* **Local Extracted Binary:** `apk/app-release.apk`

---

## 🚀 Quick Setup & Run

For complete step-by-step instructions on running MongoDB in Docker, restoring the database seed data, starting the backend, and running the frontend, please refer to the dedicated guide:

👉 **[DOCKER_START_GUIDE.md](./DOCKER_START_GUIDE.md)**

---

## 📁 Repository Structure

```text
├── store_app_be/           # NestJS REST & WebSocket API Backend
├── store_app_fe/           # Flutter Cross-Platform Frontend (Web & Mobile)
├── dump/                   # Seed database dump (for MongoDB restoration)
├── DOCKER_START_GUIDE.md   # Complete step-by-step deployment & running guide
└── README.md               # Project overview
```

---

## ⚡ Fast Start Summary

```powershell
# 1. Start Docker Desktop and run MongoDB container
docker start store-app-mongo

# 2. Run Backend Server (Terminal 1)
cd store_app_be
npm install
npm run start:dev

# 3. For Android USB Testing (Terminal 2)
adb reverse tcp:8080 tcp:8080

# 4. Run Frontend (Terminal 3)
cd store_app_fe
flutter pub get
flutter run -d chrome    # Or 'flutter run' for Android
```

---

## 🔑 User Accounts & Roles

The system includes pre-configured seeded roles for testing all core workflows:
* **Super Admin**: Full administrative control and user management.
* **Store Receiver**: Inward goods receiving, inspection, and shelf placement.
* **Issue Requester**: Requisition slips and material requests.
* **Issue Approver**: Request approvals and authorization workflows.
* **Store Issuer**: Inventory dispatching, rack quantity allocation.
* **Store Returner**: Handling returns and scrap disposal.
* **Test User**: General floor testing.

> 🔒 **Security Notice:** Test account login credentials and passwords are maintained confidentially in the local `credentials.md` file (excluded from git) and shared privately with authorized evaluators.
