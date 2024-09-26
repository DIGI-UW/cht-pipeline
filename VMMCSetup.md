# VMMC Analytics Support in 2WayTexting Programs

This branch has been specifically designed to support analytics for VMMC in 2WayTexting programs.

### Key Additions

Two new tables have been added to the base CHT-Pipeline:

1. **Message Table** (`models/contacts/message.sql`)

   - **Purpose**: Stores all messages received within the application. This table is central to tracking communications in the system.

2. **Response Table** (`models/contacts/response.sql`)
   - **Purpose**: Caches SMS form responses from RapidPro. By storing these responses locally, analytics based on the responses can be generated more efficiently.

### Modifications to the Patients Table

The **Patients** table has been updated to include location information, adding the following columns:

- `enrollment_facility`
- `district`
- `province`
- `implementing_partner`

These additions make it easier to filter dashboards based on these attributes, enhancing the ability to analyze data by geographical and partner-specific dimensions.

### Location Data

Location data is set up as **seeds** in the file `seeds/locations.csv` within the CHT-Sync repository. The **Patients** table depends on this file to provide location-related information. A copy of this file can be found in `data/locations.csv`.

#### Important Note:

The columns in this CSV are directly referenced in the **Patients** table. If you make any changes (e.g., adding, removing, or renaming columns), you will need to update `models/contacts/patient.sql` to reflect these changes.

### Workflow

1. **Modifications**: If any changes are made to the `locations.csv` file, ensure that you update the SQL models accordingly.
2. **Commit & Push**: After making changes, commit and push them to GitHub. CHT Sync will then detect these changes and incorporate them into the pipeline.
