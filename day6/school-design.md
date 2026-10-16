# School Database Design

## Tables

- **students**: one row for each student. Columns are `id` (primary key), `name` and `email`. The email must be unique, so two students can't register with the same address.
- **courses**: one row for each course. Columns are `id` (primary key), `title` and `credits`.
- **enrolments**: one row for each time a student signs up for a course. Columns are `id` (primary key), `student_id` (points to students), `course_id` (points to courses) and `grade`. The grade can be empty until the course is marked.

## Relationships

- **Students to enrolments: one-to-many.** One student can have many enrolments, but each enrolment belongs to exactly one student.
- **Courses to enrolments: one-to-many.** One course can have many enrolments, but each enrolment belongs to exactly one course.
- **Students to courses: many-to-many.** A student can take many courses, and a course can have many students.

A join table is needed because a many-to-many relationship can't be stored directly in either main table. If a student row listed every course, the table would need a variable-length list in one cell, which breaks the rules of a relational database. If a course row listed every student, the same problem appears. The enrolments table solves this by holding one row for each pairing, and it is the right place to store the grade, since the grade belongs to the pairing, not to the student or the course alone.

The `UNIQUE (student_id, course_id)` rule stops the same student enrolling on the same course twice.

## Suggested index

**Index: `enrolments (course_id)`**

I would add an index on `course_id`. The most common question for a school is "who is on this course?", which filters enrolments by course. Without an index, the database checks every enrolment row to find the matches. With an index, it jumps straight to the right rows, which matters as the number of enrolments grows into the thousands. The unique pair rule already creates an index on `(student_id, course_id)`, which covers the questions that start with a student, so this extra index covers the course side.

## SQL or NoSQL

I would choose SQL for this system. The data is highly structured and connected: students, courses and grades must link together correctly, and the database must reject an enrolment for a student who doesn't exist or a duplicate pairing. SQL enforces these rules through keys and constraints, and joins answer questions such as "which courses is this student taking?" directly. A NoSQL document store would be a better fit for data with no fixed shape, such as user activity logs or product catalogues where each item has different attributes, but a school register needs the consistency and relationships that SQL provides.
