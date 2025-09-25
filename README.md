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
- `from_phone`: Sender (one of your two monitoring numbers)
- `message_content`: SMS text (extracted from multiple JSON paths for robustness)

### Time
- `reported`: When the phone reported it sent (from `reported_date`)
- `saved_timestamp`: When CHT stored the doc
- `message_date`: Date (for daily charts)
- `message_hour`: Hour of day (0–23)
- `day_of_week`: 0=Sunday … 6=Saturday

### Monitoring Analytics
- `expected_time_slot`: Time slot when message was sent
  - `morning`: 6-8am
  - `afternoon`: 12-2pm  
  - `evening`: 6-8pm
  - `other`: outside expected monitoring hours
- `is_expected_monitoring_time`: Boolean flag for expected monitoring hours (6-8am, 12-2pm, 6-8pm)

### Health & gaps
- `time_since_last_message`: Interval since previous message from the same phone
- `message_health`:
  - `healthy`: cadence ok
  - `gap_detected`: message >10 hours after previous (allowing 2-hour buffer beyond 8-hour schedule)
  - `processing_error`: CHT recorded errors on the doc
  - `deleted`: doc marked deleted

## Gap Detection Logic
- **Simplified threshold**: Any message >10 hours after the previous message = `gap_detected`
- **Buffer allowance**: 2 hours beyond the expected 8-hour interval for minor delays
- **Purpose**: Proactive monitoring to detect messaging failures before field staff report issues

Examples:
- 07:00 → 13:00 (6h): `healthy`
- 13:00 → 22:00 (9h): `healthy` (within 10h threshold)
- 13:00 → 23:30 (10.5h): `gap_detected`
- 19:00 → 07:00 next day (12h): `gap_detected`

## Message Content Extraction
The model uses robust extraction to handle different JSON structures:
- Object format: `doc.sms_message.message.value` (TextIt format)
- String format: `doc.sms_message.message` (direct string)
- Parsed fields: `doc.fields.message` (canonical CHT format)
- Fallback paths: `doc.fields.sms_message`, `doc.sms_content`, `doc.content`

## Daily performance in Superset

Dataset: `v1.monitoring_messages`
- Set Time Column = `message_date` (or `reported`) with Time Grain = Day

### A) Daily messages by phone (bar)
- Time: `message_date` (Day)
- Group by: `from_phone`
- Metric: `COUNT(*)`

### B) Daily gaps by phone (bar)
- Time: `message_date` (Day)
- Group by: `from_phone`
- Metric:
```sql
COUNT(CASE WHEN message_health = 'gap_detected' THEN 1 END)
```

### C) Messages by time slot (stacked bar)
- Time: `message_date` (Day)
- Group by: `expected_time_slot`
- Metric: `COUNT(*)`

### D) Daily success vs expected (virtual dataset option)
Save this as a SQL dataset `daily_monitoring_performance`:
```sql
WITH daily AS (
  SELECT
    message_date,
    from_phone,
    COUNT(*) AS received,
    COUNT(CASE WHEN message_health = 'gap_detected' THEN 1 END) AS gaps,
    COUNT(CASE WHEN is_expected_monitoring_time THEN 1 END) AS expected_time_messages
  FROM v1.monitoring_messages
  GROUP BY message_date, from_phone
),
by_phone AS (
  SELECT
    message_date,
    from_phone,
    SUM(received) AS received,
    SUM(gaps) AS gaps,
    SUM(expected_time_messages) AS expected_time_messages,
    3 AS expected_per_phone,  -- 3 messages per day (morning, afternoon, evening)
    ROUND(SUM(expected_time_messages)::numeric / 3.0 * 100, 1) AS success_rate_pct
  FROM daily
  GROUP BY message_date, from_phone
),
overall AS (
  SELECT
    message_date,
    SUM(received) AS received_total,
    SUM(gaps) AS gaps_total,
    SUM(expected_time_messages) AS expected_time_total,
    6 AS expected_total,  -- 2 phones × 3 messages per day
    ROUND(SUM(expected_time_messages)::numeric / 6.0 * 100, 1) AS success_rate_total_pct
  FROM daily
  GROUP BY message_date
)
SELECT
  p.message_date,
  p.from_phone,
  p.received,
  p.gaps,
  p.expected_time_messages,
  p.expected_per_phone,
  p.success_rate_pct,
  o.received_total,
  o.gaps_total,
  o.expected_time_total,
  o.expected_total,
  o.success_rate_total_pct
FROM by_phone p
JOIN overall o USING (message_date)
ORDER BY p.message_date, p.from_phone;
```
Then build charts:
- Line: `success_rate_total_pct` by day (overall)
- Multi-series line: `success_rate_pct` by phone
- Bar: `expected_time_total` vs `expected_total`
- Stacked bar: `gaps` by phone

## Operations checklist
- Phones send at 07:00, 13:00, 19:00 (use an SMS scheduler)
- Ensure TextIt → CHT forwarding is active
- Set `MONITORING_PHONE_DIGICEL`, `MONITORING_PHONE_FLOW` environment variables
- Run `dbt run --select monitoring_messages`
- Build daily charts in Superset using `message_date`
- Monitor `expected_time_slot` and `is_expected_monitoring_time` fields for timing analysis

## Troubleshooting
- **No rows today**: verify phones, TextIt flow, CHT API, environment variables
- **Many `gap_detected`**: network/device issues or forwarding disabled
- **`processing_error`**: inspect CHT logs for processing issues
- **NULL `message_content`**: check sync lag or JSON structure differences
- **Missing days in charts**: create a date spine dataset and left join
- **Unexpected time slots**: verify phone scheduling and timezone settings

