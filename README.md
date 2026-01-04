# fivem-lua-lint-action

This GitHub Action runs `luacheck` on your Lua codebase against known FiveM natives for any GitHub repository!

> Now supports FiveM Lua backtick syntax.

---

## Using

To use this in your GitHub repository, create the following file:

> **.github/workflows/lint.yml**

```yml
name: Lint
on: [push, pull_request]
jobs:
  lint:
    name: Lint Resource
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Lint
        uses: Thunderwolfx/fivem-lua-lint-action@v2
```

This will automatically run `luacheck` for both commits and pull requests!

---

## JUnit Reporting (Getting Fancy)

If you would like to display fancy results in the GitHub action job, you can try the following configuration,
which outputs a JUnit results file:

![Fancy JUnit Reporting in GitHub Actions Example](.github/docs/fancy_example.png)

> **.github/workflows/lint.yml**

```yml
name: Lint
on: [push, pull_request]
jobs:
  lint:
    name: Lint Resource
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Lint
        uses: Thunderwolfx/fivem-lua-lint-action@v2
        with:
          capture: "junit.xml"
          args: "-t --formatter JUnit"
      - name: Generate Lint Report
        if: always()
        uses: mikepenz/action-junit-report@v3
        with:
          report_paths: "**/junit.xml"
          check_name: Linting Report
          fail_on_failure: false

```

---

## Linting Only Changed Resources

To improve performance in large repositories, you can configure the action to only lint resources that have changed files. This is particularly useful for monorepos with many FiveM resources.

When a `.lua` file is changed in a resource folder (e.g., `apollo/apollo_one/client.lua`), the action will lint the entire resource folder (`apollo/apollo_one/`).

> **.github/workflows/lint.yml**

```yml
name: Lint
on: [push, pull_request]
jobs:
  lint:
    name: Lint Changed Resources
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
        with:
          fetch-depth: 0  # Required for comparing against base branch
      - name: Lint
        uses: Thunderwolfx/fivem-lua-lint-action@v2
        with:
          only_changed: "true"
```

This feature:
- For **pull requests**: compares against the base branch
- For **pushes**: compares against the previous commit
- Detects changed `.lua` files and extracts their resource folders (first 2 directory levels)
- Skips linting entirely if no `.lua` files were changed
- Works with any repository structure where resources are in `category/resource_name/` format


