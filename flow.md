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
| Reading      | Update page          | Progress bar (%), Mark finished, Put on hold |
| On hold      | Resume               | Progress bar, paused since <date>   |
| Finished     | Rate (1–10)          | Started/finished dates, duration, review |
| Abandoned    | Start again          | —                                   |

- Destructive actions (remove from library, clear log) go in the ⋮ menu.
- In Discover results, it also shows a match badge ("92% your taste").
- The rating sheet saves as soon as you tap a star, with no Save button.
- Rating: 5 stars with half-stars on screen, stored as an `int` from 1 to 10.
- Status changes on its own: current page > 0 → Reading; current page reaches `pageCount` → suggest Finished.
- Duration is worked out from the started/finished dates, never stored.
- Copy info rows: "Lent to Riya · 4 months ago", shelf + position, acquisition source (Bought / Gift / Borrowed / Library + from whom), language ("Read in English, originally Japanese").

### Data design: book facts vs copy facts
- **`BookModel` = facts about the book:** title, author, ISBN, pages, cover, genres, original language. These are the same for everyone.
- **`UserBookEntry` (was `ReadingLogEntry`) = facts about *this user's copy*:** status, current page, dates, rating, review, ranks, shelf, position, lent to, acquisition, reading language. Stored at `users/{uid}/readingLog/{googleBooksId}`.
- **Sessions:** `users/{uid}/readingLog/{id}/sessions/{auto}` = `{date, fromPage, toPage}`. A new one is written on every page update and feeds the heatmap and Insights.

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
- Filter chips: All · Reading · Want to read · On hold · Finished · Lent out.
- Genre chips that combine (e.g. Non-fiction + Classics).
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

### Priority order (set 2026-10-17)
1. **Book Detail + reading tracker** (Step 2.1–2.3 for the `googleBooksId` key, then Step 3) ← **current**
   - A book can be in 2 libraries but has **one** reading status. The log lives at user level (`users/{uid}/readingLog/{googleBooksId}`), not under a library, so every library copy reads the same entry.
   - Books saved before `googleBooksId` existed: fall back to `isbn` as the key (decide in planning).
2. **Profile page** (Step 10.1)
3. **Friends:** send/accept requests, open a friend's profile, see what they're reading (Step 10.2–10.4)
4. **Notifications** (Step 10.5)
5. Everything else in step order. Polish items wait for the test run.

### Step 1: Add to library from Search
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
- [ ] 2.4 Make `categories` a fixed genre tag list (about 8: Fiction, Non-fiction, Biography, Poetry, Classics, Self-help, …; more than one allowed). The backend AI maps the messy Google Books categories onto these tags
- [ ] 2.5 Add `originalLanguage` to `BookModel` (AI-suggested or entered by hand; Google Books only gives the edition's language)

### Step 3: Reading log (user's copy)
- [ ] 3.1 Create the `ReadingStatus` enum (notStarted/wantToRead, reading, onHold, finished, abandoned) and a `UserBookEntry` model (with a snapshot of the book info)
- [ ] 3.2 Create a `ReadingLogRepository` at `users/{uid}/readingLog/{googleBooksId}`
- [ ] 3.3 Add `readingLogEntryProvider(googleBooksId)`
- [ ] 3.4 Have Book Detail watch the provider and render the state table above
- [ ] 3.5 Build the Update page, Mark finished, and rating sheets (rating `int` 1–10, shown as half-stars)
- [ ] 3.6 Fix `deleteLibrary` so it also deletes the `books` subcollection
- [ ] 3.7 Automatic status changes: page > 0 → Reading; page == `pageCount` → suggest Finished
- [ ] 3.8 Write a `sessions` record `{date, fromPage, toPage}` on every page update
- [ ] 3.9 Copy fields on `UserBookEntry`: `shelf`, `position`, `lentTo`, `lentOn`, `acquisition` (+ from whom/where), `readingLanguage`, `review`
- [ ] 3.10 Book Detail rows and edit sheets for the copy fields (lend / return, shelf, acquisition)
- [ ] 3.11 Shelf-photo scan: when a whole shelf is added, fill in `position` from the left-to-right spine order

### Step 4: Scan modes
- [ ] 4.1 Create the `ScanMode` and `ScanInput` enums and the top toggle
- [ ] 4.2 Add the barcode scanner (Add mode only), the 978/979 filter, and dedup
- [ ] 4.3 Build the tray, then Done → picker
- [ ] 4.4 Build the Add review list with checkboxes

### Step 5: Home + Library polish
- [ ] 5.1 Home sections and empty state
- [ ] 5.2 Library filter chips (incl. On hold and Lent out)
- [ ] 5.3 Delete confirmation that shows the count
- [ ] 5.4 Genre filter chips that combine (multi-select)

### Step 6: Insights
- [ ] 6.1 Pure-Dart `ReadingStatsService`
- [ ] 6.2 Charts with `fl_chart` on the You tab
- [ ] 6.3 Reading heatmap (days read), built from `sessions`
- [ ] 6.4 (Later) Lending nudge: "You lent *X* 90 days ago"

### Step 7: Suggestions
- [ ] 7.1 Rule-based (categories + authors)
- [ ] 7.2 Embeddings in the Node API (all-MiniLM-L6-v2) → taste vector → cosine ranking
- [ ] 7.3 Discover ranking + match badge
- [ ] 7.4 (Stretch) Colab training

### Step 8: Rankings
- [ ] 8.1 One reusable drag-to-reorder widget (`ReorderableListView`), so ranks are unique and never clash
- [ ] 8.2 Three ranked lists on `UserBookEntry`: overall (per year), by cover, by title
- [ ] 8.3 (Fun) "Judge by cover": two covers side by side, "which is better?"

### Step 9: CSV import
- [ ] 9.1 Pick a CSV file and parse its rows
- [ ] 9.2 Match each row to a book by ISBN (fall back to a title search)
- [ ] 9.3 Review screen → picker → save the books plus their copy fields (status, dates, rating, …)

### Step 10: Profile + friends + notifications (plan details before building)
- [ ] 10.1 Profile page (You tab): public profile doc `users/{uid}` (displayName, photoUrl, unique lowercase `username` for search), edit sheet, counts (books, reading, finished)
- [ ] 10.2 Find people by username → send a friend request (`friendRequests/{fromUid}_{toUid}` with status pending/accepted/declined)
- [ ] 10.3 Incoming requests list → accept/decline. Accepting writes `users/{uid}/friends/{friendUid}` on both sides
- [ ] 10.4 Friend's profile: what they're reading / finished / ratings. Firestore rules let friends read `readingLog`
- [ ] 10.5 Notifications: in-app feed at `users/{uid}/notifications` (friend request, accepted, …) with an unread badge. Later: push via FCM, sent from the Node API
