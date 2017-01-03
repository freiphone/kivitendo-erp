-- @tag: parts_add_additional_fields_leadtime_etc
-- @description: Neue Artikelfelder
-- @depends: release_3_4_0
ALTER TABLE parts ADD COLUMN intnotes text;
ALTER TABLE parts ADD COLUMN consume NUMERIC(15,5) default 0;
ALTER TABLE parts ADD COLUMN ordersize NUMERIC(15,5) default 0;
ALTER TABLE parts ADD COLUMN leadtime integer default 0;

