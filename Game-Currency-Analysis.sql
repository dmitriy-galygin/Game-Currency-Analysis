/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор:Галыгин Дмитрий 
 * Дата:01.10.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),group_city_days AS (
SELECT
   fi.id,
   CASE 
   	 WHEN c.city = 'Санкт-Петербург' THEN 'Санкт_Петербург'
   	 ELSE 'ЛенОбл'
     END AS region,
   CASE 
   	 WHEN a.days_exposition >= '1' AND a.days_exposition <= '31' THEN 'до месяца'
   	 WHEN a.days_exposition >= '31' AND a.days_exposition <= '90' THEN 'до трех месяцаев'
   	 WHEN a.days_exposition >= '91' AND a.days_exposition <= '180' THEN 'полугода'
   	 WHEN a.days_exposition >= '181' THEN 'более полугода'
     ELSE 'активные объявелния'
     END AS activity_period,
     a.last_price,
     f.total_area,
     a.last_price/f.total_area AS metr_price,
     f.rooms,
     f.balcony
FROM real_estate.city AS c
LEFT JOIN real_estate.flats AS f USING(city_id)
RIGHT JOIN real_estate.advertisement AS a USING(id)
RIGHT JOIN real_estate.TYPE AS t USING(type_id)
INNER JOIN filtered_id AS fi ON fi.id=f.id
WHERE t.TYPE = 'город'
AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
)
SELECT 
    region,
    activity_period,
    COUNT(id) AS total_advertisement,
    ROUND(COUNT(*)/(SUM(COUNT(*)) OVER(PARTITION BY region)) :: NUMERIC, 2) *100 AS perc_advertisement,
	ROUND(AVG(last_price) :: NUMERIC, 2) AS avg_flat_price,
	MAX(last_price) AS max_flat_price,
	MIN(last_price) AS min_flat_price,
	ROUND(AVG(total_area) :: NUMERIC, 2) AS avg_area,
	MAX(total_area) AS max_area,
	MIN(total_area) AS min_area,
    ROUND(AVG(metr_price) :: NUMERIC, 2) AS avg_metr_price,
    MAX(metr_price) AS max_metr_price,
    MIN(metr_price) AS min_metr_price,
    ROUND(AVG(rooms) :: NUMERIC, 2) AS avg_rooms,
    MAX(rooms) AS max_rooms,
    MIN(rooms) AS min_rooms,
    ROUND(AVG(balcony) :: NUMERIC, 2) AS avg_balcony,
    MAX(balcony) AS max_balcony,
    MIN(balcony) AS min_balcony
FROM group_city_days
GROUP BY region, activity_period
ORDER BY region

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
first_last_month AS (
SELECT
    fi.id,
    EXTRACT(YEAR FROM a.first_day_exposition) AS year,
    DATE_TRUNC('month', a.first_day_exposition) :: DATE AS first_month,
    DATE_TRUNC('month', a.first_day_exposition + a.days_exposition :: int) :: DATE AS last_month,
    f.total_area,
    a.last_price/f.total_area AS metr_price
 FROM real_estate.advertisement AS a 
 JOIN real_estate.flats AS f USING(id)
 RIGHT JOIN real_estate.TYPE AS t USING(type_id)
 FULL JOIN filtered_id AS fi ON fi.id=f.id
 WHERE t.TYPE = 'город'
 ),
 last_month_info AS (
 SELECT 
    RANK() OVER(ORDER BY COUNT(id) ASC) AS rank_month,
    last_month,
    COUNT(id) AS total_adv,
    ROUND(COUNT(id)/(SELECT COUNT(*) FROM first_last_month) :: NUMERIC,2 ) AS perc_total_adv,
    ROUND(AVG(metr_price) :: NUMERIC, 2) AS avg_metr_price,
    ROUND(AVG(total_area) :: NUMERIC, 2) AS avg_area
 FROM first_last_month
 WHERE last_month BETWEEN '2015-01-01' AND '2018-12-01' 
       AND last_month IS NOT NULL
 GROUP BY last_month
 ORDER BY last_month
 ),
first_month_info AS (
 SELECT
    RANK() OVER(ORDER BY COUNT(id) ASC) AS rank_month,
    first_month,
    COUNT(id) AS total_adv,
    ROUND(COUNT(id)/(SELECT COUNT(*) FROM first_last_month) :: NUMERIC,2 ) AS perc_total_adv,
    ROUND(AVG(metr_price) :: NUMERIC, 2) AS avg_metr_price,
    ROUND(AVG(total_area) :: NUMERIC, 2) AS avg_area
 FROM first_last_month
 WHERE first_month BETWEEN '2015-01-01' AND '2018-12-01'
 GROUP BY first_month
 ORDER BY first_month
 )
 SELECT
 *
 FROM last_month_info AS li
 FULL JOIN first_month_info AS fi ON li.last_month=fi.first_month
