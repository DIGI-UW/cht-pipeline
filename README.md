A set of SQL queries that transform raw CouchDB data into a more useful format. It uses `dbt` to define the models that are translated into PostgreSQL tables or views, which makes it easier to query the data in the analytics platform of choice.

## Local Setup
Follow the instructions in [the Local CHT Sync Setup documentation](https://docs.communityhealthtoolkit.org/apps/guides/data/analytics/setup/) to set up CHT Sync locally.

## Run dbt models unit tests locally

### Prerequisites
- `Docker`

### Run the tests

1. Navigate to `tests` folder.
2. Run the test script

```sh
# set environment variables, install dbt dependencies, seed data, run dbt, run test
./run_dbt_tests.sh
```

## Release Process
This repo has an automated release process where each feature/bug fix will be released immediately after it is merged to `main`. The release type is determined by the commit message format. Have a look at the development workflow in the [Contributor Handbook](https://docs.communityhealthtoolkit.org/contribute/code/workflow/) for more information.

### Commit message format

The commit format should follow the convention outlined in the [CHT docs](https://docs.communityhealthtoolkit.org/contribute/code/workflow/#commit-message-format).
Examples are provided below.

| Type        | Example commit message                                                                              | Release type |
|-------------|-----------------------------------------------------------------------------------------------------|--------------|
| Bug fixes   | fix(#123): rename column names                                                                      | patch        |
| Performance | perf(#789): add new indexes                                                                         | patch        |
| Features    | feat(#456): add new model                                                                           | minor        |
| Non-code    | chore(#123): update README                                                                          | none         |
| Breaking    | perf(#2): remove data_record model <br/> BREAKING CHANGE: form models should now read from new_model| major        |

# CHT Monitoring Messages

End-to-end system monitoring for Jamaica CHT deployment using physical Android phones with Digicel and Flow SIM cards.

## What it does

The `monitoring_messages` model filters your existing `data_record` data to only messages sent from two dedicated monitoring phones. It derives daily/time features and gap-based health so you can see, per day, whether the three expected pings (07:00, 13:00, 19:00) arrived for each carrier.

## Architecture

```
[Android Digicel Phone] → [TextIt] → [CHT] → [CouchDB] → [dbt Pipeline] → [PostgreSQL] → [Superset]
[Android Flow Phone]    → [TextIt] → [CHT] → [CouchDB] → [dbt Pipeline] → [PostgreSQL] → [Superset]
```

## Setup

### 1) Set monitoring phone numbers
```bash
export MONITORING_PHONE_DIGICEL="+1876XXXXXXX"  # Your Digicel phone
export MONITORING_PHONE_FLOW="+1876YYYYYYY"     # Your Flow phone
```

### 2) Run the model
```bash
dbt run --select monitoring_messages
```

## Fields in `monitoring_messages`

### Core
- `uuid`: CHT document id
- `from_phone`: Sender (one of your two numbers)
- `carrier`: Digicel/Flow (derived from +1876 prefixes)
- `message_content`: SMS text

### Time
- `reported`: When the phone reported it sent (from `reported_date`)
- `saved_timestamp`: When CHT stored the doc
- `message_date`: Date (for daily charts)
- `message_hour`: Hour of day (0–23)
- `day_of_week`: 0=Sunday … 6=Saturday

### Health & gaps
- `time_since_last_message`: Interval since previous message from the same phone
- `message_health`:
  - `healthy`: cadence ok
  - `gap_detected`: large gap vs schedule (see thresholds below)
  - `processing_error`: CHT recorded errors on the doc
  - `deleted`: doc marked deleted
- `error_details`: Raw error info (if present)

## Gap logic (aligned to schedule 07:00, 13:00, 19:00)
- Same-day gap threshold: > 8 hours (larger than expected 6 hours)
- Overnight gap threshold (crossing days): > 14 hours (larger than expected ~12 hours)

Examples
- 07:00 → 13:00 (6h): healthy
- 13:00 → 22:00 (9h same-day): gap_detected
- 19:00 → 07:00 next day (12h): healthy
- 19:00 → 13:00 next day (18h): gap_detected

## Carrier detection
- **Digicel**: `+1876[8|3|4|5]XXXXXXX`
- **Flow**: `+1876[9|7|6]XXXXXXX`

## Daily performance in Superset

Dataset: `v1.monitoring_messages`
- Set Time Column = `message_date` (or `reported`) with Time Grain = Day

### A) Daily messages by carrier (bar)
- Time: `message_date` (Day)
- Group by: `carrier`
- Metric: `COUNT(*)`

### B) Daily gaps by carrier (bar)
- Time: `message_date` (Day)
- Group by: `carrier`
- Metric:
```sql
COUNT(CASE WHEN message_health = 'gap_detected' THEN 1 END)
```

### C) Daily success vs expected (virtual dataset option)
Save this as a SQL dataset `daily_monitoring_performance`:
```sql
WITH daily AS (
  SELECT
    message_date,
    from_phone,
    carrier,
    COUNT(*) AS received,
    COUNT(CASE WHEN message_health = 'gap_detected' THEN 1 END) AS gaps
  FROM v1.monitoring_messages
  GROUP BY message_date, from_phone, carrier
),
by_carrier AS (
  SELECT
    message_date,
    carrier,
    SUM(received) AS received,
    SUM(gaps) AS gaps,
    3 AS expected_per_carrier,
    ROUND(SUM(received)::numeric / 3.0 * 100, 1) AS success_rate_pct
  FROM daily
  GROUP BY message_date, carrier
),
overall AS (
  SELECT
    message_date,
    SUM(received) AS received_total,
    SUM(gaps) AS gaps_total,
    6 AS expected_total,
    ROUND(SUM(received)::numeric / 6.0 * 100, 1) AS success_rate_total_pct
  FROM daily
  GROUP BY message_date
)
SELECT
  c.message_date,
  c.carrier,
  c.received,
  c.gaps,
  c.expected_per_carrier,
  c.success_rate_pct,
  o.received_total,
  o.gaps_total,
  o.expected_total,
  o.success_rate_total_pct
FROM by_carrier c
JOIN overall o USING (message_date)
ORDER BY c.message_date;
```
Then build charts:
- Line: `success_rate_total_pct` by day (overall)
- Multi-series line: `success_rate_pct` by carrier
- Bar: `received_total` vs `expected_total`
- Stacked bar: `gaps` by carrier

## Operations checklist
- Phones send at 07:00, 13:00, 19:00 (use an SMS scheduler)
- Ensure TextIt → CHT forwarding is active
- Set `MONITORING_PHONE_DIGICEL`, `MONITORING_PHONE_FLOW`
- Run `dbt run --select monitoring_messages`
- Build daily charts in Superset using `message_date`

## Troubleshooting
- No rows today: verify phones, TextIt flow, CHT API, env vars
- Many `gap_detected`: network/device issues or forwarding disabled
- `processing_error`: inspect `error_details` and CHT logs
- Missing days in charts: create a date spine dataset and left join

