select * from tangsel_housing th ;
select count (*) from tangsel_housing th;

--STRUCTURING

--mengubah nama tabel
alter table tangsel_housing 
	rename column "nav-link href" to link_housing;

alter table tangsel_housing 
	rename column "listing-location" to loc_housing;

alter table tangsel_housing 
	rename column "listing-floorarea" to floor_area;

alter table tangsel_housing 
	rename column "listing-floorarea 2" to price_per_m2;

--convert floor_area to numeric
alter table tangsel_housing  
	add column floor_area_clean numeric;

update tangsel_housing th 
set floor_area_clean = cast(
    regexp_replace(floor_area, '[^0-9]', '', 'g') as numeric);

--convert price_per_m2
alter table tangsel_housing 
	add column price_per_m2_clean numeric;

update tangsel_housing th 
set price_per_m2_clean = cast(
    regexp_replace(
        replace(price_per_m2, E'\u00A0', ' '), 
        '[^0-9]', 
        '', 
        'g'
    ) as numeric
)
where regexp_replace(price_per_m2, '[^0-9]', '', 'g') <> '';

/* housing_df.loc[613, 'price'] = '2,45 M'
housing_df.loc[622, 'price'] = '987,75 jt'
housing_df.loc[623, 'price'] = '1,69 M'
housing_df.loc[624, 'price'] = '900 jt'
*/

--convert price to numeric
--mengisi rentang dengan nilai tengah
update tangsel_housing th 
	set price = '2,45 M'
	where price = '2,2 M - Rp 2,7 M';

update tangsel_housing th
	set price = '987,75 jt'
	where price = '875,5 jt - Rp 1,1 M';

update tangsel_housing th
	set price = '1,69 M'
	where price = '1,08 M - Rp 2,3 M';

update tangsel_housing th
	set price = '900 jt'
	where price = '800 jt - Rp 1 M';

alter table tangsel_housing 
	add column price_num numeric;

update tangsel_housing
set price_num = case
    when lower(price) like '%m%' then
        cast(replace(replace(replace(lower(price), 'rp', ''), ',', '.'), 'm', '') as numeric) * 1000000000
    when lower(price) like '%jt%' then
        cast(replace(replace(replace(lower(price), 'rp', ''), ',', '.'), 'jt', '') as numeric) * 1000000
    when lower(price) like '%rb%' then
        cast(replace(replace(replace(lower(price), 'rp', ''), ',', '.'), 'rb', '') as numeric) * 1000
    else null
end;

	
select * from tangsel_housing th ;



--CLEANSING
alter table tangsel_housing add column id serial primary key;

create index idx_link on tangsel_housing(id);

--menghapus duplikat
with ranked_rows as (
  select *,
         row_number() over (
           partition by link_housing, loc_housing, price, floor_area, price_per_m2, bath, bed -- kolom yang dianggap untuk cek duplikat
           order by id
         ) as rn
  from tangsel_housing
)
delete from tangsel_housing
where id in (
  select id from ranked_rows where rn > 1
);

--menangani missing value
update tangsel_housing th 
	set bed = 0
	where bed is null;

update tangsel_housing th 
	set bath = 0
	where bath is null;

update tangsel_housing th 
	set price_per_m2_clean = price_num / floor_area_clean 
	where th.price_per_m2_clean  is null;

select count(*) from tangsel_housing th 
	where th.price_per_m2_clean is null;

delete from tangsel_housing th
	where price_per_m2_clean < 1000000;

--ENRICHING

alter table tangsel_housing 
	add column subdistrict text;

update tangsel_housing th 
	set subdistrict = loc_housing;

update tangsel_housing th 
	set subdistrict = lower(subdistrict);

update tangsel_housing th 
	set subdistrict = replace(subdistrict, ', tangerang selatan, banten', '');

update tangsel_housing
set subdistrict = reverse(trim(split_part(reverse(subdistrict), ',', 1)));

select count(*) from tangsel_housing th ;

select 
	id, link_housing, loc_housing, subdistrict, 
	price_num, floor_area_clean, price_per_m2_clean, bed, bath 
from tangsel_housing th ;