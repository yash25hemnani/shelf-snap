# Shelf Snap: UI flow and build steps

Local working notes, not committed. Tick each box as you finish it.

---

## 1. App map

```
Bottom nav:  Home · Search · Scan · Library · You
                         │
                         ▼
                  Book Detail  ◄── reached from Search, Scan, Library, Home
```

**Book Detail is the hub.** Every book you tap opens it, and what it shows depends on the book's state:

| State        | Main action          | Also shows                          |
|--------------|----------------------|-------------------------------------|
| Not saved    | Add to library       | Want to read                        |
| Want to read | Start reading        | "In: <libraries>" row               |
| Reading      | Update page          | Progress bar, Mark finished         |
| Finished     | Rate (stars)         | Started/finished dates, notes       |
| Abandoned    | Start again          | —                                   |

- Destructive actions (remove from library, clear log) go in the ⋮ menu.
- In Discover results, it also shows a match badge ("92% your taste").
- The rating sheet saves as soon as you tap a star, with no Save button.

---

## 2. Screens

### Search
```
[ Title, author or ISBN    🔍 ]
┌───┐ ┌───┐ ┌───┐
│   │ │   │ │   │   tap → Book Detail (Not saved) → Add to library
└───┘ └───┘ └───┘                                   → Library picker → snackbar
```

### Scan
```
  [ ●Add | Discover ]
      camera preview
  ( 📷 Shelf ) ( ‖‖ ISBN )   ← only in Add mode
           ◉
```

| Mode     | Shelf photo                                   | Barcode (ISBN)                       |
|----------|-----------------------------------------------|--------------------------------------|
| Add      | Review list (checkboxes, "Fix" → Search) → picker | Continuous scan → tray → Done → picker |
| Discover | Ranked spines, top 3 highlighted              | Not offered                          |

Rules:
- Switching to Discover resets the input to Shelf and **stops** the barcode camera.
- Barcode: accept only EAN-13 codes starting with 978 or 979, and ignore repeat detections of the same code.

### Library
- A list of libraries; tap one → its books grid → Book Detail.
- Filter chips: All · Reading · Want to read · Finished.
- Deleting a library asks for confirmation and shows the book count ("Delete 'Fiction' and its 24 books?").

### Home
1. Continue reading (books with status = reading)
2. For you (suggestions)
3. Recently added
- Empty state: "Scan your first shelf" → Scan.

### You (replaces Profile)
- Insights (charts)
- Your taste (top categories/authors)
- Settings

### Onboarding (later)
- "Pick 3 books you loved" seeds the taste vector.

---

## 3. Build steps

### Step 1: Add to library from Search  ← **current**
- [ ] 1.1 Make `LibraryPickerSheet` take `List<BookModel>` instead of `List<ScoredBookResult>`
- [ ] 1.2 Update the scanner's call site to pass `_results.map((r) => r.book).toList()`
- [ ] 1.3 Make the picker save **all** book fields, not just title/author/isbn/cover
- [ ] 1.4 In `search_screen.dart`, have `onAdd` open the picker with `[book]`
- [ ] 1.5 After saving: pop Book Detail and show a snackbar
- [ ] 1.6 Clean up: `.trim()` the query and remove the unused `widgets.dart` import

### Step 2: Model fields
- [ ] 2.1 Add `googleBooksId` and `categories` to `BookModel` (fields, toMap, fromMap)
- [ ] 2.2 Return them from the backend search and identify endpoints
- [ ] 2.3 Parse them in `book_search_service.dart` and `book_identification_service.dart`

### Step 3: Reading log
- [ ] 3.1 Create the `ReadingStatus` enum and a `ReadingLogEntry` model (with a snapshot of the book info)
- [ ] 3.2 Create a `ReadingLogRepository` at `users/{uid}/readingLog/{googleBooksId}`
- [ ] 3.3 Add `readingLogEntryProvider(googleBooksId)`
- [ ] 3.4 Have Book Detail watch the provider and render the state table above
- [ ] 3.5 Build the Update page, Mark finished, and rating sheets
- [ ] 3.6 Fix `deleteLibrary` so it also deletes the `books` subcollection

### Step 4: Scan modes
- [ ] 4.1 Create the `ScanMode` and `ScanInput` enums and the top toggle
- [ ] 4.2 Add the barcode scanner (Add mode only), the 978/979 filter, and dedup
- [ ] 4.3 Build the tray, then Done → picker
- [ ] 4.4 Build the Add review list with checkboxes

### Step 5: Home + Library polish
- [ ] 5.1 Home sections and empty state
- [ ] 5.2 Library filter chips
- [ ] 5.3 Delete confirmation that shows the count

### Step 6: Insights
- [ ] 6.1 Pure-Dart `ReadingStatsService`
- [ ] 6.2 Charts with `fl_chart` on the You tab

### Step 7: Suggestions
- [ ] 7.1 Rule-based (categories + authors)
- [ ] 7.2 Embeddings in the Node API (all-MiniLM-L6-v2) → taste vector → cosine ranking
- [ ] 7.3 Discover ranking + match badge
- [ ] 7.4 (Stretch) Colab training
