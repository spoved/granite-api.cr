create table test_model
(
    id          integer not null
        constraint test_model_pk
            primary key autoincrement,
    name        TEXT    not null,
    count       int  default 0 not null,
    status      text default "none" not null,
    created_at  int     not null,
    modified_at int     not null
);

INSERT INTO test_model (id, name, count, status, created_at, modified_at) VALUES (1, 'first_record', 101, 'done', 1630692214, 1630692214);