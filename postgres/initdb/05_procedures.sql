-- ============ Borrow a copy (concurrency-safe) ============
-- Lock order is always: member row first, then copy row (prevents deadlocks).
CREATE OR REPLACE PROCEDURE sp_borrow_copy(
    p_member_id int,
    p_copy_id   int,
    INOUT p_loan_id bigint
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_member_status text;
    v_copy_status   text;
    v_open_loans    int;
    v_unpaid_fines  int;
BEGIN
    -- 1. Lock the member row: serializes all borrows by the same member
    --    (protects the 5-loan limit against write skew)
    SELECT status INTO v_member_status
    FROM member WHERE member_id = p_member_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Member % does not exist', p_member_id;
    END IF;
    IF v_member_status <> 'active' THEN
        RAISE EXCEPTION 'Member % is %, cannot borrow', p_member_id, v_member_status;
    END IF;

    -- 2. Lock the copy row: serializes all borrows of the same copy
    --    (protects against double lending of the last copy)
    SELECT status INTO v_copy_status
    FROM copy WHERE copy_id = p_copy_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Copy % does not exist', p_copy_id;
    END IF;
    IF v_copy_status <> 'available' THEN
        RAISE EXCEPTION 'Copy % is not available (status: %)', p_copy_id, v_copy_status;
    END IF;

    -- 3. Business rules (safe to check now: both rows are locked)
    SELECT count(*) INTO v_unpaid_fines
    FROM fine f JOIN loan l ON l.loan_id = f.loan_id
    WHERE l.member_id = p_member_id AND f.paid_on IS NULL;
    IF v_unpaid_fines > 0 THEN
        RAISE EXCEPTION 'Member % has % unpaid fine(s)', p_member_id, v_unpaid_fines;
    END IF;

    SELECT count(*) INTO v_open_loans
    FROM loan WHERE member_id = p_member_id AND returned_on IS NULL;
    IF v_open_loans >= 5 THEN
        RAISE EXCEPTION 'Member % reached the limit of 5 open loans', p_member_id;
    END IF;

    -- 4. Create the loan (the trigger sets copy.status = 'on_loan' and audits)
    INSERT INTO loan(copy_id, member_id, borrowed_on, due_on)
    VALUES (p_copy_id, p_member_id, current_date, current_date + 14)
    RETURNING loan_id INTO p_loan_id;
END;
$$;

-- ============ Return a copy and issue a fine if late ============
CREATE OR REPLACE PROCEDURE sp_return_copy(
    p_loan_id bigint,
    INOUT p_fine numeric
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_returned date;
BEGIN
    SELECT returned_on INTO v_returned
    FROM loan WHERE loan_id = p_loan_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Loan % does not exist', p_loan_id;
    END IF;
    IF v_returned IS NOT NULL THEN
        RAISE EXCEPTION 'Loan % was already returned on %', p_loan_id, v_returned;
    END IF;

    UPDATE loan SET returned_on = current_date WHERE loan_id = p_loan_id;
    -- the trigger frees the copy and writes the audit row

    p_fine := fn_calc_fine(p_loan_id);
    IF p_fine > 0 THEN
        INSERT INTO fine(loan_id, amount) VALUES (p_loan_id, p_fine);
    END IF;
END;
$$;
