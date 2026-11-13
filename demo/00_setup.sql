INSERT INTO category(name) VALUES ('Demo');
INSERT INTO branch(name,address) VALUES ('Demo Branch', ROW('1 Rue X','Constantine','25000','Constantine')::address_t);
INSERT INTO title(isbn,name,category_id)
  VALUES ('9780000000099','Demo Book',(SELECT category_id FROM category WHERE name='Demo'));
INSERT INTO copy(title_id,branch_id,barcode)
  SELECT (SELECT title_id FROM title WHERE isbn='9780000000099'),
         (SELECT branch_id FROM branch WHERE name='Demo Branch'),
         'DEMO-'||g FROM generate_series(1,8) g;
INSERT INTO member(card_no,full_name,email) VALUES
  ('D-1','Demo One','d1@example.com'),
  ('D-2','Demo Two','d2@example.com'),
  ('D-3','Demo Three','d3@example.com');

-- Member D-3 already has 4 open loans (copies DEMO-1..4)
INSERT INTO loan(copy_id,member_id,borrowed_on,due_on)
  SELECT copy_id,(SELECT member_id FROM member WHERE card_no='D-3'),current_date,current_date+14
  FROM copy WHERE barcode IN ('DEMO-1','DEMO-2','DEMO-3','DEMO-4');
