-- @tag: parts_customs_tariff_number
-- @description: Neues Feld für Zolltarifnummer 
-- @depends: release_3_3_0
ALTER TABLE parts ADD COLUMN customs_tariff_number varchar(11);
