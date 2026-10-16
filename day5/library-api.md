# Library Books API

A REST API for managing the books in a library. Each book has an `id`, `title`, `author`, `year` and `isbn`.

## Endpoints

### 1. List all books

- **Method:** `GET`
- **Path:** `/books`
- **Description:** Returns every book in the library.
- **Request body:** None
- **Success status:** `200 OK`

### 2. Get one book

- **Method:** `GET`
- **Path:** `/books/{id}`
- **Description:** Returns the book with the given id.
- **Request body:** None
- **Success status:** `200 OK`

### 3. Create a book

- **Method:** `POST`
- **Path:** `/books`
- **Description:** Adds a new book to the library.
- **Example request body:**

  ```json
  {
    "title": "Things Fall Apart",
    "author": "Chinua Achebe",
    "year": 1958,
    "isbn": "9780385474542"
  }
  ```

- **Success status:** `201 Created`

### 4. Update a book

- **Method:** `PUT`
- **Path:** `/books/{id}`
- **Description:** Replaces the details of an existing book.
- **Example request body:**

  ```json
  {
    "title": "Things Fall Apart",
    "author": "Chinua Achebe",
    "year": 1958,
    "isbn": "9780385474542"
  }
  ```

- **Success status:** `200 OK`

### 5. Delete a book

- **Method:** `DELETE`
- **Path:** `/books/{id}`
- **Description:** Removes the book with the given id from the library.
- **Request body:** None
- **Success status:** `204 No Content`

### 6. List books by author

- **Method:** `GET`
- **Path:** `/books?author={name}`
- **Description:** Returns only the books written by the author named in the query parameter.
- **Example request:** `GET /books?author=Chinua%20Achebe`
- **Request body:** None
- **Success status:** `200 OK`

## Error responses

### 400 Bad Request

- **When it happens:** The request is malformed or missing required fields.
- **Example:** Sending a `POST /books` request without a `title`:

  ```json
  {
    "author": "Chinua Achebe",
    "year": 1958
  }
  ```

  Response: `400 Bad Request` with the message `"title is required"`.

### 404 Not Found

- **When it happens:** The requested book does not exist.
- **Example:** Requesting `GET /books/999` when no book has the id `999`.

  Response: `404 Not Found` with the message `"Book 999 was not found"`.
