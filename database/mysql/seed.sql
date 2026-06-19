INSERT IGNORE INTO categories (name)
VALUES
  ('Science'),
  ('History'),
  ('Sports');

INSERT INTO questions (category_id, question_text, answer)
SELECT c.id, 'What is the chemical symbol for gold?', 'Au'
FROM categories c
WHERE c.name = 'Science'
  AND NOT EXISTS (
    SELECT 1
    FROM questions q
    WHERE q.category_id = c.id
      AND q.question_text = 'What is the chemical symbol for gold?'
  );

INSERT INTO question_options (question_id, option_text, is_correct)
SELECT q.id, option_row.option_text, option_row.is_correct
FROM questions q
JOIN categories c ON c.id = q.category_id
JOIN (
  SELECT 'Au' AS option_text, TRUE AS is_correct
  UNION ALL SELECT 'Ag', FALSE
  UNION ALL SELECT 'Fe', FALSE
  UNION ALL SELECT 'Pb', FALSE
) option_row
WHERE c.name = 'Science'
  AND q.question_text = 'What is the chemical symbol for gold?'
  AND NOT EXISTS (
    SELECT 1
    FROM question_options existing
    WHERE existing.question_id = q.id
  );

INSERT INTO questions (category_id, question_text, answer)
SELECT c.id, 'Which country hosted the 2016 Summer Olympics?', 'Brazil'
FROM categories c
WHERE c.name = 'Sports'
  AND NOT EXISTS (
    SELECT 1
    FROM questions q
    WHERE q.category_id = c.id
      AND q.question_text = 'Which country hosted the 2016 Summer Olympics?'
  );

INSERT INTO question_options (question_id, option_text, is_correct)
SELECT q.id, option_row.option_text, option_row.is_correct
FROM questions q
JOIN categories c ON c.id = q.category_id
JOIN (
  SELECT 'Brazil' AS option_text, TRUE AS is_correct
  UNION ALL SELECT 'Japan', FALSE
  UNION ALL SELECT 'China', FALSE
  UNION ALL SELECT 'Greece', FALSE
) option_row
WHERE c.name = 'Sports'
  AND q.question_text = 'Which country hosted the 2016 Summer Olympics?'
  AND NOT EXISTS (
    SELECT 1
    FROM question_options existing
    WHERE existing.question_id = q.id
  );

INSERT INTO questions (category_id, question_text, answer)
SELECT c.id, 'Who was the first president of the United States?', 'George Washington'
FROM categories c
WHERE c.name = 'History'
  AND NOT EXISTS (
    SELECT 1
    FROM questions q
    WHERE q.category_id = c.id
      AND q.question_text = 'Who was the first president of the United States?'
  );

INSERT INTO question_options (question_id, option_text, is_correct)
SELECT q.id, option_row.option_text, option_row.is_correct
FROM questions q
JOIN categories c ON c.id = q.category_id
JOIN (
  SELECT 'George Washington' AS option_text, TRUE AS is_correct
  UNION ALL SELECT 'Thomas Jefferson', FALSE
  UNION ALL SELECT 'Abraham Lincoln', FALSE
  UNION ALL SELECT 'John Adams', FALSE
) option_row
WHERE c.name = 'History'
  AND q.question_text = 'Who was the first president of the United States?'
  AND NOT EXISTS (
    SELECT 1
    FROM question_options existing
    WHERE existing.question_id = q.id
  );
