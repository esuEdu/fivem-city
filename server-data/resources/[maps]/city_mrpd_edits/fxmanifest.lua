fx_version 'cerulean'
game 'gta5'
this_is_a_map 'yes'

name 'city_mrpd_edits'
description 'Mission Row interior edits: the stuck-open armory hall door replaced by a working one (hei_dlc_heist_police.ytyp, made in CodeWalker)'
version '0.1.0'

-- The station the game shows is the heist DLC interior (hei_dlc_heist_police.ytyp), not the base game's v_int_20.ytyp.
-- The streamed file replaces the game's own file of the same name just by being streamed. No DLC_ITYP_REQUEST:
-- that would load it as an extra ytyp next to the original instead of replacing it.
