-- Turn on foreign key checking (SQLite does not enforce them by default)
PRAGMA foreign_keys = ON;

-- ============================================
-- 1. TABLES
-- ============================================

CREATE TABLE students (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE
);

CREATE TABLE courses (
  id INTEGER PRIMARY KEY,
  title TEXT NOT NULL,
  credits INTEGER NOT NULL
);

-- Join table: one row for each student enrolled on a course, with the grade.
-- A grade is allowed to be empty until the course is graded.
CREATE TABLE enrolments (
  id INTEGER PRIMARY KEY,
  student_id INTEGER NOT NULL,
  course_id INTEGER NOT NULL,
  grade TEXT,
  FOREIGN KEY (student_id) REFERENCES students (id),
  FOREIGN KEY (course_id) REFERENCES courses (id),
  UNIQUE (student_id, course_id)
);

-- ============================================
-- 2. SAMPLE DATA
-- ============================================

INSERT INTO students (id, name, email) VALUES
  (1, 'Amara Okafor', 'amara@example.com'),
  (2, 'Brian Kiprop', 'brian@example.com'),
  (3, 'Chloe Mwangi', 'chloe@example.com'),
  (4, 'David Otieno', 'david@example.com');

INSERT INTO courses (id, title, credits) VALUES
  (1, 'Introduction to Programming', 3),
  (2, 'Web Development', 4),
  (3, 'Databases', 3);

INSERT INTO enrolments (id, student_id, course_id, grade) VALUES
  (1, 1, 1, 'A'),
  (2, 1, 2, 'B+'),
  (3, 2, 1, 'B'),
  (4, 2, 3, NULL),
  (5, 3, 2, 'A-'),
  (6, 3, 3, 'B+');
-- David (student 4) has no enrolments, which the last query will find.

-- ============================================
-- 3. QUERIES
-- ============================================

-- Query 1: All courses for one student, by name
-- Expected: Introduction to Programming (A), Web Development (B+)
SELECT courses.title, courses.credits, enrolments.grade
FROM students
JOIN enrolments ON enrolments.student_id = students.id
JOIN courses ON courses.id = enrolments.course_id
WHERE students.name = 'Amara Okafor';

-- Query 2: All students on one course
-- Expected: Amara Okafor (B+), Chloe Mwangi (A-)
SELECT students.name, students.email, enrolments.grade
FROM courses
JOIN enrolments ON enrolments.course_id = courses.id
JOIN students ON students.id = enrolments.student_id
WHERE courses.title = 'Web Development';

-- Query 3: Number of students per course
-- LEFT JOIN keeps courses that have no students, which would show a count of 0
-- Expected: each course shows 2 students
SELECT courses.title, COUNT(enrolments.id) AS student_count
FROM courses
LEFT JOIN enrolments ON enrolments.course_id = courses.id
GROUP BY courses.id, courses.title;

-- Query 4: Students who have no enrolments
-- Expected: David Otieno
SELECT students.name, students.email
FROM students
LEFT JOIN enrolments ON enrolments.student_id = students.id
WHERE enrolments.id IS NULL;

-- Query 5: Update one enrolment's grade
-- Changes Brian Kiprop's grade in Introduction to Programming from B to A
UPDATE enrolments
SET grade = 'A'
WHERE student_id = 2 AND course_id = 1;

-- Check the update worked
SELECT students.name, courses.title, enrolments.grade
FROM enrolments
JOIN students ON students.id = enrolments.student_id
JOIN courses ON courses.id = enrolments.course_id
WHERE enrolments.student_id = 2 AND enrolments.course_id = 1;
-- Expected: Brian Kiprop, Introduction to Programming, A
