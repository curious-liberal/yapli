## 📌 Project Overview

**Purpose**
A minimalist web-based chatroom app for educational workshops. Facilitators can create scheduled chatrooms to share links and text in real time with participants using temporary aliases. At the end of the session, the chat becomes read-only and acts as a record of the day’s collaboration.

---

## 🧱 Core Features

### Facilitators

- Can register/login via **email/password** or **OAuth** (Google/GitHub).
- Can **create chatrooms** with:

  - Title (must be unique per facilitator)
  - Start time
  - End time
  - Password (required for access, hashed before storage)

- Can view all past and upcoming chatrooms in a dashboard.
- Can delete any chatroom (before or after it ends).
- No editing of chatrooms after creation.
- No admin privileges during chat—equal to participants.

### Participants

- Join via **link + password**.
- Enter any alias (no validation or uniqueness enforced).
- Can join/leave freely while the room is live.
- Alias is fixed per session.
- Can send **plain text messages** (with automatic link detection).
- Can see a **live list of current aliases**.
- Can copy individual messages.
- Can’t edit or delete messages.
- Can’t change alias mid-session.
- No signup or account needed.

### Chatroom Behaviour

- Completely inaccessible until the start time.
- Only accessible during the scheduled window.
- Ends silently and becomes **read-only**.
- Transcript is visible to **anyone with the original link**.
- Transcript displays messages only—no alias list, no timestamps beyond what’s shown inline.
- Transcript is stored indefinitely unless deleted by the facilitator.

---

## 🏗️ Architecture

### Frontend

- **Next.js (App Router)**, responsive layout.
- WebSockets for live messaging and alias tracking.
- Light/Dark mode toggle.
- Message list: continuous scroll, auto-scrolls to bottom on new message.
- Timestamp, alias, and message displayed for each post.
- “Copy” button per message.

### Backend

- **PostgreSQL** for persistent data (hosted or local).
- **Node.js WebSocket server** (self-hosted) for real-time events.
- REST/GraphQL API for chatroom creation, login, message history, etc.
- Session management via cookies or secure tokens (httpOnly).
- Passwords (both user and room) hashed using bcrypt.

---

## 🗃️ Database Schema (simplified)

### Users (facilitators)

```sql
id UUID PK
email TEXT UNIQUE
password_hash TEXT
created_at TIMESTAMP
auth_provider TEXT
```

### Chatrooms

```sql
id UUID PK
user_id FK -> Users(id)
title TEXT UNIQUE (per user)
start_time TIMESTAMP
end_time TIMESTAMP
password_hash TEXT
created_at TIMESTAMP
```

### Messages

```sql
id UUID PK
chatroom_id FK -> Chatrooms(id)
alias TEXT
message TEXT
timestamp TIMESTAMP
```

### ActiveSessions (in-memory or ephemeral store, e.g. Redis)

```
chatroom_id -> Set of aliases (for presence tracking)
```

---

## 🔐 Security & Privacy

- All passwords (user + room) are hashed using **bcrypt**.
- No data is indexed by search engines (robots.txt + meta tags).
- Alias data is never stored beyond the active session.
- No message moderation or filtering; content is user-generated.
- Transcripts are public via the shareable link but not discoverable.

---

## ⚠️ Error Handling Strategy

| Action                     | Error Case           | Handling                          |
| -------------------------- | -------------------- | --------------------------------- |
| Join chatroom              | Wrong password       | Show error, stay on login screen  |
| Join before start time     | Room locked          | Show generic “Room not available” |
| Send message               | Empty message        | Prevent sending                   |
| Chatroom not found         | Invalid link         | Show 404                          |
| WebSocket drop             | Connection loss      | Retry logic with backoff          |
| Duplicate title (creation) | Constraint violation | Show “Title already used”         |

---

## ✅ Testing Plan

### Unit Tests

- User authentication (email + OAuth)
- Password hashing + validation
- Chatroom creation constraints
- Message storage + formatting
- Alias handling logic

### Integration Tests

- Login → create → join → send → end flow
- Transcript visibility rules
- Presence tracking (join/leave behaviour)

### UI Tests

- Light/Dark mode toggle
- Copy button per message
- Form validation (chatroom creation, login)
- Mobile/responsive layout checks

### Load Testing (Optional for now)

- Concurrent participants in a live chatroom
- Message volume limits (if later added)

---

## 🧪 Dev Notes

- Use `socket.io` or `ws` for WebSockets.
- Use Prisma or another ORM for DB handling.
- Consider Redis or in-memory store for live alias tracking.
- Deploy backend + WebSocket server together if self-hosted (e.g. DigitalOcean, Railway).
- Frontend deployable separately (e.g. Vercel) if using external WebSocket server.
