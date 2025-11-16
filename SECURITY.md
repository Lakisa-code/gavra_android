# Security: Supabase Keys

This project should not contain Supabase service keys or other secrets in the source code. If you find embedded secrets, rotate them immediately and remove them from the repository.

## How to migrate away from embedded keys

1. Rotate any exposed keys in the Supabase dashboard:
   - Navigate to Project -> Settings -> API -> Rotate Keys.

2. Remove the keys from the repository (done in this PR) and ensure code reads the key from environment variables.

3. Use `--dart-define` or a `.env` file (with flutter_dotenv) locally:
   - Local dev: create a `.env` file (not checked into git) and set keys there.
   - For Flutter builds: use `--dart-define=SUPABASE_SERVICE_ROLE_KEY=<key>` on build/CI.
   ## Example GitHub Actions setup

   1) Add secrets in GitHub repository => Settings -> Secrets -> Actions:
      - SUPABASE_URL
      - SUPABASE_ANON_KEY
      - SUPABASE_SERVICE_ROLE_KEY

   2) The CI workflow (for example in `.github/workflows/ci.yml`) should:
      - Run a secret scan (gitleaks or similar) on push/PR.
      - Run dart format, flutter analyze, and `flutter test`.
      - Build and verify app using `--dart-define` to inject SUPABASE_URL/KEYS at build time.

   See `.github/workflows/ci.yml` in this repository for a working example.

4. For serverless functions and cloud jobs, use platform secrets (Supabase project secrets, GitHub Actions Secrets, etc.).

Example for GitHub Actions (workflow):
```yaml
env:
  SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
  SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
  SUPABASE_SERVICE_ROLE_KEY: ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}
```

5. Validate that no service keys remain in the git history (consider using `git filter-branch` or the BFG Repo-Cleaner to remove them if the repo is public).

If you want, I can prepare a PR that removes any remaining hard-coded keys across the repo and adds CI docs for setting secrets.
