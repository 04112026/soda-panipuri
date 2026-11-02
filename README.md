# Parallel GitHub Actions CI/CD demo

Two tiny HTTP APIs and one GitHub Actions workflow to demonstrate parallel builds, gated merges, and parallel simulated deployments.

## Run locally

- Java 17 + Maven: `cd java-api && mvn package && java -jar target/java-api-1.0.0.jar` then visit http://localhost:8080
- Node.js 22: `cd node-api && npm install && npm start` then visit http://localhost:3000

## How the pipeline behaves

1. Raise a PR into `main` → `java-build` and `node-build` execute independently and can run concurrently.
2. Require **both** CI status checks and a reviewer approval before merging.
3. Merge into `main` → both builds run again, followed by `java-deploy` and `node-deploy` in parallel.
4. Deploy steps are *simulations only* (echo statements); no cloud credentials are needed.

## Configure gated check-ins on GitHub

In **Settings → Branches → Add branch protection rule** for `main` (or use repository rulesets):

- Require a pull request before merging.
- Require at least 1 approval.
- Require status checks `java-build` and `node-build` (the workflow may need to run once before the checks are available).
- Optionally require the branch to be up to date before merging.
- Prevent bypass and force pushes as needed, according to your repository permissions and plan.

GitHub branch protection is the closest equivalent to gated check-ins; it isn't the same feature as Azure DevOps TFVC gated check-in.

## Team exercise

1. Create a feature branch and PR.
2. Observe the two concurrent build jobs in **Actions**.
3. Introduce invalid JavaScript syntax in `node-api/index.js`: Node build fails, Java build remains independent, and merging is blocked.
4. Fix syntax, rerun/check jobs, get approval, merge, and observe the two parallel deployment simulations.

Note: parallel scheduling depends on available GitHub Actions runners/concurrency limits.

Some random lines getting written into main branch.
