-- ============ View: currently overdue loans ============
CREATE OR REPLACE VIEW v_overdue_loans AS
SELECT l.loan_id,
       m.member_id,
       m.full_name   AS member_name,
       m.email,
       t.name        AS book,
       b.name        AS branch,
       l.borrowed_on,
       l.due_on,
       (current_date - l.due_on)  AS days_overdue,
       fn_calc_fine(l.loan_id)    AS fine_so_far
FROM loan l
JOIN member m ON m.member_id = l.member_id
JOIN copy   c ON c.copy_id   = l.copy_id
JOIN title  t ON t.title_id  = c.title_id
JOIN branch b ON b.branch_id = c.branch_id
WHERE l.returned_on IS NULL
  AND l.due_on < current_date;

-- ============ Materialized view: loans per branch per month ============
CREATE MATERIALIZED VIEW mv_branch_monthly_stats AS
SELECT c.branch_id,
       b.name                                    AS branch,
       date_trunc('month', l.borrowed_on)::date  AS month,
       count(*)                                  AS loans,
       count(*) FILTER (WHERE l.returned_on IS NULL) AS still_open
FROM loan l
JOIN copy   c ON c.copy_id   = l.copy_id
JOIN branch b ON b.branch_id = c.branch_id
GROUP BY c.branch_id, b.name, date_trunc('month', l.borrowed_on)::date;

-- Unique index: required for REFRESH ... CONCURRENTLY and speeds up lookups
CREATE UNIQUE INDEX uq_mv_branch_month ON mv_branch_monthly_stats (branch_id, month);
