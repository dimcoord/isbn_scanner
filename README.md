# Book ISBN Barcode Scanner App (scanner_buku)

A Flutter application designed to scan book ISBN barcodes, automatically fetch detailed book metadata from international book databases, allow user review & editing, and transmit the final data to a customizable API endpoint.

---

## 🚀 Features

1. **Barcode / ISBN Scanning (`ScannerScreen`)**:
   - Fast ML Kit barcode scanning via `mobile_scanner`.
   - Supports **EAN-13** (standard ISBN-13), **ISBN-10**, **EAN-8**, **UPC-A**, **Code 128**, and QR codes.
   - Interactive camera viewfinder overlay with animated laser indicator.
   - Flashlight / Torch toggle and Camera Switch (front/back).
   - **Manual ISBN Input Fallback**: Allows testing or direct entry for damaged barcodes or emulator environments.

2. **Automatic Book Metadata Fetching (`BookFetchService`)**:
   - **Dedicated Indonesian Catalog Engine**:
     - Automatically recognizes Indonesian ISBNs (`978-602-`, `978-623-`, `978-979-`, etc.).
     - Queries **Indonesia OneSearch (IOS) by Perpustakaan Nasional Republik Indonesia (Perpusnas)** directly (`onesearch.id`).
     - Extracts title, subtitle, author names (cleaned from `LASTNAME, Firstname` or all-caps), publisher, publication year, category/genre, page count, and cover thumbnails.
   - **International & Fallback Providers**:
     - **Open Library**: Direct ISBN edition lookup and search fallback.
     - **Google Books**: Rich metadata with optional user API key support in Settings to avoid anonymous quota limits.
   - Graceful manual creation prompt if a book is not cataloged in any online database.

3. **User Review & Edit Screen (`BookReviewScreen`)**:
   - Visual book cover preview and ISBN badges.
   - Editable form fields: Title, Subtitle, Authors, Publisher, Published Date, ISBN, Page Count, Categories/Genres, Description, and Custom Notes / Shelf Location.
   - Prominent API target status banner displaying the current destination endpoint.
   - "Send to API" primary action with loading feedback and detailed response dialog.
   - "Save Locally (Don't Send Yet)" option to store as a local draft.

4. **Configurable API Endpoint (`ApiSettingsScreen`)**:
   - Set any custom API URL (e.g. `https://my-backend.com/api/books` or `http://10.0.2.2:8000/api/books`).
   - Default test endpoint: `https://httpbin.org/post` (echo test server).
   - Configure HTTP Method (**POST**, **PUT**, or **PATCH**).
   - Optional Authorization Header / API Key (auto-prepends `Bearer ` if needed).
   - Optional Payload Root Wrapper Key (e.g. `"book"` for `{"book": {...}}` or empty for direct JSON).
   - Optional Custom Headers in JSON format.
   - **Test Connection** button: Instantly sends a test ping to verify connectivity, HTTP status code, and server response before scanning books.

5. **Scanned Books History (`HistoryScreen`)**:
   - Persistent local storage using `SharedPreferences`.
   - Tracks sync status (`SENT`, `PENDING`, `FAILED`).
   - Filter chips: All, Sent, Pending / Failed.
   - Tap any past scan to re-review and re-send to your API.
   - Swipe to delete or clear all history.

---

## 📦 API Request Format

The app sends requests formatted exactly as specified:

```bash
curl -X POST http://127.0.0.1:8000/api/v1/books/isbn-scan \
  -H "Authorization: Bearer 2|xMfKgP7fOIHLvA7KpVjXl1Ijrg8bt3M1EaimTjtlccc0d98b" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
  "isbn": "9786020332956",
  "title": "Bumi Manusia",
  "author": "Pramoedya Ananta Toer",
  "publisher": "Hasta Mitra",
  "publication_year": 2005,
  "category_id": 8,
  "rack_location": "Rak-A1",
  "stock": 5,
  "cover_image": "https://example.com/covers/bumi-manusia.jpg"
}'
```

### JSON Payload Schema

| Field | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `isbn` | `string` | 10 or 13-digit ISBN code | `"9786020332956"` |
| `title` | `string` | Book title | `"Bumi Manusia"` |
| `author` | `string` | Book author (single string) | `"Pramoedya Ananta Toer"` |
| `publisher` | `string` | Publisher name | `"Hasta Mitra"` |
| `publication_year` | `integer` | 4-digit publication year | `2005` |
| `category_id` | `integer` | Backend category ID | `8` |
| `rack_location` | `string` | Shelf / rack designation | `"Rak-A1"` |
| `stock` | `integer` | Inventory count | `5` |
| `cover_image` | `string` | URL to book cover image | `"https://..."` |

---

## ⚙️ How to Insert Your API Endpoint

1. Launch the app and tap the **"API Config"** tab in the bottom navigation bar.
2. In the **Target API Endpoint URL** field, enter your endpoint:
   - For a public server: `https://api.yourdomain.com/v1/books`
   - For a local development server running on your computer when using the Android Emulator: `http://10.0.2.2:8000/books` (or your port)
   - For a local server when testing on a physical phone on the same Wi-Fi: `http://192.168.x.x:8000/books`
3. (Optional) Enter your **Authorization Token / API Key** or custom headers.
4. Tap **"Test Connection"** to verify that your API responds with a `200` / `201` status.
5. Tap **"Save Settings"**.

---

## 🛠 Running the Application

### Prerequisites
- Flutter SDK 3.12+ / 3.44+
- Android Studio / VS Code with Flutter extension
- An Android device or emulator with camera support

### Run tests:
```bash
flutter test
```

### Run app on Android:
```bash
flutter run
```
