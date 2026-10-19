# Comprehensive Setup & Deployment Guide: Store App

Complete guide to set up, initialize, and run the **Store App** project from scratch. Covers Docker container installation, database restoration from the included seed dump, starting the NestJS backend, and launching the Flutter frontend on Web, Android, or Docker.

---

## 📋 System Prerequisites

Ensure the following tools are installed on the host machine:
- **Docker Desktop** (with Linux containers enabled)
- **Node.js** (v18.x or v20.x LTS) & **npm**
- **Flutter SDK** (v3.x+) & Google Chrome (for web testing)
- **Android SDK & ADB** (Platform Tools) – if testing on Android mobile

---

## 1️⃣ Step 1: Start Docker & Setup MongoDB

### 1.0 Start Docker Desktop (Do this first!)
Before running any Docker commands, the Docker engine must be turned on:
1. Press the **Windows Key**, type **Docker Desktop**, and click to open it.
2. Look at the **bottom-left corner** of the Docker Desktop window: wait 15–30 seconds until the icon turns **green** and shows **"Engine running"**.
3. Verify it is running by opening PowerShell or Command Prompt and typing:
   ```bash
   docker ps
   ```
   *(If you see headers like `CONTAINER ID   IMAGE   COMMAND...` without errors, Docker is ready).*

> ⚠️ **Common Mistake:** If you see an error like *"failed to connect to the docker API / daemon is not running"*, it simply means Docker Desktop is not opened yet. Just open Docker Desktop and wait for the green status.

---

### 1.1 Pull MongoDB Docker Image
Once Docker Desktop is running, open a terminal (PowerShell or Command Prompt) and pull the official MongoDB image:
```bash
docker pull mongo:latest
```

### 1.2 Create and Run MongoDB Container
Run the container named `store-app-mongo` mapping port `27017` to localhost with a persistent volume:
```bash
docker run -d --name store-app-mongo -p 27017:27017 -v mongo_data:/data/db mongo:latest
```
*(If the container was already created previously, simply start it:)*
```bash
docker start store-app-mongo
```

### 1.3 Restore the Database Dump
Copy the project dump into the running MongoDB container and restore it into the `store_app_live` database:

**From the root project directory (`d:\store app`):**
```bash
# Copy the dump directory into the container
docker cp "dump/dump/store_app_live" store-app-mongo:/dump

# Execute mongorestore inside the container
docker exec -i store-app-mongo mongorestore --db store_app_live /dump
```

*(Optional Verification)*: Verify collections are imported:
```bash
docker exec -it store-app-mongo mongosh --eval "use store_app_live; db.getCollectionNames()"
```

---

## 2️⃣ Step 2: Configure & Start Backend (`store_app_be`)

The backend is built with NestJS and communicates with MongoDB on `mongodb://localhost:27017/store_app_live`.

### 2.1 Verify Environment Configuration
Check that `store_app_be/.env` exists. If not, create it with the following configuration:
```env
PORT=8080
MONGO_URI=mongodb://localhost:27017/store_app_live
JWT_SECRET=change_this_to_a_long_random_secret
JWT_EXPIRES=7d
GOOGLE_CLIENT_ID=66417910817-0tp2pn046499v2c5b0rqhj3tocgs3e9i.apps.googleusercontent.com

# MinIO Object Storage Configuration
MINIO_ENDPOINT=localhost
MINIO_PORT=9000
MINIO_ACCESS_KEY=your_minio_access_key
MINIO_SECRET_KEY=your_minio_secret_key
MINIO_BUCKET=store-app
```

### 2.2 Install Dependencies & Start Server
Open a terminal window and execute:
```bash
cd store_app_be
npm install
npm run start:dev
```

Wait until you see:
```text
Nest application successfully started
API on http://localhost:8080
```
Keep this terminal running.

---

## 3️⃣ Step 3: Mobile USB Bridge (Only for Physical Android Devices)

> 💡 **No Shared Wi-Fi Required:** Even if your phone and laptop are on different networks or mobile hotspot, Android Debug Bridge (ADB) forwards localhost calls through the USB cable directly to the backend.

1. Enable **Developer Options** and **USB Debugging** on your Android phone.
2. Connect your phone to your computer via USB.
3. Open a terminal and run ADB reverse port forwarding:
   ```bash
   adb reverse tcp:8080 tcp:8080
   ```
   *(If `adb` is not in your system PATH on Windows PowerShell, run:)*
   ```powershell
   & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8080 tcp:8080
   ```
4. **Verify Bridge:**
   ```bash
   adb reverse --list
   ```
   Output will show: `tcp:8080 tcp:8080`.  
   Requests from the phone to `http://localhost:8080` will now reach your laptop's backend server.

---

## 4️⃣ Step 4: Configure & Start Frontend (`store_app_fe`)

### 4.1 Install Dependencies
Open a new terminal window:
```bash
cd store_app_fe
flutter pub get
```

### 4.2 Run the App

#### 🌐 Option A: Run on Google Chrome (Web Browser)
```bash
flutter run -d chrome
```

#### 📱 Option B: Run on Android (Physical Device or Emulator)
```bash
flutter run
```
*(If multiple target devices are connected, Flutter will prompt you to pick one, or you can specify `-d android`)*.

#### 📦 Option C: Build Release APK
```bash
flutter build apk --release
```
The compiled APK will be generated at:
`store_app_fe/build/app/outputs/flutter-apk/app-release.apk`

To install it directly to your connected device:
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 5️⃣ Step 5: (Optional) Dockerize Backend & Frontend

If you wish to run the entire backend or frontend inside Docker containers:

### 5.1 Backend Docker Container
```bash
cd store_app_be
docker build -t store_app_be .
docker run -d --name store_app_be -p 8080:8080 --network host store_app_be
```

### 5.2 Frontend Docker Container (Nginx Web Server)
```bash
cd store_app_fe
flutter build web
docker build -t store_app_fe .
docker run -d --name store_app_fe -p 83:83 store_app_fe
```
Access the web frontend at `http://localhost:83`.

---

## 🔑 User Accounts & Testing Roles

The restored database comes pre-populated with accounts configured for each departmental workflow:
* **Super Admin**: System governance, permissions, master catalog configuration.
* **Store Receiver**: Material inward receiving, PO inspection, and rack storage.
* **Issue Requester**: Departments raising material requests & indent slips.
* **Issue Approver**: Department heads approving or rejecting issue requests.
* **Store Issuer**: Physical warehouse dispatch & rack inventory adjustments.
* **Store Returner**: Handling returned items and scrap tracking.
* **Test User**: General walkthrough and verification.

> 🔒 **Security Notice:** For security and privacy, test user credentials (phone numbers, emails, and passwords) are kept in the private `credentials.md` file (excluded from git) or shared directly with authorized project evaluators.

---

## ⚡ Quick Daily Workflow Cheat Sheet

```powershell
# 0. Open Docker Desktop from Start menu (wait until icon turns green)

# 1. Start MongoDB
docker start store-app-mongo

# 2. Start Backend (Terminal 1)
cd store_app_be ; npm run start:dev

# 3. For USB Phone Testing - Port Forward (Terminal 2)
adb reverse tcp:8080 tcp:8080

# 4. Start Frontend (Terminal 3)
cd store_app_fe ; flutter run -d chrome    # Or: flutter run
```

---

## 🛠️ Troubleshooting

- **MongoDB connection refused**:
  Verify container status with `docker ps`. If stopped, execute `docker start store-app-mongo`.
- **Port 8080 already in use**:
  Check if another node process is running: `Get-Process -Id (Get-NetTCPConnection -LocalPort 8080).OwningProcess` on Windows, or kill conflicting processes.
- **Phone cannot reach Backend**:
  Whenever you disconnect or re-plug the USB cable, re-run `adb reverse tcp:8080 tcp:8080`.
- **Database is empty**:
  Run the dump restore command from Step 1.3:
  `docker cp "dump/dump/store_app_live" store-app-mongo:/dump` followed by `docker exec -i store-app-mongo mongorestore --db store_app_live /dump`.
