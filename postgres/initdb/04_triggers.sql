-- ============ Trigger 1: loan -> copy status + audit ============
CREATE OR REPLACE FUNCTION trg_loan_sync()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- New loan: the copy is now out
        UPDATE copy SET status = 'on_loan' WHERE copy_id = NEW.copy_id;

        INSERT INTO loan_audit(table_name, operation, loan_id, copy_id, member_id,
                               old_returned_on, new_returned_on)
        VALUES ('loan', 'INSERT', NEW.loan_id, NEW.copy_id, NEW.member_id,
                NULL, NEW.returned_on);

    ELSIF TG_OP = 'UPDATE' THEN
        -- Book returned: free the copy (but never "un-lose" a lost/repair copy)
        IF OLD.returned_on IS NULL AND NEW.returned_on IS NOT NULL THEN
            UPDATE copy SET status = 'available'
            WHERE copy_id = NEW.copy_id AND status = 'on_loan';
        END IF;

        INSERT INTO loan_audit(table_name, operation, loan_id, copy_id, member_id,
                               old_returned_on, new_returned_on)
        VALUES ('loan', 'UPDATE', NEW.loan_id, NEW.copy_id, NEW.member_id,
                OLD.returned_on, NEW.returned_on);
    END IF;

    RETURN NULL;   -- AFTER trigger: return value is ignored
END;
$$;

CREATE TRIGGER trg_loan_after_change
AFTER INSERT OR UPDATE ON loan
FOR EACH ROW EXECUTE FUNCTION trg_loan_sync();

-- ============ Trigger 2: member status changes -> audit ============
CREATE OR REPLACE FUNCTION trg_member_status_audit()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO member_audit(table_name, operation, member_id, old_status, new_status)
    VALUES ('member', 'UPDATE', NEW.member_id, OLD.status, NEW.status);
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_member_status
AFTER UPDATE OF status ON member
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION trg_member_status_audit();
