# SnapShare Scaling Plan

## 1. Assumptions

- 10 million registered users.
- 10% of registered users are active each day.
- Each active user uploads 1 photo per day.
- Each active user views 50 feed pages per day.
- An average photo is 2 MB. Each photo also has a 50 KB thumbnail.
- Peak traffic is 5 times the average.
- 1 MB = 1,000 KB, and 1 GB = 1,000 MB, for simple calculation.
- A day has 86,400 seconds, and a year has 365 days.
- Usage stays constant. Growth and deleted photos are not included.

## 2. Estimates

### Daily active users

10,000,000 registered users × 10% = **1,000,000 daily active users**

### Uploads per second

- Uploads per day: 1,000,000 users × 1 photo = **1,000,000 uploads per day**
- Average: 1,000,000 ÷ 86,400 ≈ **12 uploads per second**
- Peak: 12 × 5 ≈ **58 uploads per second**

### Feed views per second

- Feed views per day: 1,000,000 users × 50 pages = **50,000,000 feed views per day**
- Average: 50,000,000 ÷ 86,400 ≈ **579 feed views per second**
- Peak: 579 × 5 ≈ **2,900 feed views per second**

### Storage per year

- Storage per photo: 2 MB photo + 50 KB thumbnail = 2,050 KB (about 2.05 MB)
- Storage per day: 1,000,000 photos × 2.05 MB = 2,050,000 MB = **2.05 TB per day**
- Storage per year: 2.05 TB × 365 ≈ **748 TB per year (about 0.75 PB)**
  - Full-size photos: about 730 TB per year
  - Thumbnails: about 18 TB per year

## 3. Read-heavy or write-heavy?

SnapShare is **read-heavy**. Each day there are 50 feed views for every upload (50,000,000 reads against 1,000,000 writes), so reads outnumber writes by about 50 to 1.

This means the design should focus on making reads fast and cheap:
- Cache popular feed data so the database is not queried on every view.
- Serve images through a CDN, so most photo requests never reach the main servers.
- Send read queries to a read replica, so the primary database can focus on saving new photos.

Writes still need care, because about 58 uploads per second at peak must be saved reliably. The thumbnail work is moved to a queue so uploads stay fast.

## 4. Why photos are not stored in the database

Photos are large binary files. Storing them in the database would make backups slow, make the database very large, and make every read heavier. Instead, photos go to **object storage**, which is designed for large files and can be served through a CDN. The database stores only metadata, such as the photo's id, owner, timestamp, and the storage keys for the photo and its thumbnail.

## 5. Architecture diagram

```
   [User's phone or browser]
        |                 ^
        | uploads         | photos and thumbnails
        v                 |
   [Load balancer]        |
        |                 |
        v                 |
   [App servers] ----> [Cache] (feed data)
     |       |
     |       +----> [Database primary] ----> [Read replica]
     |                    ^                       ^
     |                    | writes                | reads
     v                    |                       |
   [Object storage] <-- [Thumbnail worker] <-- [Queue]
     (photos +            (creates 50 KB
      thumbnails)          thumbnails)
        |
        v
      [CDN] ----------> [User's phone or browser]
   (serves photos near the user)
```

## 6. What each component does

- **Load balancer:** Spreads incoming requests across several app servers so no single server is overloaded.
- **App servers:** Handle the logic for uploading photos, building feeds and checking who each user follows.
- **Cache:** Stores recently requested feed data, so repeat views don't query the database.
- **Database primary:** Stores all metadata (users, follows, photo records) and handles every write.
- **Read replica:** Holds a copy of the database that answers feed queries, so reads don't slow down writes.
- **Object storage:** Holds the full-size photos and thumbnails as files, which is cheaper and faster for large data than a database.
- **Queue:** Holds thumbnail jobs so the upload can finish without waiting for the thumbnail to be made.
- **Thumbnail worker:** Takes jobs from the queue, creates the 50 KB thumbnail, and saves it to object storage.
- **CDN:** Stores copies of photos on servers near users, so images load quickly and the main servers handle less traffic.

## 7. Upload flow, step by step

1. The user selects a photo in the app, and the app sends it to the load balancer.
2. The load balancer passes the request to an app server.
3. The app server checks that the user is logged in, the file is an image, and the file is within the size limit.
4. The app server saves the full-size photo to object storage and receives a storage key.
5. The app server writes a metadata record to the database primary with the photo's id, owner, timestamp, storage key and status "processing". It then returns "Upload received" to the user.
6. The app server adds a message to the queue saying "create a thumbnail for photo X".
7. The thumbnail worker takes the message from the queue and downloads the full-size photo from object storage.
8. The worker creates a 50 KB thumbnail and saves it to object storage.
9. The worker updates the photo's record in the database with the thumbnail key and sets the status to "ready".
10. When followers open their feeds, the app server reads the new photo through the cache or the read replica, and the browser loads the image from the CDN.

## 8. Trade-offs

**Trade-off 1: Fast uploads versus instant thumbnails.**
Creating thumbnails in the background means the user gets a quick response after uploading. The cost is that a new photo may briefly show without its thumbnail, so the app needs a placeholder until the worker finishes.

**Trade-off 2: Fresh feeds versus fast feeds.**
Serving feeds from a cache or read replica keeps the system fast and reduces load on the primary database. The cost is that a new photo may take a few seconds to appear in other users' feeds, because copies of the data update with a small delay.

**Trade-off 3 (optional): Cost of a CDN.**
A CDN makes photos load quickly around the world and cuts the traffic to the main servers, but it adds ongoing cost for storage and data transfer.
