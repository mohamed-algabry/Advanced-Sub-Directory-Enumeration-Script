# Advanced-Sub-Directory-Enumeration-Script
# 🔎 Advanced Sub-Directory Enumeration Toolkit

A powerful Bash-based web content discovery toolkit that combines multiple directory enumeration engines into a single workflow.

This script automates sub-directory and file discovery by leveraging:

- ffuf
- gobuster
- dirsearch
- feroxbuster
- dirb

It automatically detects available tools, selects a suitable wordlist, runs scans, normalizes outputs, removes duplicates, and generates a consolidated results file.

---

## ✨ Features

- Multi-tool directory enumeration
- Automatic tool detection
- Automatic wordlist discovery
- Support for custom wordlists
- Clean and normalized output
- Deduplicated final results
- Organized output structure
- Colored terminal output
- HTTPS support by default
- Run a single tool or all tools together

---

## 📦 Supported Tools

| Tool | Supported |
|--------|----------|
| ffuf | ✅ |
| gobuster | ✅ |
| dirsearch | ✅ |
| feroxbuster | ✅ |
| dirb | ✅ |

If a tool is not installed, the script skips it automatically.

---

## 📋 Requirements

Install one or more of the following:

```bash
ffuf
gobuster
dirsearch
feroxbuster
dirb
```

Recommended wordlists:

```bash
/usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt
/usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt
/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
/usr/share/seclists/Discovery/Web-Content/common.txt
/usr/share/wordlists/dirb/common.txt
/usr/share/dirb/wordlists/common.txt
/usr/share/wordlists/dirb/common.txt
```

---

## 🚀 Installation

Clone the repository:

```bash
git clone https://github.com/yourusername/subdir-enum-toolkit.git
cd subdir-enum-toolkit
```

Make the script executable:

```bash
chmod +x subdir_enum.sh
```

---

## 🛠 Usage

### Basic Scan

```bash
./subdir_enum.sh example.com
```

### Specify Target

```bash
./subdir_enum.sh -u example.com
```

### Use Custom Wordlist

```bash
./subdir_enum.sh example.com -w wordlist.txt
```

### Run ffuf Only

```bash
./subdir_enum.sh --ffuf example.com
```

### Run Gobuster Only

```bash
./subdir_enum.sh --gobuster example.com
```

### Run Multiple Tools

```bash
./subdir_enum.sh --ffuf --dirsearch example.com
```

### Run All Tools

```bash
./subdir_enum.sh --all example.com
```

---

## ⚙️ Available Options

| Option | Description |
|----------|------------|
| `-u, --target` | Target URL/domain |
| `-w, --wordlist` | Custom wordlist |
| `--ffuf` | Run ffuf only |
| `--gobuster` | Run gobuster only |
| `--dirsearch` | Run dirsearch only |
| `--feroxbuster` | Run feroxbuster only |
| `--dirb` | Run dirb only |
| `--all` | Run all available tools |
| `-h, --help` | Show help menu |

---

## 📂 Output Structure

After execution:

```text
subdir_enum_example_com/
├── ffuf.json
├── ffuf_filtered.txt
├── gobuster.txt
├── gobuster_filtered.txt
├── dirsearch.txt
├── dirsearch_filtered.txt
├── feroxbuster.txt
├── feroxbuster_filtered.txt
├── dirb.txt
├── dirb_filtered.txt
└── all_results.txt
```

### Final Results

The file:

```text
all_results.txt
```

contains all unique findings merged from every tool.

Example:

```text
200  https://example.com/admin
301  https://example.com/login
403  https://example.com/private
```

---

## 🧠 Wordlist Selection Logic

Priority order:

1. User supplied wordlist (`-w`)
2. SecLists medium directory list
3. Raft large directories list
4. Common SecLists list
5. Dirb common lists

If no valid wordlist is found, execution stops.

---

## 🔒 Notes

- Targets can be supplied with or without protocol.
- Results are normalized and deduplicated automatically.
- The script uses HTTPS by default.
- Missing tools do not stop execution.
- Individual tool failures are handled gracefully.

---

## 📜 License

MIT License

---

## ⭐ Disclaimer

Use this tool only on systems you own or are explicitly authorized to test.

Unauthorized scanning may violate laws, regulations, or bug bounty policies.

