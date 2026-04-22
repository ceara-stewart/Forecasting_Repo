SET DATEFIRST 1;  -- Monday = 1

WITH channels AS (
    SELECT DISTINCT
        CASE
            WHEN channel LIKE '%corr%' THEN 'Correspondent'
            ELSE channel
        END AS channel
    FROM marketing_sandbox.dbo.SDS WITH (NOLOCK)
    WHERE channel NOT LIKE '%Credit Union Partners%'
),

base AS (
    SELECT
        CASE
            WHEN s.channel LIKE '%corr%' THEN 'Correspondent'
            ELSE s.channel
        END AS channel,
        s.funded_date,
        s.loan_amount,
        DATEPART(YEAR, s.funded_date) AS year_of_funding,
        DATEPART(WEEKDAY, s.funded_date) - 1 AS day_of_week,
        DATEPART(DAY, s.funded_date) AS day_of_month,
        DATEDIFF(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, s.funded_date), 0), s.funded_date) + 1 AS week_of_month,
        DATEPART(MONTH, s.funded_date) AS month_of_year
    FROM marketing_sandbox.dbo.SDS s WITH (NOLOCK)
    WHERE s.funded_date >= DATEADD(YEAR, -5, CAST(GETDATE() AS DATE))
      AND s.funded_date <= (
            SELECT MIN(Calendar_Date)
            FROM (
                SELECT Calendar_Date,
                       ROW_NUMBER() OVER (ORDER BY Calendar_Date ASC) AS rn
                FROM marketing_sandbox.dbo.Calendar WITH (NOLOCK)
                WHERE Calendar_Date > CAST(GETDATE() AS DATE)
                  AND Biz_Day = 1
            ) biz
            WHERE rn = 3
      )
      AND s.funded_date IS NOT NULL
      AND s.channel NOT LIKE '%Credit Union Partners%'
),

freq AS (
    SELECT
        channel,
        funded_date,
        loan_amount,
        year_of_funding,
        day_of_week,
        day_of_month,
        week_of_month,
        month_of_year,
        COUNT(CASE WHEN day_of_week < 5 THEN 1 END)
            OVER (PARTITION BY channel, year_of_funding, month_of_year, week_of_month) AS loans_in_week,
        COUNT(CASE WHEN day_of_week < 5 THEN 1 END)
            OVER (PARTITION BY channel, year_of_funding, month_of_year) AS loans_in_month,
        COUNT(CASE WHEN day_of_week < 5 THEN 1 END)
            OVER (PARTITION BY channel, year_of_funding, month_of_year, week_of_month, day_of_week) AS loans_on_day_of_week,
        COUNT(CASE WHEN day_of_week < 5 THEN 1 END)
            OVER (PARTITION BY channel, year_of_funding, month_of_year, day_of_month) AS loans_on_day_of_month,
        SUM(CASE WHEN day_of_week < 5 THEN loan_amount ELSE 0 END)
            OVER (PARTITION BY channel, year_of_funding, month_of_year, week_of_month) AS amount_in_week,
        SUM(CASE WHEN day_of_week < 5 THEN loan_amount ELSE 0 END)
            OVER (PARTITION BY channel, year_of_funding, month_of_year) AS amount_in_month,
        SUM(CASE WHEN day_of_week < 5 THEN loan_amount ELSE 0 END)
            OVER (PARTITION BY channel, year_of_funding, month_of_year, week_of_month, day_of_week) AS amount_on_day_of_week,
        SUM(CASE WHEN day_of_week < 5 THEN loan_amount ELSE 0 END)
            OVER (PARTITION BY channel, year_of_funding, month_of_year, day_of_month) AS amount_on_day_of_month,
        SUM(CASE WHEN day_of_week < 5 THEN 1 ELSE 0 END)
            OVER (PARTITION BY channel, month_of_year) AS total_loans_in_month_across_years,
        SUM(CASE WHEN day_of_week < 5 THEN loan_amount ELSE 0 END)
            OVER (PARTITION BY channel, month_of_year) AS total_amount_in_month_across_years,
        SUM(CASE WHEN day_of_week < 5 THEN 1 ELSE 0 END)
            OVER (PARTITION BY channel, year_of_funding) AS total_loans_in_year,
        SUM(CASE WHEN day_of_week < 5 THEN loan_amount ELSE 0 END)
            OVER (PARTITION BY channel, year_of_funding) AS total_amount_in_year
    FROM base
),

agg_loans AS (
    SELECT
        channel,
        CAST(funded_date AS DATE) AS funded_date,
        year_of_funding,
        day_of_week,
        day_of_month,
        week_of_month,
        month_of_year,
        COUNT(*) AS count_funded_loans,
        SUM(loan_amount) AS sum_funded_volume,
        CAST(loans_in_week AS FLOAT) / NULLIF(loans_in_month, 0) AS week_weight,
        CAST(loans_on_day_of_week AS FLOAT) / NULLIF(loans_in_week, 0) AS day_of_week_weight,
        CAST(loans_on_day_of_month AS FLOAT) / NULLIF(loans_in_month, 0) AS day_of_month_weight,
        CAST(amount_in_week AS FLOAT) / NULLIF(amount_in_month, 0) AS week_amount_weight,
        CAST(amount_on_day_of_week AS FLOAT) / NULLIF(amount_in_week, 0) AS day_of_week_amount_weight,
        CAST(amount_on_day_of_month AS FLOAT) / NULLIF(amount_in_month, 0) AS day_of_month_amount_weight,
        CAST(total_loans_in_month_across_years AS FLOAT) / NULLIF(SUM(total_loans_in_month_across_years)
            OVER (PARTITION BY channel, month_of_year), 0) AS month_to_month_weight_loans,
        CAST(total_amount_in_month_across_years AS FLOAT) / NULLIF(SUM(total_amount_in_month_across_years)
            OVER (PARTITION BY channel, month_of_year), 0) AS month_to_month_weight_amount,
        CAST(total_loans_in_month_across_years AS FLOAT) / NULLIF(total_loans_in_year, 0) AS month_within_year_weight_loans,
        CAST(total_amount_in_month_across_years AS FLOAT) / NULLIF(total_amount_in_year, 0) AS month_within_year_weight_amount
    FROM freq
    GROUP BY
        channel, CAST(funded_date AS DATE), year_of_funding, day_of_week,
        day_of_month, week_of_month, month_of_year, loans_in_week, loans_in_month,
        loans_on_day_of_week, loans_on_day_of_month, amount_in_week, amount_in_month,
        amount_on_day_of_week, amount_on_day_of_month, total_loans_in_month_across_years,
        total_amount_in_month_across_years, total_loans_in_year, total_amount_in_year
),

calendar_channels AS (
    SELECT
        c.Calendar_Date, ch.channel, c.Biz_Day, c.Funding_Day,
        c.Funding_Day_Remaining_in_Month, c.Biz_Day_Remaining_in_Month,
        c.Is_Holiday,
        DATEPART(WEEKDAY, c.Calendar_Date) - 1 AS day_of_week,
        DATEPART(DAY, c.Calendar_Date) AS day_of_month,
        DATEDIFF(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, c.Calendar_Date), 0), c.Calendar_Date) + 1 AS week_of_month,
        DATEPART(MONTH, c.Calendar_Date) AS month_of_year
    FROM marketing_sandbox.dbo.Calendar c
    CROSS JOIN channels ch
    WHERE c.Calendar_Date >= DATEADD(YEAR, -5, CAST(GETDATE() AS DATE))
      AND c.Calendar_Date <= (
            SELECT MIN(Calendar_Date)
            FROM (
                SELECT Calendar_Date,
                       ROW_NUMBER() OVER (ORDER BY Calendar_Date ASC) AS rn
                FROM marketing_sandbox.dbo.Calendar WITH (NOLOCK)
                WHERE Calendar_Date > CAST(GETDATE() AS DATE)
                  AND Biz_Day = 1
            ) biz
            WHERE rn = 3
      )
),

joined AS (
    SELECT
        cc.Calendar_Date, cc.channel, cc.Biz_Day, cc.Funding_Day,
        cc.Funding_Day_Remaining_in_Month, cc.Biz_Day_Remaining_in_Month,
        cc.Is_Holiday, cc.day_of_week, cc.day_of_month, cc.week_of_month,
        cc.month_of_year,
        ISNULL(al.count_funded_loans, 0)            AS count_funded_loans,
        ISNULL(al.sum_funded_volume, 0)             AS sum_funded_volume,
        ISNULL(al.week_weight, 0)                 AS week_weight,
        ISNULL(al.day_of_week_weight, 0)          AS day_of_week_weight,
        ISNULL(al.day_of_month_weight, 0)         AS day_of_month_weight,
        ISNULL(al.week_amount_weight, 0)          AS week_amount_weight,
        ISNULL(al.day_of_week_amount_weight, 0)   AS day_of_week_amount_weight,
        ISNULL(al.day_of_month_amount_weight, 0)  AS day_of_month_amount_weight,
        ISNULL(al.month_to_month_weight_loans, 0) AS month_to_month_weight_loans,
        ISNULL(al.month_to_month_weight_amount, 0)AS month_to_month_weight_amount,
        ISNULL(al.month_within_year_weight_loans, 0)  AS month_within_year_weight_loans,
        ISNULL(al.month_within_year_weight_amount, 0) AS month_within_year_weight_amount
    FROM calendar_channels cc
    LEFT JOIN agg_loans al
        ON cc.Calendar_Date = al.funded_date
       AND cc.channel = al.channel
)

SELECT
    Calendar_Date, channel, Biz_Day, Funding_Day,
    Funding_Day_Remaining_in_Month, Biz_Day_Remaining_in_Month,
    Is_Holiday, day_of_week, day_of_month, week_of_month, month_of_year,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE count_funded_loans END          AS count_funded_loans,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE sum_funded_volume END           AS sum_funded_volume,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE week_weight END               AS week_weight,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE day_of_week_weight END        AS day_of_week_weight,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE day_of_month_weight END       AS day_of_month_weight,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE week_amount_weight END        AS week_amount_weight,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE day_of_week_amount_weight END AS day_of_week_amount_weight,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE day_of_month_amount_weight END AS day_of_month_amount_weight,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE month_to_month_weight_loans END  AS month_to_month_weight_loans,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE month_to_month_weight_amount END AS month_to_month_weight_amount,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE month_within_year_weight_loans END  AS month_within_year_weight_loans,
    CASE WHEN day_of_week IN (5,6) THEN 0 ELSE month_within_year_weight_amount END AS month_within_year_weight_amount
FROM joined
ORDER BY Calendar_Date ASC, channel;