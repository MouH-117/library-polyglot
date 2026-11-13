-- Late fee: 10 DA per overdue day, capped at 1000 DA.
-- Works for returned loans (uses returned_on) and open loans (uses today).
CREATE OR REPLACE FUNCTION fn_calc_fine(p_loan_id bigint)
RETURNS numeric
LANGUAGE plpgsql STABLE
AS $$
DECLARE
    v_due      date;
    v_returned date;
    v_days     int;
BEGIN
    SELECT due_on, returned_on INTO v_due, v_returned
    FROM loan WHERE loan_id = p_loan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % does not exist', p_loan_id;
    END IF;

    v_days := GREATEST(coalesce(v_returned, current_date) - v_due, 0);
    RETURN LEAST(v_days * 10, 1000);
END;
$$;

-- Available copies of one book, grouped by branch
CREATE OR REPLACE FUNCTION fn_available_copies(p_title_id int)
RETURNS TABLE (branch_id int, branch_name text, available_copies int)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT b.branch_id, b.name, count(c.copy_id)::int
    FROM branch b
    JOIN copy c ON c.branch_id = b.branch_id
    WHERE c.title_id = p_title_id
      AND c.status = 'available'
    GROUP BY b.branch_id, b.name
    ORDER BY b.name;
END;
$$;
