-- Parent table: columns common to every audit record
CREATE TABLE audit_log (
    audit_id   bigserial   PRIMARY KEY,
    table_name text        NOT NULL,
    operation  text        NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    changed_at timestamptz NOT NULL DEFAULT now(),
    changed_by text        NOT NULL DEFAULT current_user
);

-- Children: inherit the parent's columns and add their own
CREATE TABLE loan_audit (
    loan_id          bigint NOT NULL,
    copy_id          int    NOT NULL,
    member_id        int    NOT NULL,
    old_returned_on  date,
    new_returned_on  date
) INHERITS (audit_log);

CREATE TABLE member_audit (
    member_id   int NOT NULL,
    old_status  text,
    new_status  text
) INHERITS (audit_log);
