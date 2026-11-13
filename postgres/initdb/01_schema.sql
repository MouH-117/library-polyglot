-- Library network: books only
-- ============ Object-relational types ============
CREATE TYPE address_t AS (
    street      text,
    city        text,
    postal_code text,
    wilaya      text
);

-- ============ Lookup / reference tables ============
CREATE TABLE branch (
    branch_id  serial      PRIMARY KEY,
    name       text        NOT NULL UNIQUE,
    address    address_t   NOT NULL,          -- composite type
    phone      text,
    opened_on  date        NOT NULL DEFAULT current_date
);

CREATE TABLE category (
    category_id serial PRIMARY KEY,
    name        text   NOT NULL UNIQUE
);

CREATE TABLE author (
    author_id  serial PRIMARY KEY,
    full_name  text   NOT NULL,
    born_year  int    CHECK (born_year BETWEEN 1000 AND 2100)
);

-- ============ Catalog (books only) ============
CREATE TABLE title (
    title_id       serial      PRIMARY KEY,
    isbn           varchar(13) NOT NULL UNIQUE
                   CHECK (isbn ~ '^[0-9]{9}[0-9X]$' OR isbn ~ '^[0-9]{13}$'),
    name           text        NOT NULL,
    published_year int         CHECK (published_year BETWEEN 1400 AND 2100),
    pages          int         CHECK (pages > 0),
    language       text        NOT NULL DEFAULT 'en',
    category_id    int         NOT NULL REFERENCES category(category_id),
    keywords       text[]      NOT NULL DEFAULT '{}'   -- array column (GIN-indexed in Component C)
);

CREATE TABLE title_author (
    title_id  int NOT NULL REFERENCES title(title_id)   ON DELETE CASCADE,
    author_id int NOT NULL REFERENCES author(author_id) ON DELETE CASCADE,
    PRIMARY KEY (title_id, author_id)
);

CREATE TABLE copy (
    copy_id     serial PRIMARY KEY,
    title_id    int    NOT NULL REFERENCES title(title_id),
    branch_id   int    NOT NULL REFERENCES branch(branch_id),
    barcode     text   NOT NULL UNIQUE,
    status      text   NOT NULL DEFAULT 'available'
                CHECK (status IN ('available','on_loan','lost','repair')),
    acquired_on date   NOT NULL DEFAULT current_date
);

-- ============ People ============
CREATE TABLE member (
    member_id serial    PRIMARY KEY,
    card_no   text      NOT NULL UNIQUE,
    full_name text      NOT NULL,
    email     text      NOT NULL UNIQUE,
    address   address_t,                      -- composite type
    phones    text[]    NOT NULL DEFAULT '{}',-- array column
    joined_on date      NOT NULL DEFAULT current_date,
    status    text      NOT NULL DEFAULT 'active'
              CHECK (status IN ('active','suspended','expired'))
);

-- ============ Events ============
CREATE TABLE loan (
    loan_id     bigserial PRIMARY KEY,
    copy_id     int  NOT NULL REFERENCES copy(copy_id),
    member_id   int  NOT NULL REFERENCES member(member_id),
    borrowed_on date NOT NULL DEFAULT current_date,
    due_on      date NOT NULL,
    returned_on date,                         -- NULL = still on loan
    CHECK (due_on >= borrowed_on),
    CHECK (returned_on IS NULL OR returned_on >= borrowed_on)
);

-- Safety net: a copy can have at most ONE open loan (used in the concurrency argument)
CREATE UNIQUE INDEX uq_loan_one_open_per_copy
    ON loan (copy_id) WHERE returned_on IS NULL;

CREATE TABLE reservation (
    reservation_id serial      PRIMARY KEY,
    member_id      int         NOT NULL REFERENCES member(member_id),
    title_id       int         NOT NULL REFERENCES title(title_id),
    reserved_at    timestamptz NOT NULL DEFAULT now(),
    status         text        NOT NULL DEFAULT 'waiting'
                   CHECK (status IN ('waiting','ready','fulfilled','cancelled'))
);

-- A member can't have two active reservations for the same title
CREATE UNIQUE INDEX uq_reservation_active
    ON reservation (member_id, title_id) WHERE status IN ('waiting','ready');

CREATE TABLE fine (
    fine_id   serial        PRIMARY KEY,
    loan_id   bigint        NOT NULL UNIQUE REFERENCES loan(loan_id),
    amount    numeric(8,2)  NOT NULL CHECK (amount >= 0),
    issued_on date          NOT NULL DEFAULT current_date,
    paid_on   date,
    CHECK (paid_on IS NULL OR paid_on >= issued_on)
);
