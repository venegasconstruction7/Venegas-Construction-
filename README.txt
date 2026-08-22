VENEGAS CONSTRUCTION CLOUD TIMECLOCK

WHAT THIS VERSION DOES
- All employee hours are stored in one cloud database.
- It works across different phones/devices.
- Employees only see their own current/today hours.
- Jobsite photos upload to a PRIVATE storage bucket.
- Only the owner account can list/view the photos.
- Owner dashboard groups shifts by employee name and totals hours.

FILES
- index.html                  Worker clock-in page
- vc-owner-4827.html          Private owner dashboard
- config.js                   Supabase URL + publishable key
- supabase_setup.sql          Database + security setup

SETUP
1. Create/open your Supabase project.
2. In Authentication settings, enable Anonymous Sign-Ins.
3. Open SQL Editor and run supabase_setup.sql.
4. In Authentication -> Users, create the owner account using email + password.
5. In SQL Editor, run the final owners INSERT shown at the bottom of supabase_setup.sql,
   replacing OWNER_EMAIL_HERE with the owner's exact email.
6. Go to Project Settings -> API.
7. Copy Project URL and Publishable Key into config.js.
   NEVER place the service_role / secret key in the website.
8. Upload index.html, vc-owner-4827.html, and config.js to the same GitHub Pages repository.
9. Workers use the normal GitHub Pages URL.
10. Owner uses:
   /vc-owner-4827.html

SECURITY
- Supabase Row Level Security is enabled on all exposed tables.
- Workers can only create/read/update their own time-entry rows.
- Worker accounts cannot read job_photos metadata.
- The storage bucket is private.
- Only owner users in public.owners can read all time records and job photos.
- The website uses only the public/publishable browser key; do not expose service_role keys.

NOTE
If two employees share exactly the same typed name, their shifts will appear under the same name in
the owner dashboard. For stricter identity later, add a worker PIN or employee ID.
