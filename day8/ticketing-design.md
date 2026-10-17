# TicketHub Design

## 1. Requirements

### Functional requirements
- Users can browse upcoming events and view each event's seat map.
- Users can hold one or more seats for a short time while they pay.
- Users can pay for held seats and receive a confirmed order.
- Users can view their own tickets.
- Each seat can be sold to only one buyer.

### Non-functional requirements
- **Speed:** Browsing pages should load in under one second. Holding a seat should respond in under 500 milliseconds, even during a big sale.
- **Correctness:** No seat may be sold twice, and no payment may be taken without a matching ticket.
- **Fairness:** During a big sale, people should be admitted in the order they arrived, and no single person or bot should be able to take many seats.
- **Availability:** Browsing should keep working during a sale, and the system should survive the failure of any one server.
- **Security:** Payments are handled by an external payment provider, so card details never reach TicketHub's servers. All traffic uses HTTPS.

## 2. Estimates

**Assumptions**
- 2,000,000 registered users.
- 50,000 people visit on a normal day, and each views 10 pages.
- 5,000 tickets are sold on a normal day.
- A big sale has 200,000 people trying to buy 20,000 seats within the first 10 minutes.
- Peak traffic is 5 times the average.
- A day has 86,400 seconds.

### Normal day

- **Page views:** 50,000 × 10 = 500,000 per day. Average: 500,000 ÷ 86,400 ≈ **6 per second**. Peak: 6 × 5 ≈ **29 per second**.
- **Tickets sold:** 5,000 per day. Average: 5,000 ÷ 86,400 ≈ **0.06 per second**. Peak: about **0.3 per second**.

### Big sale (first 10 minutes)

- **Purchase attempts:** 200,000 people in 600 seconds. Average: 200,000 ÷ 600 ≈ **333 attempts per second**. Peak: 333 × 5 ≈ **1,667 per second**.
- **Page views:** each attempt views about 10 pages, so 2,000,000 page views in 600 seconds. Average: 2,000,000 ÷ 600 ≈ **3,333 per second**. Peak: 3,333 × 5 ≈ **16,667 per second**.
- **Seats sold:** 20,000 seats in 600 seconds, about **33 per second**, while 180,000 people miss out.

### Comparison

The big sale brings about **575 times** the normal average page traffic (3,333 against 6 per second) and about **1,000 times** the normal purchase rate (333 against 0.3 per second). Storage is not a concern: each order takes about 1 KB, so even a full day of sales needs only a few megabytes. The real challenge is the **burst** of concurrent requests for the same seats.

## 3. API

| Method | Path | Description | Success | Errors |
|---|---|---|---|---|
| GET | `/events` | List upcoming events | 200 | 500 |
| GET | `/events/{id}` | Get one event's details and sale times | 200 | 404 |
| GET | `/events/{id}/seats` | Get the seat map with each seat's status (available, held, sold) | 200 | 404 |
| POST | `/events/{id}/queue` | Join the waiting room for a big sale; returns a position and an admission token | 202 Accepted | 409 if already in queue |
| POST | `/holds` | Hold one or more seats for 10 minutes. Body: `{ "event_id": 7, "seat_ids": [1001, 1002] }` | 201 Created | 409 if any seat is taken, 403 without a valid admission token, 429 if the user has too many holds |
| POST | `/orders` | Pay for held seats and create the order. Body: `{ "hold_id": 55, "payment_token": "tok_abc" }` | 201 Created | 402 payment declined, 410 hold expired, 409 seat no longer held by you |
| GET | `/me/tickets` | List the signed-in user's confirmed tickets | 200 | 401 |

**Example: hold seats**

Request: `POST /holds`

```json
{ "event_id": 7, "seat_ids": [1001, 1002] }
```

Response: `201 Created`

```json
{
  "hold_id": 55,
  "seat_ids": [1001, 1002],
  "expires_at": "2026-10-24T19:10:00Z"
}
```

**Example: seat already taken**

Response: `409 Conflict`

```json
{
  "error": {
    "code": 409,
    "message": "Seat 1002 is no longer available",
    "seat_ids": [1002]
  }
}
```

## 4. Data model

### Tables

**users**
- `id` (primary key)
- `email` (unique, not empty)
- `name`
- `created_at`

**events**
- `id` (primary key)
- `name`
- `venue`
- `starts_at`
- `on_sale_at` (when tickets go on sale)

**seats**
- `id` (primary key)
- `event_id` (foreign key to events)
- `section`, `row_label`, `seat_number`
- `price`
- `status` (available, held or sold)
- `held_by_user_id` (foreign key to users, empty unless held)
- `hold_expires_at` (empty unless held)
- Unique on `(event_id, section, row_label, seat_number)`, so no two seats share a position.

**orders**
- `id` (primary key)
- `user_id` (foreign key to users)
- `event_id` (foreign key to events)
- `total_amount`
- `payment_reference` (the provider's transaction id)
- `status` (confirmed or refunded)
- `created_at`

**order_items**
- `id` (primary key)
- `order_id` (foreign key to orders)
- `seat_id` (foreign key to seats, unique)
- `price`

### Relationships

- **users to orders: one-to-many.** A user can place many orders.
- **events to seats: one-to-many.** Each event has many seats.
- **events to orders: one-to-many.** Each event can have many orders.
- **orders to seats: many-to-many,** linked through `order_items`. One order can contain many seats, and the `UNIQUE` rule on `seat_id` means each seat appears in only one order.

### SQL for the seats table

```sql
CREATE TABLE seats (
  id INTEGER PRIMARY KEY,
  event_id INTEGER NOT NULL,
  section VARCHAR(20) NOT NULL,
  row_label VARCHAR(10) NOT NULL,
  seat_number INTEGER NOT NULL,
  price DECIMAL(10, 2) NOT NULL,
  status VARCHAR(10) NOT NULL DEFAULT 'available'
    CHECK (status IN ('available', 'held', 'sold')),
  held_by_user_id INTEGER,
  hold_expires_at TIMESTAMP,
  UNIQUE (event_id, section, row_label, seat_number),
  FOREIGN KEY (event_id) REFERENCES events (id),
  FOREIGN KEY (held_by_user_id) REFERENCES users (id)
);

CREATE TABLE order_items (
  id INTEGER PRIMARY KEY,
  order_id INTEGER NOT NULL,
  seat_id INTEGER NOT NULL UNIQUE,
  price DECIMAL(10, 2) NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders (id),
  FOREIGN KEY (seat_id) REFERENCES seats (id)
);
```

## 5. How double-booking is prevented

Double-booking is prevented in three layers, so a bug in one layer cannot sell the same seat twice.

**Layer 1: an atomic conditional update when holding a seat.** The system doesn't first check whether a seat is free and then book it. It runs one statement that books the seat only if it is still free:

```sql
UPDATE seats
SET status = 'held',
    held_by_user_id = 42,
    hold_expires_at = CURRENT_TIMESTAMP + INTERVAL '10 minutes'
WHERE id = 1002
  AND status = 'available';
```

The database checks the condition and makes the change as one step. If two requests run at the same moment, only one changes the row. The app checks how many rows were changed: 1 means the hold succeeded, and 0 means someone else got there first, so it returns 409 Conflict. Because the check and the change happen together, there is no gap in which another request can slip in.

**Layer 2: a transaction when paying.** Confirming a purchase changes several tables, so it runs in one transaction:

```sql
BEGIN;

-- Turn the held seat into a sold seat, only if this user still holds it and the hold has not expired
UPDATE seats
SET status = 'sold', hold_expires_at = NULL
WHERE id = 1002
  AND status = 'held'
  AND held_by_user_id = 42
  AND hold_expires_at > CURRENT_TIMESTAMP;

-- If no row changed, the hold expired or belongs to someone else: undo everything
-- (the application checks the row count and runs ROLLBACK instead of continuing)

INSERT INTO orders (user_id, event_id, total_amount, payment_reference, status, created_at)
VALUES (42, 7, 85.00, 'pay_9xk2', 'confirmed', CURRENT_TIMESTAMP);

INSERT INTO order_items (order_id, seat_id, price)
VALUES (last_insert_rowid(), 1002, 85.00);

COMMIT;
```

If the payment is declined or any step fails, the transaction is rolled back, so no seat is sold without a payment and no payment is recorded without a seat.

**Layer 3: a database constraint.** The `UNIQUE` rule on `order_items.seat_id` means the database itself refuses a second sale of the same seat, even if the application code has a bug. This is the final safety net.

**Expiry.** A background worker runs every minute and sets seats back to `available` when `hold_expires_at` has passed. Without this, a buyer who closes the page would lock a seat forever.

## 6. Architecture

```
   [Browser or phone]
          |
          v
        [DNS]
          |
          v
        [CDN] --- caches event pages and seat-map snapshots (short time)
          |
          v
   [Waiting room service] --- admits users at a steady rate and issues admission tokens
          |
          v
   [Load balancer (two or more, with failover)]
          |
     +----+-----------------+------------------+
     |                      |                  |
     v                      v                  v
 [App server 1]        [App server 2]     [App server N]   (auto-scaled, stateless)
     |     \                 |     /
     |      \                |    /
     |       v               v   v
     |     [Cache] (event details, seat maps with short expiry)
     |
     |  holds and orders (writes)           browsing (reads)
     v                                          ^
 [Primary database] ----- replicates ----> [Read replica]
     |
     | (new holds, sales and expiries)
     v
 [Queue] ----------------> [Worker]
                           (releases expired holds, sends confirmation
                            emails, reports to the payment provider)

 [External payment provider] <--- called by the app server during payment
```

### What each component does

- **Browser or phone:** Sends requests and shows seat maps and tickets.
- **DNS:** Points the site name to the CDN and the load balancers.
- **CDN:** Serves event pages and recent seat-map snapshots from nearby locations, so most browsing never reaches the servers.
- **Waiting room service:** Holds visitors in a fair queue during a big sale, lets them in at a set rate, and issues admission tokens. Without it, 200,000 people would hit the database at once.
- **Load balancer:** Spreads requests across the app servers and removes any server that fails its health check.
- **App servers:** Run the booking logic. They hold no state of their own, so new servers can be added during a sale.
- **Cache:** Stores event details and seat maps for a few seconds, so repeated browsing doesn't query the database.
- **Primary database:** Stores users, events, seats and orders, and handles every hold and sale, so the rules are enforced in one place.
- **Read replica:** Serves seat-map and ticket-list reads, so browsing does not compete with holds and sales for the primary database.
- **Queue and worker:** Process slower tasks in the background, such as releasing expired holds and sending confirmation emails.
- **External payment provider:** Takes the card payment, so TicketHub never stores card details.

### How the architecture survives the big sale

1. **The waiting room limits the load.** Instead of 333 purchase attempts per second hitting the database, the waiting room admits a fixed number of people each minute, for example 500 per minute. The database sees a steady, predictable rate.
2. **Browsing is served from the CDN and cache.** Most of the 16,667 peak page views per second are answered by the CDN and cache, so the database only handles writes and occasional fresh reads.
3. **Writes are small and atomic.** Each hold is a single conditional update, which is quick, so contention for the same seat is resolved in microseconds.
4. **App servers scale out.** Because they hold no state, more servers can be added while the sale runs.
5. **Rate limits stop bots.** Each account and IP address can make only a few requests per second, and admission tokens are tied to accounts, so one person cannot take many seats.
6. **Clear error responses.** When a seat is gone, the user gets a 409 straight away and can pick another, instead of waiting on a slow page.

## 7. Trade-offs

**Trade-off 1: Waiting room versus instant access.**
The waiting room makes some people wait, which is frustrating, but it protects the system and gives everyone an equal chance in the order they arrived. Without it, the site would crash or the fastest connections would win every time.

**Trade-off 2: Cached seat maps versus accurate seat maps.**
Serving seat maps from the cache and CDN keeps the site fast under load, but a seat may appear available for a few seconds after it was taken. This is acceptable because the hold itself is checked against the primary database. A user may see a seat that then returns 409 Conflict, but they can never be sold a seat that is already taken.

**Trade-off 3: Hold time versus fairness.**
A 10-minute hold gives buyers enough time to pay, but it keeps seats locked while people may not finish. A shorter hold frees seats sooner for others but may lose buyers who are slow to pay. The time is a balance between the two.

## 8. Single points of failure

- Two or more load balancers run with failover, and the app servers sit behind them.
- The waiting room runs as several instances, so admission continues if one fails.
- The primary database has a standby in a second availability zone that takes over automatically.
- Read replicas are kept in more than one zone.
- The cache runs as a cluster with replication.
- The queue stores messages on several machines, and multiple workers read from it.
- Servers are spread across at least two availability zones, so a single data-centre failure does not stop sales.
