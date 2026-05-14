# gsheet

Stata program to directly import a public Google Sheet by URL using the Stata Python Integration

---

## Requirements

### Stata
- Stata **16.0 or later** (required for Python integration)
- Python must already be configured and linked to Stata

### Python Packages
| Package | Purpose |
|---|---|
| `pandas` | Data download, parsing, and type inference |
| `numpy` | Missing value handling during date parsing |

> `re` and `warnings` are Python standard library modules and require no installation.

### Network
- Active internet connection
- The target Google Sheet must be set to **"Anyone with the link can view"** — private or restricted sheets *will not* work. There is **no** plan to add functionality for private or restricted sheets in the future.

---

## Installation

**Install directly from GitHub:**
```stata
net from "https://raw.githubusercontent.com/elpus/gsheet/main/"
net install gsheet
```

---

## Installing Needed Python Packages

**From within Stata:**
```stata
python:
import sys, subprocess
subprocess.run([sys.executable, "-m", "pip", "install", "pandas", "numpy"])
end
```

Alternatively, locate the python executable linked to Stata via `python query` in Stata and run that environment's `pip` directly in a command line or terminal.

---

## Syntax

```stata
gsheet using "https://docs.google.com/spreadsheets/d/YOUR_SHEET_ID/...", [options]
```

### Options

| Option | Description |
|---|---|
| `sheet(string)` | Sheet tab name (e.g. `sheet(Sheet2)`) or numeric GID (e.g. `sheet(123456789)`) |
| `cellrange(string)` | Limit import to a cell range, e.g. `cellrange(A1:G100)` |
| `save(string)` | Save the resulting dataset as a `.dta` file at the specified path |
| `firstrow` | Use the first row of the sheet as variable names |
| `lowercase` | Force variable names to lowercase (requires `firstrow`) |
| `noblankrows` | Drop rows where every cell is empty |
| `noblankcols` | Drop columns where every cell is empty |
| `clear` | Clear data in memory before importing |
| `quiet` | Suppress all output |
| `verbose` | Print additional diagnostic output |

---

## Usage Examples

**Basic import, replacing any current dataset:**
```stata
gsheet using "https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit", clear
```

**Import a specific named sheet with variable names from first row:**
```stata
gsheet using "https://docs.google.com/spreadsheets/d/1cvaIhXYhDh70rnUfAtyAhI7hlXhrLSCnLWqhL6UnioE/edit", sheet("Data-world-by-year") firstrow clear

```

**Limit to a cell range and save the result skipping blank columns and using first row as variable names:**
```stata
gsheet using "https://docs.google.com/spreadsheets/d/1cvaIhXYhDh70rnUfAtyAhI7hlXhrLSCnLWqhL6UnioE/edit", sheet("Data countries etc by year") ///
 cellrange(A1:F500) firstrow lowercase noblankcols save("life_expectancy.dta") clear

```

---

## Behavior Notes

- **Variable naming:** Special characters in column headers are replaced with underscores. Duplicate names are resolved automatically with numeric suffixes. Names are truncated to 32 characters per Stata's limit.
- **Type inference:** Columns are stored as `double` if numeric, Stata datetime (`%tc`) if all non-blank values parse as dates, and `string` otherwise.
- **ID columns:** Any column whose name contains `id` (case-insensitive) is always stored as a string regardless of content (i.e., leading zeroes are not dropped and numbers are not rounded).
- **All-missing variables:** Columns where every observation is missing after import are automatically dropped.
- **Missing values:** Blank individual cells, `#N/A`, and `NA` are treated as missing on import.

---

## Author

Kenneth Elpus

---

## As is

This program works for me and I hope it will work for you, but I can't provide support if it doesn't. Most likely, you need to ensure your Python integration is setup correctly or ensure that the specific python executable that Stata invokes has the numpy and pandas packages installed.
