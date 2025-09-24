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

The `monitoring_messages` model creates a comprehensive monitoring system by filtering your existing `data_record` data to show only messages from your dedicated monitoring phones. It provides real-time visibility into your CHT system's health by tracking the complete journey of test messages from physical phones through your entire pipeline.

## Architecture

```
[Android Digicel Phone] → [TextIt] → [CHT] → [CouchDB] → [dbt Pipeline] → [PostgreSQL] → [Superset]
[Android Flow Phone]    → [TextIt] → [CHT] → [CouchDB] → [dbt Pipeline] → [PostgreSQL] → [Superset]
```

## Setup

### 1. Set your monitoring phone numbers:
```bash
export MONITORING_PHONE_DIGICEL="+18763456789"  # Your Digicel phone
export MONITORING_PHONE_FLOW="+18767890123"     # Your Flow phone
```

### 2. Run the model:
```bash
dbt run --select monitoring_messages
```

## What you get

A comprehensive `monitoring_messages` table with:

### Core Fields
- `uuid` - Unique message identifier
- `from_phone` - The phone number that sent the message
- `carrier` - Automatically detected carrier (Digicel/Flow)
- `message_content` - The actual SMS text content

### Time-based Fields
- `saved_timestamp` - When message was saved to database
- `reported` - When message was originally sent
- `message_date` - Date only (for daily summaries)
- `message_hour` - Hour of day (0-23)
- `day_of_week` - Day of week (0=Sunday, 6=Saturday)

### Performance Fields
- `processing_delay_minutes` - Time from message sent to processed

## Carrier Detection

Automatically detects carriers based on Jamaica phone patterns:
- **Digicel**: `+1876[8|3|4|5]XXXXXXX`
- **Flow**: `+1876[9|7|6]XXXXXXX`

## Superset Dashboard Queries

### Message Timeline
```sql
SELECT 
  message_date,
  carrier,
  COUNT(*) as messages
FROM monitoring_messages 
GROUP BY message_date, carrier 
ORDER BY message_date;
```

### Hourly Patterns
```sql
SELECT 
  message_hour,
  carrier,
  COUNT(*) as messages
FROM monitoring_messages 
GROUP BY message_hour, carrier 
ORDER BY message_hour;
```

### Processing Performance
```sql
SELECT 
  carrier,
  AVG(processing_delay_minutes) as avg_delay,
  MAX(processing_delay_minutes) as max_delay
FROM monitoring_messages 
GROUP BY carrier;
```

### System Health Score
```sql
SELECT 
  message_date,
  COUNT(*) as total_messages,
  COUNT(DISTINCT carrier) as carriers_active,
  AVG(processing_delay_minutes) as avg_delay
FROM monitoring_messages 
GROUP BY message_date 
ORDER BY message_date;
```

### Gap Detection (Missing Messages)
```sql
SELECT 
  from_phone,
  carrier,
  reported,
  LAG(reported) OVER (PARTITION BY from_phone ORDER BY reported) as prev_message,
  EXTRACT(EPOCH FROM (reported - LAG(reported) OVER (PARTITION BY from_phone ORDER BY reported)))/3600.0 as gap_hours
FROM monitoring_messages 
ORDER BY reported DESC;
```

## Monitoring Setup

### Configure Your Android Phones
1. **Digicel Phone**: Install SMS scheduling app, send "System check - Digicel OK" every 30 minutes
2. **Flow Phone**: Install SMS scheduling app, send "System check - Flow OK" every 30 minutes (offset by 15 minutes)

### TextIt Integration
Configure TextIt to forward monitoring messages to CHT via webhook/API.

## Success Metrics

Your monitoring is working when you see:
- Regular messages from both carriers (every 30 minutes)
- Balanced message counts between Digicel and Flow
- Processing delays < 5 minutes average
- No gaps longer than 2 hours in message timeline

## Troubleshooting

- **No messages**: Check phone connectivity, TextIt integration, CHT API status
- **Single carrier down**: Check that carrier's network, phone battery, SIM card
- **High processing delays**: Check database performance, CHT server resources
- **Gaps in timeline**: Check phone scheduling apps, network coverage
