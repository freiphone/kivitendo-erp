-- @tag: parts_add_dispotype
-- @description: Neues Feld zur Definition "Disposition nach", derzeit "demand" oder "consumption"
-- @depends: release_3_4_0 parts_add_additional_fields_leadtime_etc
ALTER TABLE parts ADD COLUMN dispotype text default 'consumption';

