WITH app_counts AS (
    SELECT 
        CAST(unified_app_date AS DATE) AS dt,
        channel,
        COUNT(*) AS application_count
    FROM marketing_sandbox.dbo.SDS WITH (NOLOCK)
    WHERE unified_app_date IS NOT NULL
    GROUP BY CAST(unified_app_date AS DATE), channel
),

uw_event_counts AS (
    SELECT 
        CAST(underwriting_submission_date AS DATE) AS dt,
        channel,
        COUNT(*) AS underwriting_submission_events
    FROM marketing_sandbox.dbo.SDS WITH (NOLOCK)
    WHERE underwriting_submission_date IS NOT NULL
    GROUP BY CAST(underwriting_submission_date AS DATE), channel
),

approval_event_counts AS (
    SELECT 
        CAST(initial_conditional_approval_date AS DATE) AS dt,
        channel,
        COUNT(*) AS approval_events
    FROM marketing_sandbox.dbo.SDS WITH (NOLOCK)
    WHERE initial_conditional_approval_date IS NOT NULL
    GROUP BY CAST(initial_conditional_approval_date AS DATE), channel
),

base AS (
    SELECT
        CAST(a.filedt AS DATE) AS filedt,
        a.channel,

        COUNT(DISTINCT a.loan_number) AS loan_count,
        SUM(a.loan_amount) AS loan_volume,

        COUNT(DISTINCT CASE WHEN b.funded_date IS NOT NULL THEN a.loan_number END) AS funded_loan_count,
        SUM(CASE WHEN b.funded_date IS NOT NULL THEN a.loan_amount ELSE 0 END) AS funded_loan_volume,

        -- status-based
        COUNT(DISTINCT CASE 
            WHEN b.underwriting_submission_date IS NOT NULL 
            THEN a.loan_number 
        END) AS underwriting_submission_count,

        COUNT(DISTINCT CASE 
            WHEN b.initial_conditional_approval_date IS NOT NULL 
            THEN a.loan_number 
        END) AS initial_conditional_approval_count,

        -- event-based
        ISNULL(uw.underwriting_submission_events, 0) AS underwriting_submission_events,
        ISNULL(ap.approval_events, 0) AS approval_events,
        ISNULL(ac.application_count, 0) AS application_count,

        -- pull-through
        CAST(
            100.0 * COUNT(DISTINCT CASE WHEN b.funded_date IS NOT NULL THEN a.loan_number END)
            / COUNT(DISTINCT a.loan_number)
            AS DECIMAL(10,2)
        ) AS pull_through_pct_count,

        CAST(
            100.0 * SUM(CASE WHEN b.funded_date IS NOT NULL THEN a.loan_amount ELSE 0 END)
            / NULLIF(SUM(a.loan_amount), 0)
            AS DECIMAL(10,2)
        ) AS pull_through_pct_volume

    FROM marketing_sandbox.dbo.skinny_core a WITH (NOLOCK)

    JOIN marketing_sandbox.dbo.SDS b WITH (NOLOCK)
        ON a.loan_number = b.loan_number

    LEFT JOIN app_counts ac
        ON CAST(a.filedt AS DATE) = ac.dt
        AND a.channel = ac.channel

    LEFT JOIN uw_event_counts uw
        ON CAST(a.filedt AS DATE) = uw.dt
        AND a.channel = uw.channel

    LEFT JOIN approval_event_counts ap
        ON CAST(a.filedt AS DATE) = ap.dt
        AND a.channel = ap.channel

    WHERE repeat_application = 0
      AND a.loan_status NOT LIKE '%C%'
      AND a.loan_status NOT IN (
            '0110','0115','0120','0125','0130','0140','0150','0160','0170','0180','0182',
            '0189','0190','0191','0192','0360','0362','0370','0375','0510','0610',
            '0618','0710','0711','0715','0720','1040'
      )

    GROUP BY 
        CAST(a.filedt AS DATE),
        a.channel,
        ac.application_count,
        uw.underwriting_submission_events,
        ap.approval_events
)

SELECT
    b.*,

    -- Calendar fields
    c.Biz_Day,
    c.Biz_Day_Remaining_in_Month,
    c.Biz_Days_in_Month,
    c.Is_Holiday,
    c.Is_Company_Holiday,
    c.Calendar_Days_Remaining

FROM base b

LEFT JOIN marketing_sandbox.dbo.Calendar c
    ON b.filedt = CAST(c.Calendar_Date AS DATE)

WHERE c.Is_Weekday = 1

ORDER BY 
    b.filedt;